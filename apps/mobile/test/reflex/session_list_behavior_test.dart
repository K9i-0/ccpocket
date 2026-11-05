// Reflex-style behavior tests for the session list.
//
// Real BridgeService + real SessionListCubit, driven through the Reflex node.
// Only the WebSocket is replaced by FixtureBridge. Assertions read the node's
// state JSON and the requests the fixture received.
import 'package:ccpocket/features/session_list/state/session_list_cubit.dart';
import 'package:ccpocket/features/session_list/state/session_list_reflex.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixture_bridge.dart';
import 'fixtures/recent_sessions_fixture.dart';
import 'reflex_driver.dart';

final _recent = [
  recentSession('c1', name: 'Fix login', firstPrompt: 'fix the login bug'),
  recentSession('c2', firstPrompt: 'add dark mode'),
  recentSession('x1', provider: 'codex', name: 'Refactor API'),
  recentSession(
    'x2',
    provider: 'codex',
    firstPrompt: 'fix flaky test',
    projectPath: '/work/api',
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FixtureBridge fixture;
  late BridgeService bridge;
  late SessionListCubit cubit;
  late ReflexDriver app;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fixture = FixtureBridge(handlers: sessionListFixture(_recent));
    bridge = fixture.connect();
    cubit = SessionListCubit(bridge: bridge);
    app = ReflexDriver(SessionListReflexNode(cubit));
  });

  tearDown(() async {
    await cubit.close();
    bridge.dispose();
    expect(fixture.unhandled, isEmpty, reason: 'requests without a fixture');
  });

  Future<void> loadInitialList() async {
    await app.act('refresh');
    await app.precondition(
      'initial list loaded',
      (s) => s['isInitialLoading'] == false,
    );
  }

  test('refresh loads the recent sessions from the Bridge', () async {
    await loadInitialList();

    expect(ReflexDriver.sessionIds(app.state), ['c1', 'c2', 'x1', 'x2']);
    expect(
      fixture.received.map((r) => r['type']),
      containsAll([
        'list_sessions',
        'list_recent_sessions',
        'list_project_history',
        'list_projects',
      ]),
    );
  });

  test(
    'provider filter asks the Bridge and shows only that provider',
    () async {
      await loadInitialList();

      await app.act('setProviderFilter', {'provider': 'codex'});
      final state = await app.precondition(
        'codex sessions shown',
        (s) =>
            s['isInitialLoading'] == false &&
            ReflexDriver.sessionIds(s).every((id) => id.startsWith('x')),
      );

      expect(state['providerFilter'], 'codex');
      expect(ReflexDriver.sessionIds(state), ['x1', 'x2']);
      expect(
        fixture.requestsOf('list_recent_sessions').last['provider'],
        'codex',
      );
    },
  );

  test('search is debounced into one request', () async {
    await loadInitialList();
    final before = fixture.requestsOf('list_recent_sessions').length;

    await app.act('setSearchQuery', {'query': 'f'});
    await app.act('setSearchQuery', {'query': 'fi'});
    await app.act('setSearchQuery', {'query': 'fix'});
    final state = await app.precondition(
      'search results shown',
      (s) => ReflexDriver.sessionIds(s).length == 2,
    );

    expect(ReflexDriver.sessionIds(state), ['c1', 'x2']);
    final searches = fixture.requestsOf('list_recent_sessions').skip(before);
    expect(searches.map((r) => r['searchQuery']), ['fix']);
  });

  test('named-only combines with the provider filter', () async {
    await loadInitialList();

    await app.act('setProviderFilter', {'provider': 'claude'});
    await app.act('toggleNamedOnly');
    final state = await app.precondition(
      'named claude sessions shown',
      (s) =>
          s['isInitialLoading'] == false &&
          ReflexDriver.sessionIds(s).length == 1,
    );

    expect(ReflexDriver.sessionIds(state), ['c1']);
    final last = fixture.requestsOf('list_recent_sessions').last;
    expect(last['provider'], 'claude');
    expect(last['namedOnly'], isTrue);
  });

  test('pinning a session is reflected in state and persisted', () async {
    await loadInitialList();

    await app.act('togglePinned', {'sessionId': 'x1'});
    final state = await app.precondition(
      'x1 pinned',
      (s) => (s['sessions']! as List).any(
        (e) => (e as Map)['id'] == 'x1' && e['pinned'] == true,
      ),
    );

    expect(
      (state['sessions']! as List).where((e) => (e as Map)['pinned'] == true),
      hasLength(1),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('session_list_pinned_session_keys_v1'), [
      'codex\n/work/app\nx1',
    ]);
  });

  test('a failed list request ends loading instead of spinning', () async {
    fixture.on(
      'list_recent_sessions',
      (request) => [
        {
          'type': 'error',
          'message': 'Failed to list recent sessions: boom',
          'errorCode': 'recent_sessions_failed',
          'requestScope': request['requestScope'],
          'requestId': request['requestId'],
          'offset': request['offset'],
        },
      ],
    );

    await app.act('refresh');
    final state = await app.precondition(
      'loading ended',
      (s) => s['isInitialLoading'] == false,
    );

    expect(state['sessions'], isEmpty);
  });

  test('unknown actions are rejected with the node name', () async {
    expect(
      () => app.act('deleteEverything'),
      throwsA(predicate((e) => e.toString().contains('on session_list'))),
    );
  });
}
