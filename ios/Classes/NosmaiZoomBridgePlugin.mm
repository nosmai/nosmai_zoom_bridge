#import "NosmaiZoomBridgePlugin.h"
#import <ZoomVideoSDK/ZoomVideoSDK.h>
#import <nosmai_effects_sdk/NosmaiFlutterPlugin.h>
#import <CoreVideo/CoreVideo.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#include <atomic>
#include "Native/FrameFit.h"
#include "Native/FramePacer.h"
#include "libyuv/convert.h"

@interface NMZoomSource : NSObject <ZoomVideoSDKVideoSource>
@property(nonatomic, weak) NSObject *owner;
- (void)retire;
@end

static char sourcesKey;
static __weak NMZoomSource *exportOwner; // Accessed only on the main queue.

@implementation NosmaiZoomBridgePlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {}

+ (void)configureContext:(ZoomVideoSDKSessionContext *)context owner:(NSObject *)owner {
    NMZoomSource *source = [NMZoomSource new];
    source.owner = owner;
    @synchronized (owner) {
        NSMutableSet *sources = objc_getAssociatedObject(owner, &sourcesKey);
        if (!sources) {
            sources = [NSMutableSet set];
            objc_setAssociatedObject(owner, &sourcesKey, sources, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        [sources addObject:source]; // Zoom's context holds a weak delegate.
    }
    context.externalVideoSourceDelegate = source;
    context.externalVideoSourceDataFormat = ZoomVideoSDKFrameDataFormat_I420;
}

+ (void)discardContext:(ZoomVideoSDKSessionContext *)context {
    id source = context.externalVideoSourceDelegate;
    if ([source isKindOfClass:NMZoomSource.class]) [source retire];
}

+ (void)detachOwner:(NSObject *)owner {
    NSArray *sources;
    @synchronized (owner) { sources = [objc_getAssociatedObject(owner, &sourcesKey) allObjects]; }
    for (NMZoomSource *source in sources) [source retire];
}
@end

@implementation NMZoomSource {
    dispatch_queue_t _worker;
    std::atomic_bool _busy;
    ZoomVideoSDKVideoSender *_sender;
    BOOL _sending, _closed;
    int _width, _height, _fps;
    NSUInteger _generation;
    NSProcessInfoThermalState _thermal;
    nosmai_zoom::FramePacer _pacer;
    std::vector<uint8_t> _planar, _output;
    nosmai_zoom::FrameFit _fit;
}

- (instancetype)init {
    if ((self = [super init])) {
        _busy.store(false);
        _worker = dispatch_queue_create("com.nosmai.zoom.video", DISPATCH_QUEUE_SERIAL);
        [NSNotificationCenter.defaultCenter addObserver:self
            selector:@selector(thermalStateChanged:) name:NSProcessInfoThermalStateDidChangeNotification object:nil];
        [self thermalStateChanged:nil];
    }
    return self;
}

- (void)thermalStateChanged:(NSNotification *)notification {
    @synchronized (self) {
        _thermal = NSProcessInfo.processInfo.thermalState;
        _pacer.Reset();
    }
}

- (void)onInitialize:(ZoomVideoSDKVideoSender *)sender supportCapabilityArray:(NSArray *)supported
    suggestCapability:(ZoomVideoSDKVideoCapability *)suggested {
    @synchronized (self) {
        if (_closed) return;
        _sender = sender;
        [self onPropertyChange:supported suggestCapability:suggested];
    }
}

- (void)onPropertyChange:(NSArray *)supported suggestCapability:(ZoomVideoSDKVideoCapability *)cap {
    @synchronized (self) {
        if (!cap) cap = supported.firstObject;
        _width = cap.width;
        _height = cap.height;
        _fps = cap.frame;
        _pacer.Reset();
        ++_generation;
    }
}

- (void)onStartSend {
    @synchronized (self) {
        if (_closed) return;
        _sending = YES;
        _pacer.Reset();
    }
    [self updateExport];
}

- (void)onStopSend {
    @synchronized (self) { _sending = NO; ++_generation; }
    [self updateExport];
}

- (void)updateExport {
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL start;
        @synchronized (self) { start = self->_sending && !self->_closed; }
        if (start && exportOwner != self) {
            exportOwner = self;
            __weak NMZoomSource *weakSelf = self;
            [NosmaiFlutterPlugin setLiveStreamFrameCallback:^(CVPixelBufferRef pixel, double timestamp) {
                [weakSelf offer:pixel];
            }];
        } else if (!start && exportOwner == self) {
            [NosmaiFlutterPlugin clearLiveStreamFrameCallback];
            exportOwner = nil;
        }
    });
}

- (void)offer:(CVPixelBufferRef)pixel {
    if (!pixel || _busy.exchange(true)) return;
    int w, h;
    NSUInteger generation;
    @synchronized (self) {
        int rate = _fps;
        if (_thermal == NSProcessInfoThermalStateSerious) rate = MIN(rate, 20);
        if (_thermal == NSProcessInfoThermalStateCritical) rate = MIN(rate, 15);
        if (!_sending || !_sender || !nosmai_zoom::I420Size(_width, _height)
            || !_pacer.Admit(CACurrentMediaTime(), rate)) {
            _busy.store(false);
            return;
        }
        w = _width; h = _height; generation = _generation;
    }
    CVPixelBufferRetain(pixel);
    dispatch_async(_worker, ^{
        @autoreleasepool {
            [self publish:pixel width:w height:h generation:generation];
            CVPixelBufferRelease(pixel);
            self->_busy.store(false);
        }
    });
}

- (void)publish:(CVPixelBufferRef)pixel width:(int)tw height:(int)th generation:(NSUInteger)gen {
    const int w = (int)CVPixelBufferGetWidth(pixel), h = (int)CVPixelBufferGetHeight(pixel);
    const size_t size = nosmai_zoom::I420Size(w, h);
    if (!size || CVPixelBufferGetPixelFormatType(pixel) != kCVPixelFormatType_32BGRA) return;
    if (CVPixelBufferLockBaseAddress(pixel, kCVPixelBufferLock_ReadOnly) != kCVReturnSuccess) return;
    _planar.resize(size);
    uint8_t *src = _planar.data();
    // libyuv ARGB is BGRA byte order on iOS. Zoom's I420 mode uses limited range.
    int result = libyuv::ARGBToI420((const uint8_t *)CVPixelBufferGetBaseAddress(pixel),
        (int)CVPixelBufferGetBytesPerRow(pixel), src, w, src + w*h, w/2,
        src + w*h*5/4, w/2, w, h);
    CVPixelBufferUnlockBaseAddress(pixel, kCVPixelBufferLock_ReadOnly);
    if (result != 0) return;
    const size_t outSize = nosmai_zoom::I420Size(tw, th);
    if (w != tw || h != th) {
        _output.resize(outSize);
        if (!_fit.Convert(src, w, h, _output.data(), tw, th, 16)) return;
        src = _output.data();
    }
    ZoomVideoSDKVideoRawDataRotation rot = nosmai_zoom::NeedsQuarterTurn(w,h,tw,th)
        ? ZoomVideoSDKVideoRawDataRotation90 : ZoomVideoSDKVideoRawDataRotationNone;
    @synchronized (self) {
        if (_sending && _sender && _generation == gen)
            [_sender sendVideoFrame:(char *)src width:tw height:th dataLength:outSize rotation:rot];
    }
}

- (void)retire {
    @synchronized (self) { _closed = YES; _sender = nil; }
    [self onStopSend];
    NSObject *owner = self.owner;
    @synchronized (owner) { [objc_getAssociatedObject(owner, &sourcesKey) removeObject:self]; }
}

- (void)onUninitialized { [self retire]; }
@end
