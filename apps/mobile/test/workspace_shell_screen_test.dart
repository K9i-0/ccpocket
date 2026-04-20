import 'dart:async';

import 'package:ccpocket/features/session_list/state/session_list_cubit.dart';
import 'package:ccpocket/features/session_list/workspace_shell_screen.dart';
import 'package:ccpocket/features/settings/state/settings_cubit.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/providers/bridge_cubits.dart';
import 'package:ccpocket/providers/server_discovery_cubit.dart';
import 'package:ccpocket/services/app_icon_service.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/services/draft_service.dart';
import 'package:ccpocket/services/in_app_review_service.dart';
import 'package:ccpocket/services/notification_service.dart';
import 'package:ccpocket/services/revenuecat_service.dart';
import 'package:ccpocket/services/support_banner_service.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/session_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart' hide Provider;
import 'package:shared_preferences/shared_preferences.dart';

class _MockBridgeService extends BridgeService {
  final _connectionController =
      StreamController<BridgeConnectionState>.broadcast();
  final _messageController = StreamController<ServerMessage>.broadcast();
  final _activeSessionsController =
      StreamController<List<SessionInfo>>.broadcast();
  final _recentSessionsController =
      StreamController<List<RecentSession>>.broadcast();
  final _galleryController = StreamController<List<GalleryImage>>.broadcast();
  final _projectHistoryController = StreamController<List<String>>.broadcast();
  final _fileListController = StreamController<List<String>>.broadcast();

  BridgeConnectionState _state;
  List<GalleryImage> _images = const [];

  _MockBridgeService({
    BridgeConnectionState initialState = BridgeConnectionState.connected,
  }) : _state = initialState;

  @override
  Stream<BridgeConnectionState> get connectionStatus =>
      _connectionController.stream;

  @override
  Stream<ServerMessage> get messages => _messageController.stream;

  @override
  Stream<List<SessionInfo>> get sessionList => _activeSessionsController.stream;

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
  String? get httpBaseUrl => 'http://localhost:8765';

  @override
  bool get recentSessionsHasMore => false;

  @override
  String? get currentProjectFilter => null;

  @override
  List<GalleryImage> get galleryImages => _images;

  void emitConnection(BridgeConnectionState state) {
    _state = state;
    _connectionController.add(state);
  }

  void emitSessions(List<SessionInfo> sessions) {
    _activeSessionsController.add(sessions);
  }

  void setGalleryImages(List<GalleryImage> images) {
    _images = images;
    _galleryController.add(images);
  }

  @override
  void requestSessionList() {}

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
  }) {}

  @override
  void loadMoreRecentSessions({int pageSize = 20}) {}

  @override
  void requestGallery({String? project, String? sessionId}) {
    _galleryController.add(_images);
  }

  @override
  void stopSession(String sessionId) {}

  @override
  void requestSessionHistory(String sessionId) {}

  @override
  void requestFileList(String projectPath) {}

  @override
  void interrupt(String sessionId) {}

  @override
  void send(ClientMessage message) {}

  @override
  void dispose() {
    _connectionController.close();
    _messageController.close();
    _activeSessionsController.close();
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

Widget _buildWorkspaceApp({
  required _MockBridgeService bridge,
  required SettingsCubit settingsCubit,
  required DraftService draftService,
  required RevenueCatService revenueCatService,
  required SupportBannerService supportBannerService,
  List<RecentSession>? debugRecentSessions,
  GlobalKey<WorkspaceShellScreenState>? shellKey,
  TargetPlatform platform = TargetPlatform.macOS,
}) {
  final sessionListCubit = SessionListCubit(bridge: bridge);
  final connectionCubit = ConnectionCubit(
    bridge.isConnected
        ? BridgeConnectionState.connected
        : BridgeConnectionState.disconnected,
    bridge.connectionStatus,
  );
  final activeSessionsCubit = ActiveSessionsCubit(const [], bridge.sessionList);
  final galleryCubit = GalleryCubit(const [], bridge.galleryStream);
  final fileListCubit = FileListCubit(const [], bridge.fileList);
  final projectHistoryCubit = ProjectHistoryCubit(
    const [],
    bridge.projectHistoryStream,
  );

  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<BridgeService>.value(value: bridge),
      RepositoryProvider<DraftService>.value(value: draftService),
      RepositoryProvider<RevenueCatService>.value(value: revenueCatService),
      ChangeNotifierProvider<SupportBannerService>.value(
        value: supportBannerService,
      ),
    ],
    child: MultiBlocProvider(
      providers: [
        BlocProvider<ConnectionCubit>.value(value: connectionCubit),
        BlocProvider<ActiveSessionsCubit>.value(value: activeSessionsCubit),
        BlocProvider<GalleryCubit>.value(value: galleryCubit),
        BlocProvider<FileListCubit>.value(value: fileListCubit),
        BlocProvider<ProjectHistoryCubit>.value(value: projectHistoryCubit),
        BlocProvider<SessionListCubit>.value(value: sessionListCubit),
        BlocProvider<SettingsCubit>.value(value: settingsCubit),
        BlocProvider<ServerDiscoveryCubit>(
          create: (_) => ServerDiscoveryCubit(),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        theme: AppTheme.darkTheme.copyWith(platform: platform),
        home: Scaffold(
          body: SizedBox(
            width: 1400,
            height: 900,
            child: WorkspaceShellScreen(
              key: shellKey,
              debugRecentSessions: debugRecentSessions,
            ),
          ),
        ),
      ),
    ),
  );
}

RecentSession _recentSession(String id) => RecentSession(
  sessionId: id,
  firstPrompt: 'Prompt $id',
  created: '2025-01-01T00:00:00Z',
  modified: '2025-01-01T00:00:00Z',
  gitBranch: 'main',
  projectPath: '/Users/demo/project-$id',
  isSidechain: false,
);

SessionInfo _runningSession({
  required String id,
  Provider provider = Provider.claude,
}) => SessionInfo(
  id: id,
  provider: provider.value,
  projectPath: '/Users/demo/project-$id',
  status: 'idle',
  createdAt: '2025-01-01T00:00:00Z',
  lastActivityAt: '2025-01-01T00:00:00Z',
  gitBranch: 'main',
  lastMessage: 'Waiting',
);

Future<SettingsCubit> _createSettingsCubit(_MockBridgeService bridge) async {
  final prefs = await SharedPreferences.getInstance();
  final revenueCatService = _FakeRevenueCatService();
  return SettingsCubit(
    prefs,
    bridgeService: bridge,
    revenueCatService: revenueCatService,
    appIconService: AppIconService(platform: TargetPlatform.macOS),
  );
}

Future<SupportBannerService> _createSupportBannerService() async {
  final prefs = await SharedPreferences.getInstance();
  return SupportBannerService(
    prefs: prefs,
    reviewService: InAppReviewService(prefs: prefs),
  );
}

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NotificationService.instance.clearActiveSession();
  });

  testWidgets('settings overlay back restores selected session root', (
    tester,
  ) async {
    final bridge = _MockBridgeService();
    final settingsCubit = await _createSettingsCubit(bridge);
    final draftService = DraftService(await SharedPreferences.getInstance());
    final revenueCatService = _FakeRevenueCatService();
    final supportBannerService = await _createSupportBannerService();
    final shellKey = GlobalKey<WorkspaceShellScreenState>();

    await tester.pumpWidget(
      _buildWorkspaceApp(
        bridge: bridge,
        settingsCubit: settingsCubit,
        draftService: draftService,
        revenueCatService: revenueCatService,
        supportBannerService: supportBannerService,
        debugRecentSessions: [_recentSession('one')],
        shellKey: shellKey,
      ),
    );
    await _pumpUi(tester);

    shellKey.currentState!.selectSession(
      const WorkspaceSessionSelection(
        sessionId: 'pending-1',
        projectPath: '/Users/demo/project-one',
        provider: Provider.codex,
        isPending: true,
      ),
    );
    await _pumpUi(tester);

    expect(find.text('Creating session...'), findsOneWidget);
    expect(find.byKey(const ValueKey('session_back_button')), findsNothing);

    shellKey.currentState!.openSettingsCenter();
    await _pumpUi(tester);
    expect(find.text('Settings'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('embedded_settings_back_button')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('embedded_settings_back_button')),
    );
    await _pumpUi(tester);
    expect(find.text('Creating session...'), findsOneWidget);
    expect(NotificationService.instance.activeSessionId, 'pending-1');
  });

  testWidgets('settings overlay back restores offline landing root', (
    tester,
  ) async {
    final bridge = _MockBridgeService();
    final settingsCubit = await _createSettingsCubit(bridge);
    final draftService = DraftService(await SharedPreferences.getInstance());
    final revenueCatService = _FakeRevenueCatService();
    final supportBannerService = await _createSupportBannerService();
    final shellKey = GlobalKey<WorkspaceShellScreenState>();

    await tester.pumpWidget(
      _buildWorkspaceApp(
        bridge: bridge,
        settingsCubit: settingsCubit,
        draftService: draftService,
        revenueCatService: revenueCatService,
        supportBannerService: supportBannerService,
        shellKey: shellKey,
      ),
    );
    await _pumpUi(tester);

    shellKey.currentState!.openSettingsCenter();
    await _pumpUi(tester);

    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('embedded_settings_back_button')),
    );
    await _pumpUi(tester);

    expect(
      find.text(
        'Select a session on the left, or open settings or gallery from the sidebar.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'opening gallery overlay replaces settings and back restores session root',
    (tester) async {
      final bridge = _MockBridgeService();
      bridge.setGalleryImages([
        const GalleryImage(
          id: 'img-1',
          url: '/api/gallery/img-1',
          mimeType: 'image/png',
          projectPath: '/Users/demo/project-one',
          projectName: 'project-one',
          addedAt: '2025-01-01T00:00:00Z',
          sizeBytes: 100,
        ),
      ]);
      final settingsCubit = await _createSettingsCubit(bridge);
      final draftService = DraftService(await SharedPreferences.getInstance());
      final revenueCatService = _FakeRevenueCatService();
      final supportBannerService = await _createSupportBannerService();
      final shellKey = GlobalKey<WorkspaceShellScreenState>();

      await tester.pumpWidget(
        _buildWorkspaceApp(
          bridge: bridge,
          settingsCubit: settingsCubit,
          draftService: draftService,
          revenueCatService: revenueCatService,
          supportBannerService: supportBannerService,
          debugRecentSessions: [_recentSession('one')],
          shellKey: shellKey,
        ),
      );
      await _pumpUi(tester);

      shellKey.currentState!.selectSession(
        const WorkspaceSessionSelection(
          sessionId: 'pending-1',
          projectPath: '/Users/demo/project-one',
          provider: Provider.codex,
          isPending: true,
        ),
      );
      await _pumpUi(tester);

      shellKey.currentState!.openSettingsCenter();
      await _pumpUi(tester);

      shellKey.currentState!.openGlobalGalleryCenter();
      await _pumpUi(tester);
      expect(
        find.byKey(const ValueKey('embedded_gallery_back_button')),
        findsOneWidget,
      );
      expect(find.textContaining('Gallery'), findsWidgets);

      await tester.tap(
        find.byKey(const ValueKey('embedded_gallery_back_button')),
      );
      await _pumpUi(tester);

      expect(find.text('Creating session...'), findsOneWidget);
      expect(NotificationService.instance.activeSessionId, 'pending-1');
    },
  );

  testWidgets(
    'opening gallery overlay replaces settings and back restores offline landing',
    (tester) async {
      final bridge = _MockBridgeService();
      bridge.setGalleryImages([
        const GalleryImage(
          id: 'img-1',
          url: '/api/gallery/img-1',
          mimeType: 'image/png',
          projectPath: '/Users/demo/project-one',
          projectName: 'project-one',
          addedAt: '2025-01-01T00:00:00Z',
          sizeBytes: 100,
        ),
      ]);
      final settingsCubit = await _createSettingsCubit(bridge);
      final draftService = DraftService(await SharedPreferences.getInstance());
      final revenueCatService = _FakeRevenueCatService();
      final supportBannerService = await _createSupportBannerService();
      final shellKey = GlobalKey<WorkspaceShellScreenState>();

      await tester.pumpWidget(
        _buildWorkspaceApp(
          bridge: bridge,
          settingsCubit: settingsCubit,
          draftService: draftService,
          revenueCatService: revenueCatService,
          supportBannerService: supportBannerService,
          shellKey: shellKey,
        ),
      );
      await _pumpUi(tester);

      shellKey.currentState!.openSettingsCenter();
      await _pumpUi(tester);

      shellKey.currentState!.openGlobalGalleryCenter();
      await _pumpUi(tester);

      expect(
        find.byKey(const ValueKey('embedded_gallery_back_button')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('embedded_gallery_back_button')),
      );
      await _pumpUi(tester);

      expect(
        find.text(
          'Select a session on the left, or open settings or gallery from the sidebar.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'selecting another session while overlay is open clears overlay',
    (tester) async {
      final bridge = _MockBridgeService();
      bridge.setGalleryImages([
        const GalleryImage(
          id: 'img-1',
          url: '/api/gallery/img-1',
          mimeType: 'image/png',
          projectPath: '/Users/demo/project-one',
          projectName: 'project-one',
          addedAt: '2025-01-01T00:00:00Z',
          sizeBytes: 100,
        ),
      ]);
      final settingsCubit = await _createSettingsCubit(bridge);
      final draftService = DraftService(await SharedPreferences.getInstance());
      final revenueCatService = _FakeRevenueCatService();
      final supportBannerService = await _createSupportBannerService();
      final shellKey = GlobalKey<WorkspaceShellScreenState>();

      await tester.pumpWidget(
        _buildWorkspaceApp(
          bridge: bridge,
          settingsCubit: settingsCubit,
          draftService: draftService,
          revenueCatService: revenueCatService,
          supportBannerService: supportBannerService,
          debugRecentSessions: [_recentSession('one')],
          shellKey: shellKey,
        ),
      );
      await _pumpUi(tester);

      shellKey.currentState!.selectSession(
        const WorkspaceSessionSelection(
          sessionId: 'pending-1',
          projectPath: '/Users/demo/project-one',
          provider: Provider.codex,
          isPending: true,
        ),
      );
      await _pumpUi(tester);

      shellKey.currentState!.openGlobalGalleryCenter();
      await _pumpUi(tester);

      shellKey.currentState!.selectSession(
        const WorkspaceSessionSelection(
          sessionId: 'pending-2',
          projectPath: '/Users/demo/project-two',
          provider: Provider.codex,
          isPending: true,
        ),
      );
      await _pumpUi(tester);

      expect(find.text('Creating session...'), findsOneWidget);
      expect(NotificationService.instance.activeSessionId, 'pending-2');
      expect(
        find.byKey(const ValueKey('embedded_gallery_back_button')),
        findsNothing,
      );
    },
  );

  testWidgets('shows guided disconnected landing', (tester) async {
    final bridge = _MockBridgeService(
      initialState: BridgeConnectionState.disconnected,
    );
    final settingsCubit = await _createSettingsCubit(bridge);
    final draftService = DraftService(await SharedPreferences.getInstance());
    final revenueCatService = _FakeRevenueCatService();
    final supportBannerService = await _createSupportBannerService();

    await tester.pumpWidget(
      _buildWorkspaceApp(
        bridge: bridge,
        settingsCubit: settingsCubit,
        draftService: draftService,
        revenueCatService: revenueCatService,
        supportBannerService: supportBannerService,
      ),
    );
    await _pumpUi(tester);

    expect(
      find.text(
        'Bridge is not connected. Use the left pane to connect, or open the setup guide to configure a machine.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('workspace_setup_guide_button')),
      findsOneWidget,
    );
  });

  testWidgets('disconnecting while overlay is open clears overlay to landing', (
    tester,
  ) async {
    final bridge = _MockBridgeService();
    final settingsCubit = await _createSettingsCubit(bridge);
    final draftService = DraftService(await SharedPreferences.getInstance());
    final revenueCatService = _FakeRevenueCatService();
    final supportBannerService = await _createSupportBannerService();
    final shellKey = GlobalKey<WorkspaceShellScreenState>();

    await tester.pumpWidget(
      _buildWorkspaceApp(
        bridge: bridge,
        settingsCubit: settingsCubit,
        draftService: draftService,
        revenueCatService: revenueCatService,
        supportBannerService: supportBannerService,
        shellKey: shellKey,
      ),
    );
    await _pumpUi(tester);

    shellKey.currentState!.openSettingsCenter();
    await _pumpUi(tester);
    expect(
      find.byKey(const ValueKey('embedded_settings_back_button')),
      findsOneWidget,
    );

    bridge.emitConnection(BridgeConnectionState.disconnected);
    await _pumpUi(tester);

    expect(
      find.byKey(const ValueKey('embedded_settings_back_button')),
      findsNothing,
    );
    expect(
      find.text(
        'Bridge is not connected. Use the left pane to connect, or open the setup guide to configure a machine.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('opens session gallery in right pane', (tester) async {
    final bridge = _MockBridgeService();
    bridge.setGalleryImages([
      const GalleryImage(
        id: 'img-1',
        url: '/api/gallery/img-1',
        mimeType: 'image/png',
        projectPath: '/Users/demo/project-one',
        projectName: 'project-one',
        sessionId: 'session-1',
        addedAt: '2025-01-01T00:00:00Z',
        sizeBytes: 100,
      ),
    ]);
    final settingsCubit = await _createSettingsCubit(bridge);
    final draftService = DraftService(await SharedPreferences.getInstance());
    final revenueCatService = _FakeRevenueCatService();
    final supportBannerService = await _createSupportBannerService();
    final shellKey = GlobalKey<WorkspaceShellScreenState>();

    await tester.pumpWidget(
      _buildWorkspaceApp(
        bridge: bridge,
        settingsCubit: settingsCubit,
        draftService: draftService,
        revenueCatService: revenueCatService,
        supportBannerService: supportBannerService,
        debugRecentSessions: [_recentSession('one')],
        shellKey: shellKey,
      ),
    );
    await _pumpUi(tester);

    shellKey.currentState!.openSessionGalleryPane(sessionId: 'session-1');
    await _pumpUi(tester);

    expect(
      find.byKey(const ValueKey('embedded_gallery_close_button')),
      findsOneWidget,
    );
  });

  testWidgets(
    'workspace session keeps show sessions button when left pane is collapsed',
    (tester) async {
      final bridge = _MockBridgeService();
      final settingsCubit = await _createSettingsCubit(bridge);
      final draftService = DraftService(await SharedPreferences.getInstance());
      final revenueCatService = _FakeRevenueCatService();
      final supportBannerService = await _createSupportBannerService();
      final shellKey = GlobalKey<WorkspaceShellScreenState>();

      await tester.pumpWidget(
        _buildWorkspaceApp(
          bridge: bridge,
          settingsCubit: settingsCubit,
          draftService: draftService,
          revenueCatService: revenueCatService,
          supportBannerService: supportBannerService,
          shellKey: shellKey,
        ),
      );
      await _pumpUi(tester);

      shellKey.currentState!.selectSession(
        const WorkspaceSessionSelection(
          sessionId: 'pending-1',
          projectPath: '/Users/demo/project-one',
          provider: Provider.codex,
          isPending: true,
        ),
      );
      await _pumpUi(tester);

      shellKey.currentState!.toggleLeftPaneVisibility();
      await _pumpUi(tester);

      expect(find.byKey(const ValueKey('session_back_button')), findsNothing);
      expect(
        find.byKey(const ValueKey('show_left_pane_button')),
        findsOneWidget,
      );
    },
  );

  testWidgets('macOS adaptive left pane hides pane title wordmark', (
    tester,
  ) async {
    final bridge = _MockBridgeService();
    final settingsCubit = await _createSettingsCubit(bridge);
    final draftService = DraftService(await SharedPreferences.getInstance());
    final revenueCatService = _FakeRevenueCatService();
    final supportBannerService = await _createSupportBannerService();

    await tester.pumpWidget(
      _buildWorkspaceApp(
        bridge: bridge,
        settingsCubit: settingsCubit,
        draftService: draftService,
        revenueCatService: revenueCatService,
        supportBannerService: supportBannerService,
        platform: TargetPlatform.macOS,
      ),
    );
    await _pumpUi(tester);

    expect(find.byKey(const ValueKey('session_list_pane_title')), findsNothing);
  });

  testWidgets('non-mac adaptive left pane keeps pane title wordmark', (
    tester,
  ) async {
    final bridge = _MockBridgeService();
    final settingsCubit = await _createSettingsCubit(bridge);
    final draftService = DraftService(await SharedPreferences.getInstance());
    final revenueCatService = _FakeRevenueCatService();
    final supportBannerService = await _createSupportBannerService();

    await tester.pumpWidget(
      _buildWorkspaceApp(
        bridge: bridge,
        settingsCubit: settingsCubit,
        draftService: draftService,
        revenueCatService: revenueCatService,
        supportBannerService: supportBannerService,
        platform: TargetPlatform.iOS,
      ),
    );
    await _pumpUi(tester);

    expect(
      find.byKey(const ValueKey('session_list_pane_title')),
      findsOneWidget,
    );
  });

  testWidgets(
    'selected running session remains highlighted while a popup menu is open',
    (tester) async {
      final bridge = _MockBridgeService();
      final settingsCubit = await _createSettingsCubit(bridge);
      final draftService = DraftService(await SharedPreferences.getInstance());
      final revenueCatService = _FakeRevenueCatService();
      final supportBannerService = await _createSupportBannerService();
      final shellKey = GlobalKey<WorkspaceShellScreenState>();
      final session = _runningSession(
        id: 'session-1',
        provider: Provider.codex,
      );

      await tester.pumpWidget(
        _buildWorkspaceApp(
          bridge: bridge,
          settingsCubit: settingsCubit,
          draftService: draftService,
          revenueCatService: revenueCatService,
          supportBannerService: supportBannerService,
          shellKey: shellKey,
        ),
      );
      await _pumpUi(tester);

      bridge.emitSessions([session]);
      await _pumpUi(tester);

      shellKey.currentState!.selectSession(
        const WorkspaceSessionSelection(
          sessionId: 'session-1',
          projectPath: '/Users/demo/project-session-1',
          provider: Provider.codex,
          isPending: true,
        ),
      );
      await _pumpUi(tester);

      expect(
        tester
            .widget<RunningSessionCard>(find.byType(RunningSessionCard))
            .isSelected,
        isTrue,
      );

      unawaited(
        showMenu<void>(
          context: tester.element(find.byType(WorkspaceShellScreen)),
          position: const RelativeRect.fromLTRB(120, 120, 0, 0),
          items: const [PopupMenuItem<void>(child: Text('Menu item'))],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        tester
            .widget<RunningSessionCard>(find.byType(RunningSessionCard))
            .isSelected,
        isTrue,
      );
    },
  );

  testWidgets(
    'selected running session remains highlighted while a modal sheet is open',
    (tester) async {
      final bridge = _MockBridgeService();
      final settingsCubit = await _createSettingsCubit(bridge);
      final draftService = DraftService(await SharedPreferences.getInstance());
      final revenueCatService = _FakeRevenueCatService();
      final supportBannerService = await _createSupportBannerService();
      final shellKey = GlobalKey<WorkspaceShellScreenState>();
      final session = _runningSession(
        id: 'session-1',
        provider: Provider.codex,
      );

      await tester.pumpWidget(
        _buildWorkspaceApp(
          bridge: bridge,
          settingsCubit: settingsCubit,
          draftService: draftService,
          revenueCatService: revenueCatService,
          supportBannerService: supportBannerService,
          shellKey: shellKey,
        ),
      );
      await _pumpUi(tester);

      bridge.emitSessions([session]);
      await _pumpUi(tester);

      shellKey.currentState!.selectSession(
        const WorkspaceSessionSelection(
          sessionId: 'session-1',
          projectPath: '/Users/demo/project-session-1',
          provider: Provider.codex,
          isPending: true,
        ),
      );
      await _pumpUi(tester);

      unawaited(
        showModalBottomSheet<void>(
          context: tester.element(find.byType(WorkspaceShellScreen)),
          builder: (_) => const SizedBox(height: 120),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        tester
            .widget<RunningSessionCard>(find.byType(RunningSessionCard))
            .isSelected,
        isTrue,
      );
    },
  );

  testWidgets('disconnected connect form opens setup guide in center pane', (
    tester,
  ) async {
    final bridge = _MockBridgeService(
      initialState: BridgeConnectionState.disconnected,
    );
    final settingsCubit = await _createSettingsCubit(bridge);
    final draftService = DraftService(await SharedPreferences.getInstance());
    final revenueCatService = _FakeRevenueCatService();
    final supportBannerService = await _createSupportBannerService();

    await tester.pumpWidget(
      _buildWorkspaceApp(
        bridge: bridge,
        settingsCubit: settingsCubit,
        draftService: draftService,
        revenueCatService: revenueCatService,
        supportBannerService: supportBannerService,
      ),
    );
    await _pumpUi(tester);

    await tester.ensureVisible(
      find.byKey(const ValueKey('setup_guide_button')),
    );
    await tester.tap(find.byKey(const ValueKey('setup_guide_button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('embedded_setup_guide_back_button')),
      findsOneWidget,
    );
  });

  testWidgets('offline landing setup guide button opens center overlay', (
    tester,
  ) async {
    final bridge = _MockBridgeService(
      initialState: BridgeConnectionState.disconnected,
    );
    final settingsCubit = await _createSettingsCubit(bridge);
    final draftService = DraftService(await SharedPreferences.getInstance());
    final revenueCatService = _FakeRevenueCatService();
    final supportBannerService = await _createSupportBannerService();

    await tester.pumpWidget(
      _buildWorkspaceApp(
        bridge: bridge,
        settingsCubit: settingsCubit,
        draftService: draftService,
        revenueCatService: revenueCatService,
        supportBannerService: supportBannerService,
      ),
    );
    await _pumpUi(tester);

    await tester.tap(
      find.byKey(const ValueKey('workspace_setup_guide_button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('embedded_setup_guide_back_button')),
      findsOneWidget,
    );
  });

  testWidgets('embedded setup guide back skip and done restore offline root', (
    tester,
  ) async {
    final bridge = _MockBridgeService(
      initialState: BridgeConnectionState.disconnected,
    );
    final settingsCubit = await _createSettingsCubit(bridge);
    final draftService = DraftService(await SharedPreferences.getInstance());
    final revenueCatService = _FakeRevenueCatService();
    final supportBannerService = await _createSupportBannerService();

    Future<void> expectOfflineRoot() async {
      await _pumpUi(tester);
      expect(
        find.text(
          'Bridge is not connected. Use the left pane to connect, or open the setup guide to configure a machine.',
        ),
        findsOneWidget,
      );
    }

    await tester.pumpWidget(
      _buildWorkspaceApp(
        bridge: bridge,
        settingsCubit: settingsCubit,
        draftService: draftService,
        revenueCatService: revenueCatService,
        supportBannerService: supportBannerService,
      ),
    );
    await expectOfflineRoot();

    await tester.tap(
      find.byKey(const ValueKey('workspace_setup_guide_button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('embedded_setup_guide_back_button')),
    );
    await expectOfflineRoot();

    await tester.tap(
      find.byKey(const ValueKey('workspace_setup_guide_button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('guide_skip_button')));
    await expectOfflineRoot();

    await tester.tap(
      find.byKey(const ValueKey('workspace_setup_guide_button')),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byKey(const ValueKey('guide_next_button')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const ValueKey('guide_done_button')));
    await expectOfflineRoot();
  });
}
