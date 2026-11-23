# Nosmai Zoom Bridge for Flutter

Publish the Nosmai camera, with beauty effects and filters, in a Zoom Video SDK session on Android or iOS. If your app already uses Zoom, replace the local camera preview and the call that joins the session. Keep using your existing Zoom code for remote video, audio, chat, screen sharing and leaving the session.

## Install

Use Flutter 3.29 or later. The bridge supports Android API 28+ and iOS 15+ with CocoaPods. This version targets `flutter_zoom_videosdk` 2.6.0.

Add these dependencies to your app’s `pubspec.yaml`. Your development machine and CI need Git access to the Nosmai bridge repository.

```yaml
dependencies:
  nosmai_zoom_bridge:
    git: https://github.com/nosmai/nosmai_zoom_bridge.git
  flutter_zoom_videosdk: 2.6.0
  nosmai_effects_sdk:
    git:
      url: https://github.com/nosmai/nosmai_effects_sdk_flutter.git
      ref: beta/2.0.3-beta.1
```

Run these commands from the **Flutter app directory** on macOS or Linux.

```sh
flutter pub get
dart run nosmai_zoom_bridge:setup
flutter pub get
```

Setup uses the system `patch` command to create a Zoom wrapper under `.nosmai_zoom/` and adds a dependency override in your app. This lets the bridge attach the Nosmai camera before Zoom joins. Rebuild the native app after setup. On a clean CI checkout, run the same steps or restore the generated wrapper and its override together.

## Connect the camera

1. Initialize Zoom as usual. Request camera permission and call `await NosmaiFlutter.initialize(nosmaiLicenseKey)`. Continue when it returns `true`. The license must match your Android application ID or iOS bundle ID. Request microphone permission if the session uses the mic.
2. Use `NosmaiCameraPreview` for the local video tile. When joining with the camera on, enable your Join action after the preview fires `onInitialized`. Keep the preview mounted while publishing, including when a remote participant fills the screen.
3. Pass your existing `JoinSessionConfig` to the bridge. Use a session JWT issued by your backend and set `videoOptions['localVideoOn']` to `true` to publish on join.

```dart
import 'package:nosmai_zoom_bridge/nosmai_zoom_bridge.dart';

// In the existing Join action, after the local preview is ready.
final result = await NosmaiZoomBridge.joinSession(config);
```

Handle the result in your existing join flow. Zoom’s `onSessionJoin` event confirms the connection. For a two-step join, call `NosmaiZoomBridge.prepareJoin(config)`, then use Zoom’s `commitJoin()` or `cancelPrepareJoin()`.

## Camera controls

- Apply effects through Nosmai. For example, `await NosmaiFlutter.instance.applySkinSmoothing(0.6)` updates the outgoing video. Use `await NosmaiFlutter.instance.switchCamera()` to flip cameras.
- Use Zoom’s video helper to mute or unmute outgoing video. To release the physical camera when leaving the screen, call `await NosmaiFlutter.instance.endCameraSession()` and remove the preview.
- The bridge uses Nosmai’s streaming frame callback while publishing. Give it exclusive use of that callback for the session.

## Platform notes

- **Android** uses Nosmai for camera effects. The adapter omits Zoom’s optional virtual-background module because it bundles a conflicting native library. Apps using that feature should account for it before switching.
- **iOS** apps using the pinned Nosmai beta can show a moving local preview while remote video freezes after returning from the background. Use a Nosmai Flutter SDK build with the iOS preview lifecycle fix for this flow.
- **iOS thermal limits** cap publishing at 20 FPS under serious thermal pressure and 15 FPS under critical pressure. The bridge resumes Zoom’s negotiated rate when thermal pressure subsides.

## Try the example

Run the setup commands from `example/`, then run `flutter run`. Enter a Nosmai license for the example app and tap **Start camera**. Enter the session name and JWT, then tap **Join session**. Join the same room from a second device and toggle **Skin smoothing** to verify the remote video. [Example app](example/lib/main.dart)

The native frame conversion uses libyuv. [License](ios/Classes/Yuv/LICENSE) · [Authors](ios/Classes/Yuv/AUTHORS) · [Patent grant](ios/Classes/Yuv/PATENTS)
