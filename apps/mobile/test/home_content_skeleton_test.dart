import 'dart:async';

import 'package:ccpocket/features/session_list/state/session_list_cubit.dart';
import 'package:ccpocket/features/session_list/state/session_list_state.dart';
import 'package:ccpocket/features/session_list/widgets/home_content.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/models/offline_pending_action.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/services/draft_service.dart';
import 'package:ccpocket/services/in_app_review_service.dart';
import 'package:ccpocket/services/revenuecat_service.dart';
import 'package:ccpocket/services/support_banner_service.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
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
    created: '2025-01-01T00:00:00Z',
    modified: '2025-01-01T00:00:00Z',
    gitBranch: 'main',
    projectPath: projectPath,
    isSidechain: false,
  );
}

SessionInfo _runningSession({
  required String id,
  String projectPath = '/home/user/project-a',
  String? projectId,
  String? projectName,
}) {
  return SessionInfo.fromJson({
    'id': id,
    'projectPath': projectPath,
    'status': 'running',
    'createdAt': '2025-01-01T12:00:00Z',
    'lastActivityAt': '2025-01-01T12:00:00Z',
    'gitBranch': 'main',
    'lastMessage': 'Working on something',
    'messageCount': 1,
    if (projectId != null)
      'workspace': {
        'kind': 'project',
        'projectId': projectId,
        'projectName': projectName,
        'rootPaths': [projectPath],
      },
  });
}

Widget _buildHomeContent({
  List<SessionInfo> sessions = const [],
  List<OfflinePendingAction> offlinePendingActions = const [],
  List<RecentSession> recentSessions = const [],
  List<WorkspaceProject> workspaceProjects = const [],
  Set<String> accumulatedProjectPaths = const {},
  Set<String> pinnedProjectPaths = const {},
  Set<String> exhaustedProjectPaths = const {},
  Map<String, int> projectSessionDisplayLimits = const {},
  String? currentProjectFilter,
  bool hasMoreSessions = false,
  bool isInitialLoading = false,
  bool showMacOSNativeAppBanner = false,
  UsageInfo? codexUsageOverride,
  VoidCallback? onOpenUsageSettings,
  VoidCallback? onDismissMacOSNativeAppBanner,
  ValueChanged<String?>? onSelectProject,
  required SessionListCubit cubit,
  required DraftService draftService,
  required RevenueCatService revenueCatService,
  required SupportBannerService supportBannerService,
}) {
  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<DraftService>.value(value: draftService),
      RepositoryProvider<RevenueCatService>.value(value: revenueCatService),
      ChangeNotifierProvider<SupportBannerService>.value(
        value: supportBannerService,
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: MultiBlocProvider(
          providers: [BlocProvider<SessionListCubit>.value(value: cubit)],
          child: HomeContent(
            connectionState: BridgeConnectionState.connected,
            sessions: sessions,
            offlinePendingActions: offlinePendingActions,
            recentSessions: recentSessions,
            workspaceProjects: workspaceProjects,
            accumulatedProjectPaths: accumulatedProjectPaths,
            pinnedProjectPaths: pinnedProjectPaths,
            exhaustedProjectPaths: exhaustedProjectPaths,
            projectSessionDisplayLimits: projectSessionDisplayLimits,
            searchQuery: '',
            isLoadingMore: false,
            isInitialLoading: isInitialLoading,
            hasMoreSessions: hasMoreSessions,
            currentProjectFilter: currentProjectFilter,
            onNewSession: () {},
            onTapRunning: (
              id, {
              projectPath,
              gitBranch,
              worktreePath,
              provider,
              permissionMode,
              sandboxMode,
              approvalPolicy,
              approvalsReviewer,
            }) {},
            onStopSession: (_) {},
            onResumeSession: (_) {},
            onLongPressRecentSession: (_, _) {},
            onArchiveSession: (_) {},
            onLongPressRunningSession: (_, _) {},
            onSelectProject: onSelectProject ?? (_) {},
            onLoadMore: () {},
            onLoadMoreProject: (_) {},
            providerFilter: ProviderFilter.all,
            namedOnly: false,
            onToggleProvider: () {},
            onToggleNamed: () {},
            showMacOSNativeAppBanner: showMacOSNativeAppBanner,
            codexUsageOverride: codexUsageOverride,
            onOpenUsageSettings: onOpenUsageSettings,
            onDismissMacOSNativeAppBanner: onDismissMacOSNativeAppBanner,
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
  late RevenueCatService revenueCatService;
  late SupportBannerService supportBannerService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    draftService = DraftService(prefs);
    revenueCatService = RevenueCatService(
      publicApiKey: '',
      platform: TargetPlatform.macOS,
    );
    supportBannerService = SupportBannerService(
      prefs: prefs,
      reviewService: InAppReviewService(
        prefs: prefs,
        appVersionLoader: () async => '1.0.0',
      ),
    );
    mockBridge = _MockBridgeService();
    cubit = SessionListCubit(bridge: mockBridge);
  });

  tearDown(() async {
    cubit.close();
    mockBridge.dispose();
    await revenueCatService.dispose();
  });

  group('HomeContent skeleton', () {
    testWidgets('lists a workspace Project with no loaded recent session', (
      tester,
    ) async {
      String? selectedProject;
      await tester.pumpWidget(
        _buildHomeContent(
          workspaceProjects: const [
            WorkspaceProject(
              id: 'mobile-api',
              name: 'Mobile + API',
              rootPaths: ['/workspace/mobile', '/workspace/api'],
              createdAt: '2026-09-01T00:00:00Z',
              updatedAt: '2026-09-01T00:00:00Z',
            ),
          ],
          onSelectProject: (project) => selectedProject = project,
          cubit: cubit,
          draftService: draftService,
          revenueCatService: revenueCatService,
          supportBannerService: supportBannerService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('project_filter_chip')));
      await tester.pumpAndSettle();
      expect(find.text('Mobile + API'), findsOneWidget);

      await tester.tap(find.text('Mobile + API'));
      await tester.pumpAndSettle();
      expect(selectedProject, 'project:mobile-api');
    });

    testWidgets('lists both a workspace Project and its primary folder', (
      tester,
    ) async {
      String? selectedProject;
      final assignedSession = RecentSession(
        sessionId: 'assigned-session',
        firstPrompt: 'assigned prompt',
        created: '2025-01-01T00:00:00Z',
        modified: '2025-01-01T00:00:00Z',
        gitBranch: 'main',
        projectPath: '/workspace/.worktrees/feature',
        isSidechain: false,
        workspace: const SessionWorkspaceInfo(
          kind: 'project',
          projectId: 'flutter-apps',
          projectName: 'Flutter apps',
          rootPaths: ['/workspace/flutter-primary', '/workspace/flutter-ui'],
        ),
      );
      await tester.pumpWidget(
        _buildHomeContent(
          recentSessions: [assignedSession],
          accumulatedProjectPaths: const {'/workspace/.worktrees/feature'},
          workspaceProjects: const [
            WorkspaceProject(
              id: 'flutter-apps',
              name: 'Flutter apps',
              rootPaths: [
                '/workspace/flutter-primary',
                '/workspace/flutter-ui',
              ],
              createdAt: '2026-09-01T00:00:00Z',
              updatedAt: '2026-09-01T00:00:00Z',
            ),
          ],
          onSelectProject: (project) => selectedProject = project,
          cubit: cubit,
          draftService: draftService,
          revenueCatService: revenueCatService,
          supportBannerService: supportBannerService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('project_filter_chip')));
      await tester.pumpAndSettle();
      expect(find.text('Flutter apps'), findsWidgets);
      expect(find.text('flutter-primary'), findsOneWidget);
      expect(find.text('feature'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Flutter apps').first).dy,
        lessThan(tester.getTopLeft(find.text('flutter-primary')).dy),
      );

      await tester.tap(find.text('flutter-primary'));
      await tester.pumpAndSettle();
      expect(selectedProject, '/workspace/flutter-primary');

      await tester.tap(find.byKey(const ValueKey('project_filter_chip')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flutter apps').first);
      await tester.pumpAndSettle();
      expect(selectedProject, 'project:flutter-apps');
    });

    testWidgets('prioritizes a pinned workspace Project in running sessions '
        'and the project filter', (tester) async {
      await tester.pumpWidget(
        _buildHomeContent(
          sessions: [
            _runningSession(
              id: 'other',
              projectPath: '/workspace/other',
              projectId: 'other',
              projectName: 'Other Project',
            ),
            _runningSession(
              id: 'pinned',
              projectPath: '/workspace/pinned',
              projectId: 'pinned',
              projectName: 'Pinned Project',
            ),
          ],
          workspaceProjects: const [
            WorkspaceProject(
              id: 'other',
              name: 'Other Project',
              rootPaths: ['/workspace/other'],
              createdAt: '2026-09-01T00:00:00Z',
              updatedAt: '2026-09-01T00:00:00Z',
            ),
            WorkspaceProject(
              id: 'pinned',
              name: 'Pinned Project',
              rootPaths: ['/workspace/pinned'],
              createdAt: '2026-09-01T00:00:00Z',
              updatedAt: '2026-09-01T00:00:00Z',
            ),
          ],
          pinnedProjectPaths: const {'project:pinned'},
          cubit: cubit,
          draftService: draftService,
          revenueCatService: revenueCatService,
          supportBannerService: supportBannerService,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('running_session_pinned')))
            .dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const ValueKey('running_session_other')))
              .dy,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('project_filter_chip')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.getTopLeft(find.text('Pinned Project').last).dy,
        lessThan(tester.getTopLeft(find.text('Other Project').last).dy),
      );
    });

    testWidgets('shows Skeletonizer when isInitialLoading is true and '
        'no sessions exist', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _buildHomeContent(
            recentSessions: const [],
            isInitialLoading: true,
            cubit: cubit,
            draftService: draftService,
            revenueCatService: revenueCatService,
            supportBannerService: supportBannerService,
          ),
        );
        await tester.pump();

        // Skeletonizer internally renders as _Skeletonizer +
        // SkeletonizerScope. Use SkeletonizerScope to detect presence.
        expect(find.byType(SkeletonizerScope), findsOneWidget);
        expect(find.text('Recent Sessions'), findsOneWidget);
        expect(find.text('No active sessions'), findsOneWidget);
        expect(find.text('Loading sessions...'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('session_list_loading_status')),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('Loading sessions...'), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp('Implement the new feature')),
          findsNothing,
        );
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('shows empty state when isInitialLoading is false and '
        'no sessions exist', (tester) async {
      await tester.pumpWidget(
        _buildHomeContent(
          recentSessions: const [],
          isInitialLoading: false,
          cubit: cubit,
          draftService: draftService,
          revenueCatService: revenueCatService,
          supportBannerService: supportBannerService,
        ),
      );
      await tester.pump();

      // Skeletonizer should NOT be present
      expect(find.byType(SkeletonizerScope), findsNothing);
      // Empty state should show the "New Session" button
      expect(find.text('New Session'), findsOneWidget);
      expect(find.text('Running'), findsOneWidget);
      expect(find.text('No active sessions'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('running_sessions_empty_message')),
        findsOneWidget,
      );
    });

    testWidgets('keeps Codex usage visible when no session is active', (
      tester,
    ) async {
      var tapCount = 0;
      await tester.pumpWidget(
        _buildHomeContent(
          recentSessions: [_session(id: 's1')],
          codexUsageOverride: const UsageInfo(
            provider: 'codex',
            sevenDay: UsageWindow(utilization: 14, resetsAt: ''),
          ),
          onOpenUsageSettings: () => tapCount++,
          cubit: cubit,
          draftService: draftService,
          revenueCatService: revenueCatService,
          supportBannerService: supportBannerService,
        ),
      );
      await tester.pump();

      expect(find.text('Running'), findsOneWidget);
      expect(find.text('No active sessions'), findsOneWidget);
      expect(find.text('Codex Remaining'), findsOneWidget);
      expect(find.text('1w 86%'), findsOneWidget);
      expect(
        tester
            .getRect(find.byKey(const ValueKey('codex_usage_summary_button')))
            .height,
        44,
      );

      await tester.tap(
        find.byKey(const ValueKey('codex_usage_summary_button')),
      );
      expect(tapCount, 1);
    });

    testWidgets('keeps the 44px usage target with an active session', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHomeContent(
          sessions: [_runningSession(id: 'r1')],
          recentSessions: [_session(id: 's1')],
          codexUsageOverride: const UsageInfo(
            provider: 'codex',
            sevenDay: UsageWindow(utilization: 14, resetsAt: ''),
          ),
          onOpenUsageSettings: () {},
          cubit: cubit,
          draftService: draftService,
          revenueCatService: revenueCatService,
          supportBannerService: supportBannerService,
        ),
      );
      await tester.pump();

      expect(
        tester
            .getRect(find.byKey(const ValueKey('codex_usage_summary_button')))
            .height,
        44,
      );
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
          revenueCatService: revenueCatService,
          supportBannerService: supportBannerService,
        ),
      );
      await tester.pump();

      // No skeleton
      expect(find.byType(SkeletonizerScope), findsNothing);
      // Real session cards should be visible
      expect(find.text('test prompt for s1'), findsOneWidget);
      expect(find.text('test prompt for s2'), findsOneWidget);
    });

    testWidgets('hides a project after its recent sessions are exhausted', (
      tester,
    ) async {
      const emptyProject = '/home/user/empty-project';
      const activeProject = '/home/user/active-project';
      await tester.pumpWidget(
        _buildHomeContent(
          recentSessions: [_session(id: 's1', projectPath: activeProject)],
          accumulatedProjectPaths: const {emptyProject, activeProject},
          exhaustedProjectPaths: const {emptyProject, activeProject},
          isInitialLoading: false,
          cubit: cubit,
          draftService: draftService,
          revenueCatService: revenueCatService,
          supportBannerService: supportBannerService,
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('project_header_$emptyProject')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('project_header_$activeProject')),
        findsOneWidget,
      );
    });

    testWidgets('hides an unloaded project until it has a session', (
      tester,
    ) async {
      const unloadedProject = '/home/user/unloaded-project';
      await tester.pumpWidget(
        _buildHomeContent(
          accumulatedProjectPaths: const {unloadedProject},
          isInitialLoading: false,
          cubit: cubit,
          draftService: draftService,
          revenueCatService: revenueCatService,
          supportBannerService: supportBannerService,
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('project_header_$unloadedProject')),
        findsNothing,
      );
    });

    testWidgets(
      'keeps global pagination when empty project headers are hidden',
      (tester) async {
        const unloadedProject = '/home/user/unloaded-project';
        await tester.pumpWidget(
          _buildHomeContent(
            accumulatedProjectPaths: const {unloadedProject},
            hasMoreSessions: true,
            isInitialLoading: false,
            cubit: cubit,
            draftService: draftService,
            revenueCatService: revenueCatService,
            supportBannerService: supportBannerService,
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const ValueKey('project_header_$unloadedProject')),
          findsNothing,
        );
        expect(find.byKey(const ValueKey('load_more_button')), findsOneWidget);
      },
    );

    testWidgets('shows only five sessions per project by default', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHomeContent(
          recentSessions: [for (var i = 1; i <= 6; i++) _session(id: 's$i')],
          isInitialLoading: false,
          cubit: cubit,
          draftService: draftService,
          revenueCatService: revenueCatService,
          supportBannerService: supportBannerService,
        ),
      );
      await tester.pump();

      expect(find.text('test prompt for s1'), findsOneWidget);
      expect(find.text('test prompt for s5'), findsOneWidget);
      expect(find.text('test prompt for s6'), findsNothing);
      expect(
        find.byKey(const ValueKey('project_show_more_/home/user/project-a')),
        findsOneWidget,
      );
    });

    testWidgets(
      'shows expanded project sessions after display limit increases',
      (tester) async {
        await tester.pumpWidget(
          _buildHomeContent(
            recentSessions: [for (var i = 1; i <= 6; i++) _session(id: 's$i')],
            exhaustedProjectPaths: const {'/home/user/project-a'},
            projectSessionDisplayLimits: const {'/home/user/project-a': 25},
            isInitialLoading: false,
            cubit: cubit,
            draftService: draftService,
            revenueCatService: revenueCatService,
            supportBannerService: supportBannerService,
          ),
        );
        await tester.pump();

        expect(find.text('test prompt for s6'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('project_show_more_/home/user/project-a')),
          findsNothing,
        );
      },
    );

    testWidgets('ungrouped toggle reveals loaded sessions and persists', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHomeContent(
          recentSessions: [for (var i = 1; i <= 6; i++) _session(id: 's$i')],
          exhaustedProjectPaths: const {'/home/user/project-a'},
          isInitialLoading: false,
          cubit: cubit,
          draftService: draftService,
          revenueCatService: revenueCatService,
          supportBannerService: supportBannerService,
        ),
      );
      await tester.pump();

      expect(find.text('test prompt for s6'), findsNothing);
      expect(
        find.byKey(const ValueKey('project_show_more_/home/user/project-a')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('recent_grouping_toggle')));
      await tester.pumpAndSettle();

      expect(
        find.text('test prompt for s6', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('project_show_more_/home/user/project-a')),
        findsNothing,
      );
      expect(find.text('List'), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('session_list_group_recent_sessions'), isFalse);
    });

    testWidgets('ungrouped mode uses global load more pagination', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHomeContent(
          recentSessions: [_session(id: 's1')],
          hasMoreSessions: true,
          isInitialLoading: false,
          cubit: cubit,
          draftService: draftService,
          revenueCatService: revenueCatService,
          supportBannerService: supportBannerService,
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('recent_grouping_toggle')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('project_show_more_/home/user/project-a')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('load_more_button')), findsOneWidget);
    });

    testWidgets('hides project Show more when project is exhausted', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHomeContent(
          recentSessions: [_session(id: 's1')],
          exhaustedProjectPaths: const {'/home/user/project-a'},
          isInitialLoading: false,
          cubit: cubit,
          draftService: draftService,
          revenueCatService: revenueCatService,
          supportBannerService: supportBannerService,
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('project_show_more_/home/user/project-a')),
        findsNothing,
      );
    });

    testWidgets(
      'uses global load more instead of project Show more in filter',
      (tester) async {
        await tester.pumpWidget(
          _buildHomeContent(
            recentSessions: [_session(id: 's1')],
            currentProjectFilter: '/home/user/project-a',
            hasMoreSessions: true,
            isInitialLoading: false,
            cubit: cubit,
            draftService: draftService,
            revenueCatService: revenueCatService,
            supportBannerService: supportBannerService,
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const ValueKey('project_show_more_/home/user/project-a')),
          findsNothing,
        );
        expect(find.byKey(const ValueKey('load_more_button')), findsOneWidget);
      },
    );

    testWidgets('shows skeleton below running sessions when '
        'isInitialLoading is true', (tester) async {
      await tester.pumpWidget(
        _buildHomeContent(
          sessions: [_runningSession(id: 'r1')],
          recentSessions: const [],
          isInitialLoading: true,
          cubit: cubit,
          draftService: draftService,
          revenueCatService: revenueCatService,
          supportBannerService: supportBannerService,
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
          revenueCatService: revenueCatService,
          supportBannerService: supportBannerService,
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

    testWidgets(
      'shows pending resume under Running and hides matching Recent',
      (tester) async {
        await tester.pumpWidget(
          _buildHomeContent(
            offlinePendingActions: [
              OfflinePendingAction(
                id: 'pending-resume-s1',
                kind: OfflinePendingActionKind.resume,
                projectPath: '/home/user/project-a',
                provider: 'claude',
                sessionId: 's1',
                createdAt: DateTime.utc(2026, 1, 1),
              ),
            ],
            recentSessions: [
              _session(id: 's1'),
              _session(id: 's2'),
            ],
            isInitialLoading: false,
            cubit: cubit,
            draftService: draftService,
            revenueCatService: revenueCatService,
            supportBannerService: supportBannerService,
          ),
        );
        await tester.pump();

        expect(find.text('Running'), findsOneWidget);
        expect(find.text('Resume pending'), findsOneWidget);
        expect(find.text('test prompt for s1'), findsNothing);
        expect(find.text('test prompt for s2'), findsOneWidget);
      },
    );

    testWidgets('labels an accepted resume as restoring', (tester) async {
      await tester.pumpWidget(
        _buildHomeContent(
          offlinePendingActions: [
            OfflinePendingAction(
              id: 'processing-resume-s1',
              kind: OfflinePendingActionKind.resume,
              state: OfflinePendingActionState.processing,
              canCancel: false,
              projectPath: '/home/user/project-a',
              provider: 'codex',
              sessionId: 's1',
              createdAt: DateTime.utc(2026, 1, 1),
            ),
          ],
          recentSessions: [_session(id: 's1')],
          isInitialLoading: false,
          cubit: cubit,
          draftService: draftService,
          revenueCatService: revenueCatService,
          supportBannerService: supportBannerService,
        ),
      );
      await tester.pump();

      expect(find.text('Restoring'), findsOneWidget);
      expect(
        find.text('Sessions with many images may take longer'),
        findsOneWidget,
      );
      expect(find.text('Loading session history'), findsOneWidget);
      expect(find.text('Processing on Bridge'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('pending_session_cancel_button')),
        findsNothing,
      );
    });

    testWidgets('shows skeleton while loading even if recent sessions exist', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHomeContent(
          recentSessions: [_session(id: 's1')],
          isInitialLoading: true,
          cubit: cubit,
          draftService: draftService,
          revenueCatService: revenueCatService,
          supportBannerService: supportBannerService,
        ),
      );
      await tester.pump();

      // While loading, skeleton should be preferred over stale cards.
      expect(find.byType(SkeletonizerScope), findsOneWidget);
      expect(find.text('test prompt for s1'), findsNothing);
    });

    testWidgets('shows macOS native app banner when requested', (tester) async {
      await tester.pumpWidget(
        _buildHomeContent(
          recentSessions: [_session(id: 's1')],
          showMacOSNativeAppBanner: true,
          cubit: cubit,
          draftService: draftService,
          revenueCatService: revenueCatService,
          supportBannerService: supportBannerService,
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('macos_native_app_banner')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('macos_native_app_banner_open_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('macos_native_app_banner_dismiss_button')),
        findsOneWidget,
      );
    });

    testWidgets('calls dismiss callback from macOS native app banner', (
      tester,
    ) async {
      var dismissed = false;
      await tester.pumpWidget(
        _buildHomeContent(
          recentSessions: [_session(id: 's1')],
          showMacOSNativeAppBanner: true,
          onDismissMacOSNativeAppBanner: () => dismissed = true,
          cubit: cubit,
          draftService: draftService,
          revenueCatService: revenueCatService,
          supportBannerService: supportBannerService,
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('macos_native_app_banner_dismiss_button')),
      );

      expect(dismissed, isTrue);
    });
  });
}
