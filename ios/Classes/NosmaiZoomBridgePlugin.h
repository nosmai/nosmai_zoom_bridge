#import <Flutter/Flutter.h>

@class ZoomVideoSDKSessionContext;

@interface NosmaiZoomBridgePlugin : NSObject <FlutterPlugin>
+ (void)configureContext:(ZoomVideoSDKSessionContext *)context owner:(NSObject *)owner;
+ (void)discardContext:(ZoomVideoSDKSessionContext *)context;
+ (void)detachOwner:(NSObject *)owner;
@end
