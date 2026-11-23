# Zoom camera example

Initialize the camera with a Nosmai license for the example application ID and use a Zoom Video SDK session JWT for the room you want to join. The Android application ID is `com.nosmai.nosmai_zoom_example`. Use the iOS bundle ID from the Runner target for an iOS license.

Run these commands from this directory.

```sh
flutter pub get
dart run nosmai_zoom_bridge:setup
flutter pub get
flutter run
```

Tap **Start camera**, enter the session name and token, and tap **Join session**. Toggle **Skin smoothing** while watching from a second participant in the same session.
