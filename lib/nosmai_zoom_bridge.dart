import 'package:flutter/services.dart';
import 'package:flutter_zoom_videosdk/native/zoom_videosdk.dart';

/// Uses the existing Zoom SDK instance and its normal session event stream.
abstract final class NosmaiZoomBridge {
  static const _zoom = MethodChannel('flutter_zoom_videosdk');

  /// Mount a NosmaiCameraPreview for the local camera, then join with this method.
  static Future<String> joinSession(JoinSessionConfig config) =>
      _join('nosmaiJoinSession', config);

  /// Hosts using Zoom's two-step join can commit or cancel through Zoom as usual.
  static Future<String> prepareJoin(JoinSessionConfig config,
          {int timeoutInterval = 0}) =>
      _join('nosmaiPrepareJoin', config, timeout: timeoutInterval);

  static Future<String> _join(String method, JoinSessionConfig config,
      {int? timeout}) async {
    try {
      final result = await _zoom.invokeMethod<String>(method, {
        'sessionName': config.sessionName,
        'sessionPassword': config.sessionPassword ?? '',
        'token': config.token,
        'userName': config.userName,
        'audioOptions': config.audioOptions ?? const <String, bool>{},
        'videoOptions': config.videoOptions ?? const <String, bool>{},
        'sessionIdleTimeoutMins': config.sessionIdleTimeoutMins,
        if (timeout != null) 'timeoutInterval': timeout,
      });
      return result ?? '';
    } on MissingPluginException {
      throw StateError('Run dart run nosmai_zoom_bridge:setup from the app, '
          'run flutter pub get and rebuild the native app.');
    }
  }
}
