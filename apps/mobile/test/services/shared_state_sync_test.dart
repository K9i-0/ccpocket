import 'dart:async';
import 'dart:convert';

import 'package:ccpocket/features/session_list/services/codex_project_profile_store.dart';
import 'package:ccpocket/features/session_list/services/session_resume_coordinator.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/providers/unseen_sessions_cubit.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/services/shared_state_adapters.dart';
import 'package:ccpocket/services/shared_state_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBridge extends BridgeService {
  final _ready = StreamController<bool>.broadcast(sync: true);
  final _messages = StreamController<ServerMessage>.broadcast(sync: true);
  final _connection = StreamController<BridgeConnectionState>.broadcast(
    sync: true,
  );
  final sent = <Map<String, dynamic>>[];

  @override
  Stream<bool> get sharedStateReady => _ready.stream;
  @override
  Stream<ServerMessage> get sharedStateMessages => _messages.stream;
  @override
  Stream<BridgeConnectionState> get connectionStatus => _connection.stream;
  @override
  String? get lastUrl => 'ws://bridge';

  @override
  void send(ClientMessage message) {
    sent.add(jsonDecode(message.toJson()) as Map<String, dynamic>);
  }

  List<Map<String, dynamic>> ofType(String type) => [
    for (final message in sent)
      if (message['type'] == type) message,
  ];

  void ready({bool supported = true}) => _ready.add(supported);
  void disconnect() => _connection.add(BridgeConnectionState.disconnected);
  void snapshot(Map<String, Object?> entries, {String storeId = 'store-1'}) =>
      _messages.add(SharedStateMessage(storeId: storeId, entries: entries));
  void changed(String key, Object? value, {String? mutationId}) =>
      _messages.add(
        SharedStateChangedMessage(
          key: key,
          value: value,
          mutationId: mutationId,
        ),
      );
  void seeded({String storeId = 'store-1'}) =>
      _messages.add(SharedStateSeededMessage(storeId: storeId));

  /// Echo the last `set_shared_state` for [key] like the Bridge does.
  void echo(Map<String, dynamic> set) => changed(
    set['key'] as String,
    set['value'],
    mutationId: set['mutationId'] as String,
  );
}

/// One in-memory entry map, to observe what the sync applies.
class _MapAdapter extends SharedStateAdapter {
  final String prefix;
  final Map<String, Object> local;
  final bool _seedable;
  _MapAdapter(this.prefix, this.local, {bool seedable = true})
    : _seedable = seedable;

  @override
  bool owns(String key) => key.startsWith(prefix);
  @override
  bool get seedable => _seedable;
  @override
  Future<Map<String, Object>> readLocal() async => {...local};
  @override
  Future<void> applyRemote(String key, Object? value) async {
    if (value == null) {
      local.remove(key);
    } else {
      local[key] = value;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeBridge bridge;
  late SharedPreferences prefs;
  late SharedStateSync sync;

  Future<void> start([Map<String, Object> initial = const {}]) async {
    SharedPreferences.setMockInitialValues(initial);
    prefs = await SharedPreferences.getInstance();
    bridge = _FakeBridge();
    sync = SharedStateSync(bridge: bridge, prefs: prefs);
    SharedStateSync.instance = sync;
  }

  tearDown(() {
    sync.dispose();
    bridge.dispose();
  });

  group('SharedStateSync', () {
    test('asks for the snapshot once the Bridge supports it', () async {
      await start();
      sync.set('a.x', 1);
      expect(bridge.sent, isEmpty);

      bridge.ready();
      expect(bridge.ofType('get_shared_state'), hasLength(1));
      // A write made before connecting goes out after the snapshot.
      expect(bridge.ofType('set_shared_state'), isEmpty);
      bridge.snapshot({});
      await sync.settled;
      expect(
        bridge.ofType('set_shared_state').single,
        containsPair('key', 'a.x'),
      );
    });

    test('stays local with a Bridge without shared state', () async {
      await start();
      final local = <String, Object>{'a.x': 1};
      sync.register(_MapAdapter('a.', local));
      sync.set('a.x', 1);

      bridge.ready(supported: false);
      sync.set('a.y', 2);

      expect(bridge.sent, isEmpty);
      expect(local, {'a.x': 1});
    });

    test('offers local entries once and keeps them until confirmed', () async {
      await start();
      final local = <String, Object>{'a.mine': 'local', 'a.both': 'local'};
      final unseedable = <String, Object>{'b.mine': 'local'};
      sync
        ..register(_MapAdapter('a.', local))
        ..register(_MapAdapter('b.', unseedable, seedable: false));

      bridge.ready();
      bridge.snapshot({'a.both': 'remote', 'a.theirs': 'remote'});
      await sync.settled;

      // The Bridge wins where it has a value; the rest is offered, not lost.
      expect(local, {
        'a.mine': 'local',
        'a.both': 'remote',
        'a.theirs': 'remote',
      });
      expect(unseedable, {'b.mine': 'local'});
      expect(bridge.ofType('seed_shared_state').single['entries'], {
        'a.mine': 'local',
      });
      expect(prefs.getStringList(SharedStateSync.seededStoreIdsKey), isNull);

      // The Bridge announces the adopted entries, then confirms.
      bridge.snapshot({
        'a.both': 'remote',
        'a.theirs': 'remote',
        'a.mine': 'local',
      });
      bridge.seeded();
      await sync.settled;
      expect(bridge.ofType('seed_shared_state'), hasLength(1));
      expect(prefs.getStringList(SharedStateSync.seededStoreIdsKey), [
        'store-1',
      ]);
    });

    test('a lost connection before the confirmation offers again', () async {
      await start();
      sync.register(_MapAdapter('a.', {'a.mine': 'local'}));
      bridge.ready();
      bridge.snapshot({});
      await sync.settled;
      bridge.disconnect();

      bridge.ready();
      bridge.snapshot({});
      await sync.settled;

      expect(bridge.ofType('seed_shared_state'), hasLength(2));
    });

    test('after seeding, the Bridge is the truth', () async {
      await start({
        SharedStateSync.seededStoreIdsKey: ['store-1'],
      });
      final local = <String, Object>{'a.gone': 'local', 'a.kept': 'old'};
      sync.register(_MapAdapter('a.', local));

      bridge.ready();
      bridge.snapshot({'a.kept': 'new'});
      await sync.settled;

      expect(local, {'a.kept': 'new'});
      expect(bridge.ofType('seed_shared_state'), isEmpty);

      // Another Bridge store is new to this device: nothing is removed.
      bridge.snapshot({}, storeId: 'store-2');
      await sync.settled;
      expect(local, {'a.kept': 'new'});
      expect(bridge.ofType('seed_shared_state').single['entries'], {
        'a.kept': 'new',
      });
    });

    test('changes from other devices are applied', () async {
      await start();
      final local = <String, Object>{};
      sync.register(_MapAdapter('a.', local));
      bridge.ready();
      bridge.snapshot({});

      bridge.changed('a.x', {'model': 'opus'});
      bridge.changed('other.x', 1);
      await sync.settled;
      expect(local, {
        'a.x': {'model': 'opus'},
      });

      bridge.changed('a.x', null);
      await sync.settled;
      expect(local, isEmpty);
    });

    test('quick writes are not reverted by the echo of the first', () async {
      await start();
      final local = <String, Object>{};
      sync.register(_MapAdapter('a.', local));
      bridge.ready();
      bridge.snapshot({});
      await sync.settled;

      local['a.x'] = 1;
      sync.set('a.x', 1);
      local['a.x'] = 2;
      sync.set('a.x', 2);
      final sets = bridge.ofType('set_shared_state');
      expect(sets, hasLength(2));

      bridge.echo(sets[0]);
      // Neither another device's write nor a snapshot replaces a pending one.
      bridge.changed('a.x', 99, mutationId: 'someone-else');
      bridge.snapshot({'a.x': 1});
      await sync.settled;
      expect(local, {'a.x': 2});

      bridge.echo(bridge.ofType('set_shared_state').last);
      await sync.settled;
      expect(local, {'a.x': 2});

      // Confirmed: the next change from elsewhere is taken again.
      bridge.changed('a.x', 3, mutationId: 'someone-else');
      await sync.settled;
      expect(local, {'a.x': 3});
    });

    test('an unconfirmed write is sent again after reconnecting', () async {
      await start();
      sync.register(_MapAdapter('a.', {}));
      bridge.ready();
      bridge.snapshot({});
      await sync.settled;
      sync.set('a.x', 1);
      bridge.disconnect();
      sync.set('a.x', 2);
      expect(bridge.ofType('set_shared_state'), hasLength(1));

      bridge.ready();
      bridge.snapshot({'a.x': 0});
      await sync.settled;

      final sets = bridge.ofType('set_shared_state');
      expect(sets, hasLength(2));
      expect(sets.last, containsPair('value', 2));
    });

    test(
      'takes the value the Bridge kept instead of the written one',
      () async {
        await start();
        final local = <String, Object>{'a.x': '2026-01-01'};
        sync.register(_MapAdapter('a.', local));
        bridge.ready();
        bridge.snapshot({'a.x': '2026-01-01'});
        await sync.settled;

        sync.set('a.x', '2026-01-01', max: true);
        final set = bridge.ofType('set_shared_state').single;
        expect(set['mode'], 'max');
        bridge.changed(
          'a.x',
          '2026-02-02',
          mutationId: set['mutationId'] as String,
        );
        await sync.settled;

        expect(local, {'a.x': '2026-02-02'});
      },
    );
  });

  group('adapters', () {
    test('local stores share their writes and take over remote ones', () async {
      await start({
        'claude_session_settings_s-old': jsonEncode({'model': 'sonnet'}),
        'new_session_additional_writable_root_history': ['/a'],
        'new_project_parent_ws://bridge': '/work',
        'session_start_defaults_claude_v1': jsonEncode({
          'provider': 'claude',
          'projectPath': '/p',
        }),
        'session_start_defaults_last_provider_v1': 'claude',
      });
      registerPrefsSharedStateAdapters(sync, prefs: prefs, bridge: bridge);
      bridge.ready();
      bridge.snapshot({
        'claude_session_settings/s-remote': {'model': 'opus'},
        'codex_profile/project:p1': 'work',
        'writable_root_history': ['/b', '/c'],
      });
      await sync.settled;

      // The Bridge's values are now the local copies.
      expect(await const ClaudeSessionSettingsStore().load('s-remote'), {
        'model': 'opus',
      });
      expect(
        await const CodexProjectProfileStore().load('/p', projectId: 'p1'),
        'work',
      );
      expect(
        prefs.getStringList('new_session_additional_writable_root_history'),
        ['/b', '/c'],
      );
      // What only this device had is offered.
      final seed = bridge.ofType('seed_shared_state').single['entries'] as Map;
      expect(seed.keys, {
        'claude_session_settings/s-old',
        'new_project_parent',
        'session_start_defaults.claude',
        'session_start_defaults.last_provider',
      });
      expect(seed['new_project_parent'], '/work');
      expect(seed['claude_session_settings/s-old'], {'model': 'sonnet'});

      // Writes through the stores are shared, merged like the local copy.
      bridge.sent.clear();
      await const ClaudeSessionSettingsStore().save('s-remote', {
        'effort': 'high',
      });
      await const CodexProjectProfileStore().save('/p', null, projectId: 'p1');
      expect(bridge.ofType('set_shared_state'), [
        containsPair('value', {'model': 'opus', 'effort': 'high'}),
        allOf(
          containsPair('key', 'codex_profile/project:p1'),
          containsPair('value', ''),
        ),
      ]);

      // A cleared profile from another device clears the local one.
      for (final set in bridge.ofType('set_shared_state')) {
        bridge.echo(set);
      }
      bridge.changed('codex_profile/project:p1', 'home');
      await sync.settled;
      expect(
        await const CodexProjectProfileStore().load('/p', projectId: 'p1'),
        'home',
      );
      bridge.changed('codex_profile/project:p1', '');
      await sync.settled;
      expect(
        await const CodexProjectProfileStore().load('/p', projectId: 'p1'),
        isNull,
      );
    });

    test('a session seen on another device is no longer unseen', () async {
      await start();
      final cubit = UnseenSessionsCubit();
      addTearDown(cubit.close);
      bridge.ready();
      bridge.snapshot({});
      await sync.settled;

      SessionInfo session(String id, String lastActivityAt) => SessionInfo(
        id: id,
        projectPath: '/p',
        status: 'idle',
        createdAt: '2026-11-01T00:00:00.000Z',
        lastActivityAt: lastActivityAt,
      );
      cubit.updateSessions([
        session('s1', '2026-11-20T10:00:00.000Z'),
        session('s2', '2026-11-20T10:00:00.000Z'),
      ]);
      expect(cubit.state, {'s1', 's2'});
      expect(bridge.ofType('seed_shared_state'), isEmpty);

      bridge.changed('seen_at/s1', '2026-11-21T10:00:00.000Z');
      // Older than the activity: s2 stays unseen.
      bridge.changed('seen_at/s2', '2026-11-19T10:00:00.000Z');
      await sync.settled;
      expect(cubit.state, {'s2'});

      cubit.markSeen('s2');
      final set = bridge.ofType('set_shared_state').single;
      expect(set['key'], 'seen_at/s2');
      expect(set['mode'], 'max');
      expect(set['value'], '2026-11-21T10:00:00.000Z');
      expect(cubit.state, isEmpty);
    });
  });
}
