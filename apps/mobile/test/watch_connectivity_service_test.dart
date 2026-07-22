import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/services/watch_connectivity_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(WatchConnectivityService.channelName);
  const codec = StandardMethodCodec();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<Object?> invokeFromWatch(Map<String, Object?> action) async {
    final reply = Completer<ByteData?>();
    final data = codec.encodeMethodCall(MethodCall('performAction', action));
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(channel.name, data, reply.complete);
    return codec.decodeEnvelope((await reply.future)!);
  }

  test('accepts an approval once and immediately clears it', () async {
    final fixture = await _WatchBridgeFixture.start();
    final outgoing = <ClientMessage>[];
    final bridge = BridgeService()..onOutgoingMessage = outgoing.add;
    final sessionReceived = bridge.sessionList.firstWhere(
      (sessions) => sessions.any((session) => session.id == 'watch-session'),
    );
    bridge.connect(fixture.url);
    await fixture.sessionDelivered;
    await sessionReceived;

    final service = WatchConnectivityService(bridge: bridge, channel: channel);
    await service.initialize();
    outgoing.clear();

    final action = <String, Object?>{
      'type': 'approve',
      'sessionId': 'watch-session',
      'toolUseId': 'watch-tool',
    };
    final first = await invokeFromWatch(action) as Map<Object?, Object?>;
    final second = await invokeFromWatch(action) as Map<Object?, Object?>;

    expect(first['accepted'], isTrue);
    expect(second['accepted'], isFalse);
    expect(bridge.sessions.single.pendingPermission, isNull);
    expect(bridge.respondedToolUseIds('watch-session'), contains('watch-tool'));
    expect(
      outgoing.where((message) {
        final json = jsonDecode(message.toJson()) as Map<String, dynamic>;
        return json['type'] == 'approve';
      }),
      hasLength(1),
    );

    await service.dispose();
    bridge.disconnect();
    bridge.dispose();
    await fixture.close();
  });

  test('rejects time-sensitive actions while Bridge is disconnected', () async {
    final fixture = await _WatchBridgeFixture.start();
    final outgoing = <ClientMessage>[];
    final bridge = BridgeService()..onOutgoingMessage = outgoing.add;
    final sessionReceived = bridge.sessionList.firstWhere(
      (sessions) => sessions.any((session) => session.id == 'watch-session'),
    );
    bridge.connect(fixture.url);
    await fixture.sessionDelivered;
    await sessionReceived;

    final service = WatchConnectivityService(bridge: bridge, channel: channel);
    await service.initialize();
    outgoing.clear();
    await fixture.disconnectClient();
    await bridge.connectionStatus.firstWhere(
      (state) => state != BridgeConnectionState.connected,
    );

    final response =
        await invokeFromWatch({
              'type': 'approve',
              'sessionId': 'watch-session',
              'toolUseId': 'watch-tool',
            })
            as Map<Object?, Object?>;

    expect(response['accepted'], isFalse);
    expect(response['message'], 'Bridge is disconnected');
    expect(
      outgoing.where((message) {
        final json = jsonDecode(message.toJson()) as Map<String, dynamic>;
        return json['type'] == 'approve';
      }),
      isEmpty,
    );

    await service.dispose();
    bridge.disconnect();
    bridge.dispose();
    await fixture.close();
  });
}

class _WatchBridgeFixture {
  final HttpServer server;
  final Completer<void> _sessionDelivered;
  WebSocket? _socket;

  _WatchBridgeFixture(this.server, this._sessionDelivered);

  String get url => 'ws://127.0.0.1:${server.port}';
  Future<void> get sessionDelivered => _sessionDelivered.future;

  static Future<_WatchBridgeFixture> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final delivered = Completer<void>();
    final fixture = _WatchBridgeFixture(server, delivered);
    server.transform(WebSocketTransformer()).listen((socket) {
      fixture._socket = socket;
      socket.add(
        jsonEncode({
          'type': 'session_list',
          'sessions': [
            {
              'id': 'watch-session',
              'projectPath': '/work/ccpocket',
              'status': 'waiting_approval',
              'createdAt': '2026-07-22T00:00:00Z',
              'lastActivityAt': '2026-07-22T01:00:00Z',
              'pendingPermission': {
                'toolUseId': 'watch-tool',
                'toolName': 'Bash',
                'input': {'command': 'flutter test'},
              },
            },
          ],
        }),
      );
      delivered.complete();
    });
    return fixture;
  }

  Future<void> disconnectClient() async {
    await _socket?.close();
  }

  Future<void> close() async {
    await _socket?.close();
    await server.close(force: true);
  }
}
