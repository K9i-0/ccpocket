import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/services/watch_connectivity_service.dart';
import 'package:ccpocket/utils/session_ordering.dart';
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
        .setMockMethodCallHandler(
          channel,
          (call) async => call.method == 'activate' ? true : null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<Object?> invokeNative(
    String method,
    Map<String, Object?> arguments,
  ) async {
    final reply = Completer<ByteData?>();
    final data = codec.encodeMethodCall(MethodCall(method, arguments));
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(channel.name, data, reply.complete);
    return codec.decodeEnvelope((await reply.future)!);
  }

  Future<Object?> invokeFromWatch(Map<String, Object?> action) =>
      invokeNative('performAction', action);

  test('stays idle until a paired Watch app becomes available', () async {
    final fixture = await _WatchBridgeFixture.start();
    final outgoing = <ClientMessage>[];
    var snapshotCount = 0;
    final bridge = BridgeService()..onOutgoingMessage = outgoing.add;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'activate') return false;
          if (call.method == 'updateSnapshot') snapshotCount += 1;
          return null;
        });
    final service = WatchConnectivityService(bridge: bridge, channel: channel);
    await service.initialize();

    bridge.connect(fixture.url);
    await fixture.sessionDelivered;
    await Future<void>.delayed(const Duration(milliseconds: 50));

    bool sent(String type) => outgoing.any((message) {
      final json = jsonDecode(message.toJson()) as Map<String, dynamic>;
      return json['type'] == type;
    });
    expect(sent('get_usage'), isFalse);
    expect(snapshotCount, 0);

    await invokeNative('availabilityChanged', {'available': true});
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(sent('get_usage'), isTrue);
    expect(snapshotCount, greaterThan(0));

    await service.dispose();
    bridge.disconnect();
    bridge.dispose();
    await fixture.close();
  });

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

  test('returns the latest full cached assistant message on demand', () async {
    final fixture = await _WatchBridgeFixture.start(
      sessions: const [
        {
          'id': 'watch-session',
          'projectPath': '/work/ccpocket',
          'status': 'running',
          'createdAt': '2026-07-22T00:00:00Z',
          'lastActivityAt': '2026-07-22T01:00:00Z',
          'lastMessage': 'A detailed response ',
        },
      ],
    );
    final bridge = BridgeService();
    final sessionReceived = bridge.sessionList.firstWhere(
      (sessions) => sessions.any((session) => session.id == 'watch-session'),
    );
    bridge.connect(fixture.url);
    await fixture.sessionDelivered;
    await sessionReceived;

    final fullText = 'A detailed response ${'with useful context. ' * 20}';
    final assistantReceived = bridge
        .messagesForSession('watch-session')
        .firstWhere((message) => message is AssistantServerMessage);
    fixture.send({
      'type': 'assistant',
      'sessionId': 'watch-session',
      'message': {
        'id': 'assistant-full',
        'role': 'assistant',
        'model': 'test',
        'content': [
          {'type': 'text', 'text': fullText},
        ],
      },
    });
    await assistantReceived;

    final service = WatchConnectivityService(bridge: bridge, channel: channel);
    await service.initialize();
    final response =
        await invokeFromWatch({
              'type': 'latest_agent_message',
              'sessionId': 'watch-session',
            })
            as Map<Object?, Object?>;

    expect(response['accepted'], isTrue);
    expect(response['text'], fullText.trim());
    expect(response['truncated'], isFalse);

    await service.dispose();
    bridge.disconnect();
    bridge.dispose();
    await fixture.close();
  });

  test(
    'loads the latest resumed assistant message from past history',
    () async {
      final fixture = await _WatchBridgeFixture.start(
        sessions: const [
          {
            'id': 'watch-session',
            'projectPath': '/work/ccpocket',
            'provider': 'claude',
            'status': 'idle',
            'createdAt': '2026-07-22T00:00:00Z',
            'lastActivityAt': '2026-07-22T01:00:00Z',
            'lastMessage': 'Resumed response ',
          },
        ],
      );
      final fullText = 'Resumed response ${'with older context. ' * 20}'.trim();
      final bridge = BridgeService()
        ..onOutgoingMessage = (message) {
          final json = jsonDecode(message.toJson()) as Map<String, dynamic>;
          if (json['type'] != 'get_history') return;
          fixture
            ..send({
              'type': 'past_history',
              'sessionId': 'watch-session',
              'claudeSessionId': 'claude-session',
              'messages': [
                {
                  'role': 'assistant',
                  'content': [
                    {'type': 'text', 'text': fullText},
                  ],
                },
              ],
            })
            ..send({
              'type': 'history',
              'sessionId': 'watch-session',
              'messages': <Object?>[],
            });
        };
      final sessionReceived = bridge.sessionList.firstWhere(
        (sessions) => sessions.any((session) => session.id == 'watch-session'),
      );
      bridge.connect(fixture.url);
      await fixture.sessionDelivered;
      await sessionReceived;

      final service = WatchConnectivityService(
        bridge: bridge,
        channel: channel,
      );
      await service.initialize();
      final response =
          await invokeFromWatch({
                'type': 'latest_agent_message',
                'sessionId': 'watch-session',
              })
              as Map<Object?, Object?>;

      expect(response['accepted'], isTrue);
      expect(response['text'], fullText);

      await service.dispose();
      bridge.disconnect();
      bridge.dispose();
      await fixture.close();
    },
  );

  test('refreshes Watch order immediately after a mobile pin change', () async {
    final pinnedKey = sessionPinKey(
      provider: 'codex',
      projectPath: '/work/pinned',
      sessionId: 'provider-pinned',
    );
    final fixture = await _WatchBridgeFixture.start(
      sessions: const [
        {
          'id': 'normal',
          'projectPath': '/work/normal',
          'provider': 'codex',
          'claudeSessionId': 'provider-normal',
          'status': 'idle',
          'createdAt': '2026-07-22T00:00:00Z',
          'lastActivityAt': '2026-07-22T02:00:00Z',
        },
        {
          'id': 'pinned',
          'projectPath': '/work/pinned',
          'provider': 'codex',
          'claudeSessionId': 'provider-pinned',
          'status': 'running',
          'createdAt': '2026-07-22T00:00:00Z',
          'lastActivityAt': '2026-07-22T01:00:00Z',
        },
      ],
    );
    final bridge = BridgeService();
    final sessionReceived = bridge.sessionList.firstWhere(
      (sessions) => sessions.length == 2,
    );
    bridge.connect(fixture.url);
    await fixture.sessionDelivered;
    await sessionReceived;

    final initialSnapshotSent = Completer<Map<Object?, Object?>>();
    final pinnedSnapshotSent = Completer<Map<Object?, Object?>>();
    var snapshotCount = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'activate') return true;
          if (call.method == 'updateSnapshot') {
            snapshotCount += 1;
            final snapshot = call.arguments as Map<Object?, Object?>;
            if (snapshotCount == 1) {
              initialSnapshotSent.complete(snapshot);
            } else if (!pinnedSnapshotSent.isCompleted) {
              pinnedSnapshotSent.complete(snapshot);
            }
          }
          return null;
        });
    final service = WatchConnectivityService(bridge: bridge, channel: channel);
    await service.initialize();

    final initialSnapshot = await initialSnapshotSent.future;
    final initialSessions = initialSnapshot['sessions']! as List<Object?>;
    expect((initialSessions.first! as Map<Object?, Object?>)['id'], 'normal');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(pinnedSessionKeysPreferenceKey, [pinnedKey]);
    notifySessionOrderingChanged();

    final pinnedSnapshot = await pinnedSnapshotSent.future;
    final pinnedSessions = pinnedSnapshot['sessions']! as List<Object?>;
    expect((pinnedSessions.first! as Map<Object?, Object?>)['id'], 'pinned');

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

  static Future<_WatchBridgeFixture> start({
    List<Map<String, Object?>>? sessions,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final delivered = Completer<void>();
    final fixture = _WatchBridgeFixture(server, delivered);
    server.transform(WebSocketTransformer()).listen((socket) {
      fixture._socket = socket;
      socket.add(
        jsonEncode({
          'type': 'session_list',
          'sessions':
              sessions ??
              [
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

  void send(Map<String, Object?> message) {
    _socket?.add(jsonEncode(message));
  }

  Future<void> close() async {
    await _socket?.close();
    await server.close(force: true);
  }
}
