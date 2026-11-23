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

## Initialize, preview and join

The local preview can appear before the user joins a room. Nosmai uses your app’s license to start the camera. The Zoom session JWT is needed when the user taps **Join**.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_zoom_videosdk/native/zoom_videosdk.dart';
import 'package:nosmai_effects_sdk/nosmai_effects_sdk.dart';
import 'package:nosmai_zoom_bridge/nosmai_zoom_bridge.dart';
import 'package:permission_handler/permission_handler.dart';
```

### 1. Initialize Zoom once

If your app already calls `zoom.initSdk(...)`, reuse that instance and its session event listener. Otherwise, initialize Zoom before joining with your app’s configuration. The example uses `await zoom.initSdk(InitConfig(domain: 'zoom.us', enableLog: false))` and checks the result. [Full initialization example](example/lib/main.dart)

### 2. Start the Nosmai camera

In your camera screen’s `State`, call `startLocalPreview` when the screen opens or the user taps **Start camera**. Pass a Nosmai license for the Android application ID or iOS bundle ID. This example uses `permission_handler` for camera access. Request microphone permission separately if the session uses the mic.

```dart
bool showLocalPreview = false;
bool cameraReady = false;

Future<void> startLocalPreview(String nosmaiLicenseKey) async {
  final permission = await Permission.camera.request();
  if (!permission.isGranted) throw StateError('Camera permission is required.');
  if (!mounted) return;

  final initialized = await NosmaiFlutter.initialize(nosmaiLicenseKey);
  if (!initialized) throw StateError('Nosmai could not initialize. Check the license.');
  if (mounted) setState(() => showLocalPreview = true);
}
```

### 3. Show the local preview

Call `buildLocalPreview()` where your screen displays the local camera tile. Nosmai owns the physical camera, so use this widget in place of Zoom’s local camera preview. Mount it as soon as `showLocalPreview` becomes true. Its `onInitialized` callback enables your **Join** action. At this point the user can see the camera and try effects locally.

```dart
Widget buildLocalPreview() {
  if (!showLocalPreview) return const SizedBox.shrink();
  return SizedBox(
    height: 300,
    child: NosmaiCameraPreview(
      onInitialized: () {
        if (mounted) setState(() => cameraReady = true);
      },
      onError: (message) {
        if (!mounted) return;
        setState(() => cameraReady = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      },
    ),
  );
}
```

### 4. Publish when the user joins

For a camera-on join, enable the button when `cameraReady` is true. Pass your existing `JoinSessionConfig` with the session JWT from your backend and `videoOptions: {'localVideoOn': true}`.

```dart
final result = await NosmaiZoomBridge.joinSession(config);
```

Handle the result in your existing join flow and use Zoom’s `onSessionJoin` event to confirm the connection. Keep `NosmaiCameraPreview` mounted while publishing, including when remote video fills the screen. Remote participants see the filtered camera through their normal Zoom video tile. If your app uses two-step join, call `NosmaiZoomBridge.prepareJoin(config)` followed by Zoom’s `commitJoin()` or `cancelPrepareJoin()`.

## Camera controls

- Apply effects through Nosmai. For example, `await NosmaiFlutter.instance.applySkinSmoothing(0.6)` updates the outgoing video. Use `await NosmaiFlutter.instance.switchCamera()` to flip cameras.
- Use Zoom’s video helper to mute or unmute outgoing video. To release the physical camera when leaving the screen, call `await NosmaiFlutter.instance.endCameraSession()` and remove the preview.
- The bridge uses Nosmai’s streaming frame callback while publishing. Give it exclusive use of that callback for the session.

## Platform notes

- **Android** uses Nosmai for camera effects. The adapter omits Zoom’s optional virtual-background module because it bundles a conflicting native library. Apps using that feature should account for it before switching.
- **iOS** apps using the pinned Nosmai beta can show a moving local preview while remote video freezes after returning from the background. Use a Nosmai Flutter SDK build with the iOS preview lifecycle fix for this flow.
- **iOS thermal limits** cap publishing at 20 FPS under serious thermal pressure and 15 FPS under critical pressure. The bridge resumes Zoom’s negotiated rate when thermal pressure subsides.

The native frame conversion uses libyuv. [License](ios/Classes/Yuv/LICENSE) · [Authors](ios/Classes/Yuv/AUTHORS) · [Patent grant](ios/Classes/Yuv/PATENTS)
