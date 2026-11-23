-keep class com.nosmai.zoom.NosmaiZoomSource {
    public static void configure(us.zoom.sdk.ZoomVideoSDKSessionContext, java.lang.Object);
    native <methods>;
}
-keepclassmembers class * implements com.nosmai.effect.api.NosmaiSDK$FrameCallback {
    public void onFrameProcessed(com.nosmai.effect.api.NosmaiSDK$FrameData);
}
# Compile-time annotations in Zoom's Tink dependency and router metadata.
-dontwarn javax.annotation.Nullable
-dontwarn javax.annotation.concurrent.GuardedBy
-dontwarn javax.lang.model.element.Element
