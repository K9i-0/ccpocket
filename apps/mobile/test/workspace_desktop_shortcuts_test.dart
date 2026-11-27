import 'dart:async';

import 'package:ccpocket/features/git/state/git_status_cubit.dart';
import 'package:ccpocket/features/git/state/git_view_cache_service.dart';
import 'package:ccpocket/features/github/state/github_view_cache_service.dart';
import 'package:ccpocket/features/session_list/state/session_list_cubit.dart';
import 'package:ccpocket/features/session_list/workspace_shell_screen.dart';
import 'package:ccpocket/features/settings/models/settings_catalog.dart';
import 'package:ccpocket/features/settings/settings_screen.dart';
import 'package:ccpocket/features/settings/state/settings_cubit.dart';
import 'package:ccpocket/features/settings/widgets/keyboard_shortcuts_dialog.dart';
import 'package:ccpocket/features/workspace/state/workspace_navigation_cubit.dart';
import 'package:ccpocket/features/workspace/state/workspace_navigation_state.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/providers/bridge_cubits.dart';
import 'package:ccpocket/providers/machine_manager_cubit.dart';
import 'package:ccpocket/services/app_icon_service.dart';
import 'package:ccpocket/services/app_update_service.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/services/desktop_menu_service.dart';
import 'package:ccpocket/services/draft_service.dart';
import 'package:ccpocket/services/in_app_review_service.dart';
import 'package:ccpocket/services/machine_manager_service.dart';
import 'package:ccpocket/services/revenuecat_service.dart';
import 'package:ccpocket/services/support_banner_service.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestBridgeService extends BridgeService {
  final _connectionController =
      StreamController<BridgeConnectionState>.broadcast();
  final _messageController = StreamController<ServerMessage>.broadcast();
  final _activeSessionsController =
      StreamController<List<SessionInfo>>.broadcast();
  final _stoppedSessionsController = StreamController<String>.broadcast();
  final _recentSessionsController =
      StreamController<List<RecentSession>>.broadcast();
  final _galleryController = StreamController<List<GalleryImage>>.broadcast();
  final _projectHistoryController = StreamController<List<String>>.broadcast();
  final _fileListController = StreamController<List<String>>.broadcast();

  BridgeConnectionState _state;
  List<SessionInfo> _sessions = const [];
  final List<String> interruptedSessionIds = [];
  final List<String> historyRequestedSessionIds = [];
  int sessionListRequests = 0;
  bool disconnectCalled = false;

  _TestBridgeService({
    BridgeConnectionState initialState = BridgeConnectionState.connected,
  }) : _state = initialState;

  @override
  final String? lastUrl = 'ws://127.0.0.1:8765';

  @override
  Stream<BridgeConnectionState> get connectionStatus =>
      _connectionController.stream;

  @override
  Stream<ServerMessage> get messages => _messageController.stream;

  @override
  Stream<ServerMessage> messagesForSession(String sessionId) => messages;

  @override
  Stream<List<SessionInfo>> get sessionList => _activeSessionsController.stream;

  @override
  Stream<String> get stoppedSessions => _stoppedSessionsController.stream;

  @override
  Stream<List<RecentSession>> get recentSessionsStream =>
      _recentSessionsController.stream;

  @override
  Stream<List<GalleryImage>> get galleryStream => _galleryController.stream;

  @override
  Stream<List<String>> get projectHistoryStream =>
      _projectHistoryController.stream;

  @override
  Stream<List<String>> get fileList => _fileListController.stream;

  @override
  bool get isConnected => _state == BridgeConnectionState.connected;

  @override
  List<SessionInfo> get sessions => _sessions;

  @override
  String? get httpBaseUrl => 'http://127.0.0.1:8765';

  @override
  bool get recentSessionsHasMore => false;

  @override
  String? get currentProjectFilter => null;

  void emitConnection(BridgeConnectionState next) {
    _state = next;
    _connectionController.add(next);
  }

  void emitSessions(List<SessionInfo> next) {
    _sessions = next;
    _activeSessionsController.add(next);
  }

  @override
  void requestSessionList() {
    sessionListRequests++;
  }

  @override
  void requestProjectHistory() {}

  @override
  void requestRecentSessions({int? limit, int? offset, String? projectPath}) {}

  @override
  void switchFilter({
    String? projectPath,
    String? provider,
    bool? namedOnly,
    String? searchQuery,
    int pageSize = 20,
    RecentSessionsExtraFilters extraFilters = RecentSessionsExtraFilters.none,
  }) {}

  @override
  void requestGallery({String? projectPath, String? sessionId}) {
    _galleryController.add(const []);
  }

  @override
  void requestSessionHistory(String sessionId) {
    historyRequestedSessionIds.add(sessionId);
  }

  @override
  void requestFileList(String projectPath) {}

  @override
  void requestUsage({bool refreshAntigravity = false}) {}

  @override
  void interrupt(String sessionId, {bool retract = false}) {
    interruptedSessionIds.add(sessionId);
  }

  @override
  void send(ClientMessage message) {}

  @override
  void disconnect() {
    disconnectCalled = true;
    emitConnection(BridgeConnectionState.disconnected);
  }

  @override
  void dispose() {
    _connectionController.close();
    _messageController.close();
    _activeSessionsController.close();
    _stoppedSessionsController.close();
    _recentSessionsController.close();
    _galleryController.close();
    _projectHistoryController.close();
    _fileListController.close();
  }
}

class _FakeRevenueCatService extends RevenueCatService {
  _FakeRevenueCatService()
    : super(publicApiKey: '', platform: TargetPlatform.macOS) {
    supporterState.value = const SupporterState.inactive();
    catalogState.value = const SupportCatalogState.unavailable();
  }
}

class _RecordedDesktopMenuCalls {
  final List<Map<String, dynamic>> menuUpdates = [];
  final List<String> windowTitles = [];
  final List<String> dockBadges = [];
  int closeWindowCount = 0;
}

class _WorkspaceTestHarness {
  _WorkspaceTestHarness({
    required this.bridge,
    required this.settingsCubit,
    required this.menuService,
    required this.menuCalls,
    required this.channel,
    required this.shellKey,
  });

  final _TestBridgeService bridge;
  final SettingsCubit settingsCubit;
  final DesktopMenuService menuService;
  final _RecordedDesktopMenuCalls menuCalls;
  final MethodChannel channel;
  final GlobalKey<WorkspaceShellScreenState> shellKey;

  Future<void> triggerNativeMenuAction(
    WidgetTester tester,
    DesktopMenuAction action,
  ) async {
    final codec = const StandardMethodCodec();
    final encoded = codec.encodeMethodCall(
      MethodCall('onMenuAction', {'action': action.wireName}),
    );
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      channel.name,
      encoded,
      (_) {},
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<_WorkspaceTestHarness> _pumpWorkspace(
  WidgetTester tester, {
  TargetPlatform platform = TargetPlatform.macOS,
  Size surfaceSize = const Size(1280, 800),
  BridgeConnectionState initialConnection = BridgeConnectionState.connected,
  List<SessionInfo> initialSessions = const [],
  WorkspaceSessionSelection? initialSession,
  Map<String, Object> initialPrefs = const {},
  Future<AppUpdateInfo?> Function()? checkForUpdatesOverride,
}) async {
  debugDefaultTargetPlatformOverride = platform;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);

  SharedPreferences.setMockInitialValues(initialPrefs);
  FlutterSecureStorage.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final bridge = _TestBridgeService(initialState: initialConnection);
  bridge.emitSessions(initialSessions);
  addTearDown(bridge.dispose);

  final machineManagerService = MachineManagerService(
    prefs,
    const FlutterSecureStorage(),
  );
  addTearDown(machineManagerService.dispose);
  final machineManagerCubit = MachineManagerCubit(
    machineManagerService,
    null,
    refreshLatestBridgeVersionOnInit: false,
  );
  addTearDown(machineManagerCubit.close);

  final settingsCubit = SettingsCubit(
    prefs,
    bridgeService: bridge,
    machineManager: machineManagerService,
    appIconService: AppIconService(),
  );
  addTearDown(settingsCubit.close);

  final draftService = DraftService(prefs);
  final reviewService = InAppReviewService(prefs: prefs);
  final supportBannerService = SupportBannerService(
    prefs: prefs,
    reviewService: reviewService,
  );
  final revenueCatService = _FakeRevenueCatService();
  final gitStatusCubit = GitStatusCubit(bridge: bridge);
  final gitViewCacheService = GitViewCacheService(
    bridge: bridge,
    gitStatusCubit: gitStatusCubit,
  );
  final githubViewCacheService = GitHubViewCacheService(bridge: bridge);
  final sessionListCubit = SessionListCubit(bridge: bridge);

  addTearDown(() async {
    await gitViewCacheService.dispose();
    await githubViewCacheService.dispose();
    await gitStatusCubit.close();
    await sessionListCubit.close();
    await revenueCatService.dispose();
    reviewService.dispose();
  });

  final menuCalls = _RecordedDesktopMenuCalls();
  final channelName =
      'ccpocket/app_menu_test_${DateTime.now().microsecondsSinceEpoch}';
  final channel = MethodChannel(channelName);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
    call,
  ) async {
    switch (call.method) {
      case 'updateMenuState':
        menuCalls.menuUpdates.add(
          Map<String, dynamic>.from(call.arguments as Map),
        );
      case 'setWindowTitle':
        menuCalls.windowTitles.add(
          (call.arguments as Map)['title'] as String? ?? '',
        );
      case 'setDockBadge':
        menuCalls.dockBadges.add(
          (call.arguments as Map)['label'] as String? ?? '',
        );
      case 'performCloseWindow':
        menuCalls.closeWindowCount++;
    }
    return null;
  });
  addTearDown(() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    );
  });

  final menuService = DesktopMenuService(
    channel: channel,
    isSupported: () => platform == TargetPlatform.macOS,
  );
  addTearDown(menuService.dispose);

  final shellKey = GlobalKey<WorkspaceShellScreenState>();

  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<BridgeService>.value(value: bridge),
        RepositoryProvider<DraftService>.value(value: draftService),
        RepositoryProvider<InAppReviewService>.value(value: reviewService),
        RepositoryProvider<RevenueCatService>.value(value: revenueCatService),
        RepositoryProvider<GitViewCacheService>.value(
          value: gitViewCacheService,
        ),
        RepositoryProvider<MachineManagerService>.value(
          value: machineManagerService,
        ),
        RepositoryProvider<GitHubViewCacheService>.value(
          value: githubViewCacheService,
        ),
        RepositoryProvider<SupportBannerService>.value(
          value: supportBannerService,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<MachineManagerCubit>.value(value: machineManagerCubit),
          BlocProvider(
            create: (_) =>
                ConnectionCubit(initialConnection, bridge.connectionStatus),
          ),
          BlocProvider(
            create: (_) =>
                ActiveSessionsCubit(initialSessions, bridge.sessionList),
          ),
          BlocProvider(
            create: (_) =>
                RecentSessionsCubit(const [], bridge.recentSessionsStream),
          ),
          BlocProvider(
            create: (_) => GalleryCubit(const [], bridge.galleryStream),
          ),
          BlocProvider(create: (_) => FileListCubit(const [], bridge.fileList)),
          BlocProvider(
            create: (_) =>
                ProjectHistoryCubit(const [], bridge.projectHistoryStream),
          ),
          BlocProvider(
            create: (_) => WorkspaceProjectsCubit(
              bridge.projectsState,
              bridge.projectsStream,
            ),
          ),
          BlocProvider<GitStatusCubit>.value(value: gitStatusCubit),
          BlocProvider<SessionListCubit>.value(value: sessionListCubit),
          BlocProvider<SettingsCubit>.value(value: settingsCubit),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme.copyWith(platform: platform),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: WorkspaceShellScreen(
            key: shellKey,
            initialSession: initialSession,
            desktopMenuService: menuService,
            checkForUpdatesOverride: checkForUpdatesOverride,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));

  return _WorkspaceTestHarness(
    bridge: bridge,
    settingsCubit: settingsCubit,
    menuService: menuService,
    menuCalls: menuCalls,
    channel: channel,
    shellKey: shellKey,
  );
}

SessionInfo _makeSession({
  required String id,
  String? name,
  String projectPath = '/Users/dev/project-a',
  String status = 'running',
}) {
  return SessionInfo(
    id: id,
    provider: 'claude',
    projectPath: projectPath,
    name: name,
    status: status,
    createdAt: '2026-01-01T00:00:00Z',
    lastActivityAt: '2026-01-01T00:01:00Z',
  );
}

void main() {
  group('WorkspaceNavigationCubit desktop state', () {
    test('toggles sidebar collapsed and preserves it across reset', () {
      final cubit = WorkspaceNavigationCubit();
      addTearDown(cubit.close);

      expect(cubit.state.isSidebarCollapsed, isFalse);
      cubit.toggleSidebarCollapsed();
      expect(cubit.state.isSidebarCollapsed, isTrue);

      cubit.selectSession(const WorkspaceSessionSelection(sessionId: 's1'));
      cubit.reset();
      expect(cubit.state.selection, isNull);
      expect(cubit.state.isSidebarCollapsed, isTrue);
    });

    test(
      'tracks settingsInitialCategory on overlay open and clears on close',
      () {
        final cubit = WorkspaceNavigationCubit();
        addTearDown(cubit.close);

        cubit.openOverlay(
          WorkspaceCenterOverlay.settings,
          settingsInitialCategory: SettingsCategory.localBridge,
        );
        expect(cubit.state.overlay, WorkspaceCenterOverlay.settings);
        expect(
          cubit.state.settingsInitialCategory,
          SettingsCategory.localBridge,
        );

        cubit.closeOverlay();
        expect(cubit.state.overlay, WorkspaceCenterOverlay.none);
        expect(cubit.state.settingsInitialCategory, isNull);
      },
    );
  });

  group('DesktopMenuService wiring & dynamic menu state (macOS)', () {
    testWidgets(
      'openSettings always opens without toggling closed and works disconnected',
      (tester) async {
        final harness = await _pumpWorkspace(
          tester,
          initialConnection: BridgeConnectionState.disconnected,
        );

        expect(find.byType(SettingsScreen), findsNothing);

        await harness.triggerNativeMenuAction(
          tester,
          DesktopMenuAction.openSettings,
        );
        expect(find.byType(SettingsScreen), findsOneWidget);

        // Second Cmd+, must keep Settings open rather than toggling it closed.
        await harness.triggerNativeMenuAction(
          tester,
          DesktopMenuAction.openSettings,
        );
        expect(find.byType(SettingsScreen), findsOneWidget);

        // Native menu Close title becomes "Close Settings".
        final lastItems = Map<String, dynamic>.from(
          harness.menuCalls.menuUpdates.last['items'] as Map,
        );
        expect((lastItems['closeActive'] as Map)['title'], 'Close Settings');
        // Disconnected state disables New Session & Disconnect.
        expect((lastItems['newSession'] as Map)['enabled'], isFalse);
        expect((lastItems['disconnect'] as Map)['enabled'], isFalse);
      },
    );

    testWidgets(
      'openLocalBridge opens Settings directly to SettingsCategory.localBridge',
      (tester) async {
        final harness = await _pumpWorkspace(tester);

        await harness.triggerNativeMenuAction(
          tester,
          DesktopMenuAction.openLocalBridge,
        );

        final settingsWidget = tester.widget<SettingsScreen>(
          find.byType(SettingsScreen),
        );
        expect(settingsWidget.initialCategory, SettingsCategory.localBridge);
      },
    );

    testWidgets(
      'closeActive follows smart close order down to macOS closeWindow',
      (tester) async {
        final session = _makeSession(id: 'sess-1', name: 'Refactor UI');
        final harness = await _pumpWorkspace(
          tester,
          initialSessions: [session],
          initialSession: WorkspaceSessionSelection(
            sessionId: session.id,
            projectPath: session.projectPath,
            provider: Provider.claude,
          ),
        );

        // Open tool pane, Settings overlay, and Shortcuts dialog on top.
        await harness.triggerNativeMenuAction(
          tester,
          DesktopMenuAction.toggleGitPane,
        );
        expect(
          harness.shellKey.currentState!.isToolPaneOpen(
            'git:${session.projectPath}:${session.id}:',
          ),
          isTrue,
        );

        await harness.triggerNativeMenuAction(
          tester,
          DesktopMenuAction.openSettings,
        );
        expect(find.byType(SettingsScreen), findsOneWidget);

        await harness.triggerNativeMenuAction(
          tester,
          DesktopMenuAction.showShortcuts,
        );
        expect(find.byType(KeyboardShortcutsDialog), findsOneWidget);

        // 1. Pop top modal dialog.
        await harness.triggerNativeMenuAction(
          tester,
          DesktopMenuAction.closeActive,
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(KeyboardShortcutsDialog), findsNothing);
        expect(find.byType(SettingsScreen), findsOneWidget);

        // 2. Close Settings overlay.
        await harness.triggerNativeMenuAction(
          tester,
          DesktopMenuAction.closeActive,
        );
        expect(find.byType(SettingsScreen), findsNothing);
        expect(harness.shellKey.currentState!.selectedSession, isNotNull);

        // 3. Close right tool pane.
        await harness.triggerNativeMenuAction(
          tester,
          DesktopMenuAction.closeActive,
        );
        expect(
          harness.shellKey.currentState!.isToolPaneOpen(
            'git:${session.projectPath}:${session.id}:',
          ),
          isFalse,
        );
        expect(harness.shellKey.currentState!.selectedSession, isNotNull);

        // 4. Close active session.
        await harness.triggerNativeMenuAction(
          tester,
          DesktopMenuAction.closeActive,
        );
        expect(harness.shellKey.currentState!.selectedSession, isNull);
        expect(harness.menuCalls.closeWindowCount, 0);

        // 5. Close native window on macOS.
        await harness.triggerNativeMenuAction(
          tester,
          DesktopMenuAction.closeActive,
        );
        expect(harness.menuCalls.closeWindowCount, 1);
      },
    );

    testWidgets(
      'toggleSidebar collapses/expands sidebar, persists state, and shows center expand button',
      (tester) async {
        final harness = await _pumpWorkspace(tester);

        expect(harness.shellKey.currentState!.isSidebarCollapsed, isFalse);
        expect(
          find.byKey(const ValueKey('sidebar_toggle_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('center_sidebar_toggle_button')),
          findsNothing,
        );

        await harness.triggerNativeMenuAction(
          tester,
          DesktopMenuAction.toggleSidebar,
        );

        expect(harness.shellKey.currentState!.isSidebarCollapsed, isTrue);
        expect(harness.shellKey.currentState!.isLeftPaneVisible, isFalse);
        expect(
          find.byKey(const ValueKey('center_sidebar_toggle_button')),
          findsOneWidget,
        );

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('workspace_sidebar_collapsed'), isTrue);

        // Native menu reflects unchecked sidebar state when collapsed.
        final lastItems = Map<String, dynamic>.from(
          harness.menuCalls.menuUpdates.last['items'] as Map,
        );
        expect((lastItems['toggleSidebar'] as Map)['checked'], isFalse);

        // Tap center expand button to restore sidebar.
        await tester.tap(
          find.byKey(const ValueKey('center_sidebar_toggle_button')),
        );
        await tester.pump();
        expect(harness.shellKey.currentState!.isSidebarCollapsed, isFalse);
        expect(prefs.getBool('workspace_sidebar_collapsed'), isFalse);
      },
    );

    testWidgets(
      'zoom, stopGeneration, reload, disconnect, and checkForUpdates actions work',
      (tester) async {
        final session = _makeSession(
          id: 'sess-run',
          name: 'Running Task',
          status: 'running',
        );
        var updateChecks = 0;
        final harness = await _pumpWorkspace(
          tester,
          initialSessions: [session],
          initialSession: WorkspaceSessionSelection(
            sessionId: session.id,
            projectPath: session.projectPath,
            provider: Provider.claude,
          ),
          checkForUpdatesOverride: () async {
            updateChecks++;
            return null;
          },
        );

        final initialScale = harness.settingsCubit.state.textScale;
        await harness.triggerNativeMenuAction(tester, DesktopMenuAction.zoomIn);
        expect(
          harness.settingsCubit.state.textScale,
          greaterThan(initialScale),
        );

        await harness.triggerNativeMenuAction(
          tester,
          DesktopMenuAction.actualSize,
        );
        expect(harness.settingsCubit.state.textScale, 1.0);

        await harness.triggerNativeMenuAction(
          tester,
          DesktopMenuAction.zoomOut,
        );
        expect(harness.settingsCubit.state.textScale, lessThan(1.0));

        await harness.triggerNativeMenuAction(
          tester,
          DesktopMenuAction.stopGeneration,
        );
        expect(harness.bridge.interruptedSessionIds, contains('sess-run'));

        final beforeReload = harness.bridge.sessionListRequests;
        await harness.triggerNativeMenuAction(tester, DesktopMenuAction.reload);
        expect(harness.bridge.sessionListRequests, greaterThan(beforeReload));
        expect(harness.bridge.historyRequestedSessionIds, contains('sess-run'));

        await harness.triggerNativeMenuAction(
          tester,
          DesktopMenuAction.checkForUpdates,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(updateChecks, 1);
        expect(
          find.byKey(const ValueKey('check_for_updates_dialog')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('app_toast')), findsNothing);
        await tester.tap(
          find.byKey(const ValueKey('check_for_updates_ok_button')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        await harness.triggerNativeMenuAction(
          tester,
          DesktopMenuAction.disconnect,
        );
        expect(harness.bridge.disconnectCalled, isTrue);
      },
    );

    testWidgets('window title and Dock badge sync with session and approvals', (
      tester,
    ) async {
      final waitingSession = _makeSession(
        id: 'sess-wait',
        name: 'Deploy Release',
        status: 'waiting_approval',
      );
      final harness = await _pumpWorkspace(
        tester,
        initialSessions: [waitingSession],
        initialSession: WorkspaceSessionSelection(
          sessionId: waitingSession.id,
          projectPath: waitingSession.projectPath,
          provider: Provider.claude,
        ),
      );

      expect(harness.menuCalls.windowTitles.last, 'Deploy Release — CC Pocket');
      expect(harness.menuCalls.dockBadges.last, '1');

      // Clearing pending approval clears Dock badge.
      harness.bridge.emitSessions([
        _makeSession(id: 'sess-wait', name: 'Deploy Release', status: 'idle'),
      ]);
      await tester.pump();
      await tester.pump();
      expect(harness.menuCalls.dockBadges.last, '');

      // Closing session falls back to connected bridge host:port.
      await harness.triggerNativeMenuAction(
        tester,
        DesktopMenuAction.closeActive,
      );
      await tester.pump();
      expect(harness.menuCalls.windowTitles.last, '127.0.0.1:8765 — CC Pocket');
    });
  });

  group('Keyboard shortcuts (macOS non-double-firing & Linux/Windows)', () {
    testWidgets(
      'macOS handles Cmd+1..9 via Flutter without double-binding NSMenu shortcuts',
      (tester) async {
        final s1 = _makeSession(id: 's1', name: 'First Session');
        final s2 = _makeSession(id: 's2', name: 'Second Session');
        final harness = await _pumpWorkspace(
          tester,
          platform: TargetPlatform.macOS,
          initialSessions: [s1, s2],
        );

        // Press Cmd+2 -> switches to second visible session.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.digit2);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.digit2);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
        await tester.pump();
        expect(harness.shellKey.currentState!.selectedSession?.sessionId, 's2');

        // Raw Cmd+, key event on macOS must NOT open Settings via Flutter
        // CallbackShortcuts (native NSMenu owns Cmd+, to avoid double-firing).
        await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.comma);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.comma);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
        await tester.pump();
        expect(find.byType(SettingsScreen), findsNothing);
      },
    );

    testWidgets(
      'Linux desktop handles Ctrl+, Ctrl+\\ Ctrl+1..9 Ctrl+W Ctrl+= via Flutter shortcuts',
      (tester) async {
        final s1 = _makeSession(id: 's1', name: 'Alpha');
        final harness = await _pumpWorkspace(
          tester,
          platform: TargetPlatform.linux,
          initialSessions: [s1],
        );

        // Ctrl+1 selects first session.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.digit1);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.digit1);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        expect(harness.shellKey.currentState!.selectedSession?.sessionId, 's1');

        // Ctrl+, opens Settings.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.comma);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.comma);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        expect(find.byType(SettingsScreen), findsOneWidget);

        // Ctrl+W closes Settings.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        expect(find.byType(SettingsScreen), findsNothing);

        // Ctrl+\ toggles sidebar.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.backslash);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.backslash);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        expect(harness.shellKey.currentState!.isSidebarCollapsed, isTrue);

        // Ctrl+= zooms in.
        final beforeZoom = harness.settingsCubit.state.textScale;
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.equal);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.equal);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        expect(harness.settingsCubit.state.textScale, greaterThan(beforeZoom));
      },
    );
  });

  group('Resizable sidebar & persisted pane widths', () {
    testWidgets('drags left resize handle and persists width in prefs', (
      tester,
    ) async {
      await _pumpWorkspace(tester);

      final listFinder = find.byKey(const ValueKey('workspace_list_slot'));
      final initialWidth = tester.getSize(listFinder).width;

      final handleFinder = find.byKey(
        const ValueKey('workspace_left_resize_handle'),
      );
      expect(handleFinder, findsOneWidget);

      await tester.drag(handleFinder, const Offset(60, 0));
      await tester.pump(const Duration(milliseconds: 200));

      final resizedWidth = tester.getSize(listFinder).width;
      expect(resizedWidth, greaterThan(initialWidth));
      expect(resizedWidth, inInclusiveRange(220.0, 480.0));

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getDouble('workspace_left_pane_width'),
        closeTo(resizedWidth, 1),
      );
    });

    testWidgets('restores persisted sidebar width and collapsed state', (
      tester,
    ) async {
      final harness = await _pumpWorkspace(
        tester,
        initialPrefs: const {
          'workspace_left_pane_width': 410.0,
          'workspace_sidebar_collapsed': true,
        },
      );
      await tester.pump();

      expect(harness.shellKey.currentState!.isSidebarCollapsed, isTrue);

      harness.shellKey.currentState!.setSidebarCollapsed(false);
      await tester.pump();

      final listWidth = tester
          .getSize(find.byKey(const ValueKey('workspace_list_slot')))
          .width;
      expect(listWidth, closeTo(410.0, 1));
    });
  });

  group('Desktop landing polish', () {
    testWidgets('shows quick actions and shortcut hints on macOS desktop', (
      tester,
    ) async {
      await _pumpWorkspace(tester, platform: TargetPlatform.macOS);

      expect(
        find.byKey(const ValueKey('workspace_landing_new_session_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('workspace_landing_settings_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('workspace_landing_local_bridge_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('workspace_landing_shortcut_hints')),
        findsOneWidget,
      );
    });

    testWidgets('hides desktop landing shortcut hints on iOS', (tester) async {
      await _pumpWorkspace(
        tester,
        platform: TargetPlatform.iOS,
        surfaceSize: const Size(1100, 800),
      );

      expect(
        find.byKey(const ValueKey('workspace_landing_shortcut_hints')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('workspace_landing_local_bridge_button')),
        findsNothing,
      );
    });
  });
}
