import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_zoom_videosdk/native/zoom_videosdk.dart';
import 'package:nosmai_effects_sdk/nosmai_effects_sdk.dart';
import 'package:nosmai_zoom_bridge/nosmai_zoom_bridge.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const MaterialApp(home: Publisher()));

class Publisher extends StatefulWidget {
  const Publisher({super.key});
  @override
  State<Publisher> createState() => _PublisherState();
}

class _PublisherState extends State<Publisher> {
  final zoom = ZoomVideoSdk();
  final room = TextEditingController(text: 'nosmai-test');
  final token = TextEditingController();
  final license = TextEditingController();
  StreamSubscription<dynamic>? events;
  bool initialized = false,
      cameraReady = false,
      joined = false,
      joining = false;
  bool working = false, smoothing = false;
  String status = '';

  Future<void> act(Future<void> Function() action) async {
    if (working) return;
    setState(() => working = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() {
          joining = false;
          status = error.toString();
        });
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> initialize() async {
    if (!(await Permission.camera.request()).isGranted) {
      throw StateError('Camera permission is required.');
    }
    if (!await NosmaiFlutter.initialize(license.text.trim())) {
      throw StateError('Check the Nosmai license and application ID.');
    }
    final result =
        await zoom.initSdk(InitConfig(domain: 'zoom.us', enableLog: false));
    if (result != 'SDK initialized successfully' && result != Errors.Success) {
      throw StateError(result);
    }
    if (!mounted) return;
    events = const EventChannel('eventListener')
        .receiveBroadcastStream()
        .listen((event) {
      if (!mounted || event is! Map) return;
      setState(() {
        if (event['name'] == 'onSessionJoin') {
          joining = false;
          joined = true;
          status = 'Connected';
        }
        if (event['name'] == 'onSessionLeave') {
          joining = false;
          joined = false;
          status = 'Session ended';
        }
        if (event['name'] == 'onError') {
          joining = false;
          status = 'Zoom error ${event['message']?['errorType']}';
        }
      });
    });
    setState(() {
      initialized = true;
      status = '';
    });
  }

  Future<void> join() async {
    setState(() {
      joining = true;
      status = 'Joining…';
    });
    final result = await NosmaiZoomBridge.joinSession(JoinSessionConfig(
      sessionName: room.text.trim(),
      token: token.text.trim(),
      userName: 'Nosmai camera',
      videoOptions: {'localVideoOn': true},
      audioOptions: {'connect': false, 'mute': true},
    ));
    if (result != 'Join Session Success' && result != Errors.Success) {
      throw StateError(result);
    }
  }

  @override
  void dispose() {
    events?.cancel();
    room.dispose();
    token.dispose();
    license.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Nosmai Zoom camera')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          if (!initialized) ...[
            TextField(
                controller: license,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Nosmai license key')),
            FilledButton(
                onPressed: working ? null : () => act(initialize),
                child: const Text('Start camera')),
          ] else ...[
            SizedBox(
                height: 300,
                child: NosmaiCameraPreview(
                  onInitialized: () {
                    if (mounted) setState(() => cameraReady = true);
                  },
                  onError: (message) {
                    if (mounted) {
                      setState(() {
                        cameraReady = false;
                        status = message;
                      });
                    }
                  },
                )),
            SwitchListTile(
                title: const Text('Skin smoothing'),
                value: smoothing,
                onChanged: !cameraReady || working
                    ? null
                    : (enabled) => act(() async {
                          await NosmaiFlutter.instance
                              .applySkinSmoothing(enabled ? 0.8 : 0);
                          if (mounted) setState(() => smoothing = enabled);
                        })),
            if (!joined && !joining) ...[
              TextField(
                  controller: room,
                  decoration: const InputDecoration(labelText: 'Session name')),
              TextField(
                  controller: token,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'Zoom session token')),
              FilledButton(
                  onPressed: working || !cameraReady ? null : () => act(join),
                  child: const Text('Join session')),
            ] else
              OutlinedButton(
                  onPressed: working
                      ? null
                      : () => act(() async {
                            await zoom.leaveSession(false);
                          }),
                  child: const Text('Leave session')),
          ],
          if (status.isNotEmpty) Text(status),
        ]),
      );
}
