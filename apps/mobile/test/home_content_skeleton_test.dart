import 'dart:async';

import 'package:ccpocket/features/session_list/state/session_list_cubit.dart';
import 'package:ccpocket/features/session_list/widgets/home_content.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/services/draft_service.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeletonizer/src/widgets/skeletonizer.dart';

/// Minimal mock for BridgeService that satisfies SessionListCubit.
class _MockBridgeService extends BridgeService {
  final _recentSessionsController =
      StreamController<List<RecentSession>>.broadcast();
  final _projectHistoryController = StreamController<List<String>>.broadcast();

  @override
  Stream<List<RecentSession>> get recentSessionsStream =>
      _recentSessionsController.stream;

  @override
  Stream<List<String>> get projectHistoryStream =>
      _projectHistoryController.stream;

  @override
  bool get recentSessionsHasMore => false;

  @override
  String? get currentProjectFilter => null;

  @override
  void switchProjectFilter(String? projectPath, {int pageSize = 20}) {}

  @override
  void requestSessionList() {}

  @override
  void requestRecentSessions({int? limit, int? offset, String? projectPath}) {}

  @override
  void requestProjectHistory() {}

  @override
  void send(ClientMessage message) {}

  @override
  void dispose() {
    _recentSessionsController.close();
    _projectHistoryController.close();
  }
}

RecentSession _session({
  required String id,
  String projectPath = '/home/user/project-a',
}) {
  return RecentSession(
    sessionId: id,
    firstPrompt: 'test prompt for $id',
    messageCount: 1,
    created: '2025-01-01T00:00:00Z',
    modified: '2025-01-01T00:00:00Z',
    gitBranch: 'main',
    projectPath: projectPath,
    isSidechain: false,
  );
}

SessionInfo _runningSession({required String id}) {
  return SessionInfo.fromJson({
    'id': id,
    'projectPath': '/home/user/project-a',
    'status': 'running',
    'createdAt': '2025-01-01T00:00:00Z',
    'lastActivityAt': '2025-01-01T00:00:00Z',
    'gitBranch': 'main',
    'lastMessage': 'Working on something',
    'messageCount': 1,
  });
}

Widget _buildHomeContent({
  List<SessionInfo> sessions = const [],
  List<RecentSession> recentSessions = const [],
  bool isInitialLoading = false,
  required SessionListCubit cubit,
  required DraftService draftService,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    theme: AppTheme.darkTheme,
    home: Scaffold(
      body: MultiBlocProvider(
        providers: [BlocProvider<SessionListCubit>.value(value: cubit)],
        child: RepositoryProvider<DraftService>.value(
          value: draftService,
          child: HomeContent(
            connectionState: BridgeConnectionState.connected,
            sessions: sessions,
            recentSessions: recentSessions,
            accumulatedProjectPaths: const {},
            selectedProject: null,
            searchQuery: '',
            isLoadingMore: false,
            isInitialLoading: isInitialLoading,
            hasMoreSessions: false,
            currentProjectFilter: null,
            onNewSession: () {},
            onTapRunning:
                (id, {projectPath, gitBranch, worktreePath, provider}) {},
            onStopSession: (_) {},
            onResumeSession: (_) {},
            onLongPressRecentSession: (_) {},
            onSelectProject: (_) {},
            onLoadMore: () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  late _MockBridgeService mockBridge;
  late SessionListCubit cubit;
  late DraftService draftService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    draftService = DraftService(prefs);
    mockBridge = _MockBridgeService();
    cubit = SessionListCubit(bridge: mockBridge);
  });

  tearDown(() {
    cubit.close();
    mockBridge.dispose();
  });

  group('HomeContent skeleton', () {
    testWidgets('shows Skeletonizer when isInitialLoading is true and '
        'no sessions exist', (tester) async {
      await tester.pumpWidget(
        _buildHomeContent(
          recentSessions: const [],
          isInitialLoading: true,
          cubit: cubit,
          draftService: draftService,
        ),
      );
      await tester.pump();

      // Skeletonizer internally renders as _Skeletonizer + SkeletonizerScope.
      // Use SkeletonizerScope to detect presence.
      expect(find.byType(SkeletonizerScope), findsOneWidget);
      // Section header should say "Recent Sessions"
      expect(find.text('Recent Sessions'), findsOneWidget);
    });

    testWidgets('shows empty state when isInitialLoading is false and '
        'no sessions exist', (tester) async {
      await tester.pumpWidget(
        _buildHomeContent(
          recentSessions: const [],
          isInitialLoading: false,
          cubit: cubit,
          draftService: draftService,
        ),
      );
      await tester.pump();

      // Skeletonizer should NOT be present
      expect(find.byType(SkeletonizerScope), findsNothing);
      // Empty state should show the "New Session" button
      expect(find.text('New Session'), findsOneWidget);
    });

    testWidgets('shows real session cards (not skeleton) when sessions exist '
        'and isInitialLoading is false', (tester) async {
      await tester.pumpWidget(
        _buildHomeContent(
          recentSessions: [
            _session(id: 's1'),
            _session(id: 's2'),
          ],
          isInitialLoading: false,
          cubit: cubit,
          draftService: draftService,
        ),
      );
      await tester.pump();

      // No skeleton
      expect(find.byType(SkeletonizerScope), findsNothing);
      // Real session cards should be visible
      expect(find.text('test prompt for s1'), findsOneWidget);
      expect(find.text('test prompt for s2'), findsOneWidget);
    });

    testWidgets('shows skeleton below running sessions when '
        'isInitialLoading is true', (tester) async {
      await tester.pumpWidget(
        _buildHomeContent(
          sessions: [_runningSession(id: 'r1')],
          recentSessions: const [],
          isInitialLoading: true,
          cubit: cubit,
          draftService: draftService,
        ),
      );
      await tester.pump();

      // Running session section should be visible
      expect(find.text('Running'), findsAtLeast(1));
      // Skeleton should show for recent sessions section
      expect(find.byType(SkeletonizerScope), findsOneWidget);
      expect(find.text('Recent Sessions'), findsOneWidget);
    });

    testWidgets('shows real recent sessions (not skeleton) below running '
        'sessions when loaded', (tester) async {
      await tester.pumpWidget(
        _buildHomeContent(
          sessions: [_runningSession(id: 'r1')],
          recentSessions: [_session(id: 's1')],
          isInitialLoading: false,
          cubit: cubit,
          draftService: draftService,
        ),
      );
      await tester.pump();

      // Running section visible
      expect(find.text('Running'), findsAtLeast(1));
      // No skeleton
      expect(find.byType(SkeletonizerScope), findsNothing);
      // Real recent session visible
      expect(find.text('test prompt for s1'), findsOneWidget);
    });

    testWidgets('does NOT show skeleton when sessions exist even if '
        'isInitialLoading is true', (tester) async {
      // This scenario shouldn't normally happen, but tests the guard
      await tester.pumpWidget(
        _buildHomeContent(
          recentSessions: [_session(id: 's1')],
          isInitialLoading: true,
          cubit: cubit,
          draftService: draftService,
        ),
      );
      await tester.pump();

      // Skeleton should NOT show because sessions exist
      expect(find.byType(SkeletonizerScope), findsNothing);
      // Real session card should be shown
      expect(find.text('test prompt for s1'), findsOneWidget);
    });
  });
}
