import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zoom_videosdk/native/zoom_videosdk.dart';
import 'package:nosmai_zoom_bridge/nosmai_zoom_bridge.dart';
import '../bin/setup.dart' as setup;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_zoom_videosdk');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final config = JoinSessionConfig(
      sessionName: 'test',
      token: 'synthetic',
      userName: 'Host',
      videoOptions: {'localVideoOn': false},
      audioOptions: {'mute': true},
      sessionIdleTimeoutMins: 8);
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test('join and prepare use Zoom session options and return native results',
      () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return 'accepted';
    });
    expect(await NosmaiZoomBridge.joinSession(config), 'accepted');
    expect(await NosmaiZoomBridge.prepareJoin(config, timeoutInterval: 12),
        'accepted');
    expect(
        calls.map((v) => v.method), ['nosmaiJoinSession', 'nosmaiPrepareJoin']);
    expect(calls.first.arguments, {
      'sessionName': 'test',
      'sessionPassword': '',
      'userName': 'Host',
      'token': 'synthetic',
      'videoOptions': {'localVideoOn': false},
      'audioOptions': {'mute': true},
      'sessionIdleTimeoutMins': 8
    });
    expect(calls.last.arguments['timeoutInterval'], 12);
  });
  test('missing adapter produces an actionable error', () async {
    await expectLater(NosmaiZoomBridge.joinSession(config), throwsStateError);
  });
  test('installer preserves unrelated overrides and refuses conflicting ones',
      () {
    const input = 'dependency_overrides:\n  other:\n    path: ../other\n';
    expect(setup.usesMainOverrides(input, ''), isTrue);
    expect(setup.usesMainOverrides(input, input), isFalse);
    final patched = setup.overrideText(input);
    expect(patched, contains('  other:\n    path: ../other'));
    expect(setup.overrideText(patched), patched);
    expect(
        () => setup
            .overrideText(input.replaceAll('other:', 'flutter_zoom_videosdk:')),
        throwsStateError);
  });
}
