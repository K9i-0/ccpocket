import 'dart:async';
import 'dart:convert';

import 'package:ccpocket/features/local_bridge/local_bridge_screen.dart';
import 'package:ccpocket/features/local_bridge/state/local_bridge_cubit.dart';
import 'package:ccpocket/features/settings/models/settings_catalog.dart';
import 'package:ccpocket/features/settings/sections/about_settings_section.dart';
import 'package:ccpocket/features/settings/sections/connection_settings_section.dart';
import 'package:ccpocket/features/settings/sections/shortcuts_settings_section.dart';
import 'package:ccpocket/features/settings/settings_screen.dart';
import 'package:ccpocket/features/settings/state/settings_cubit.dart';
import 'package:ccpocket/features/settings/widgets/connected_bridge_tools_card.dart';
import 'package:ccpocket/features/settings/widgets/keyboard_shortcuts_dialog.dart';
import 'package:ccpocket/features/session_list/widgets/machine_edit_sheet.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/models/machine.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/models/protocol_version.dart';
import 'package:ccpocket/providers/machine_manager_cubit.dart';
import 'package:ccpocket/services/app_update_service.dart';
import 'package:ccpocket/services/bridge_latest_version_service.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/services/database_service.dart';
import 'package:ccpocket/services/in_app_review_service.dart';
import 'package:ccpocket/services/machine_manager_service.dart';
import 'package:ccpocket/services/revenuecat_service.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/bridge_version_test_values.dart';
import 'local_bridge/local_bridge_fakes.dart';

class _TestBridgeService extends BridgeService {
  _TestBridgeService({
    required bool connected,
    this.fakeLastUrl,
    this.fakeBridgeVersion,
    this.fakeAllowedDirs = const [],
    this.fakeProtocolCompatibility,
  }) : _isConnected = connected;

  final _connectionController =
      StreamController<BridgeConnectionState>.broadcast();
  bool _isConnected;
  final String? fakeLastUrl;
  final String? fakeBridgeVersion;
  final List<String> fakeAllowedDirs;
  final ProtocolCompatibility? fakeProtocolCompatibility;

  final List<String> connectedUrls = [];
  bool disconnectCalled = false;

  @override
  bool get isConnected => _isConnected;

  @override
  String? get lastUrl => fakeLastUrl;

  @override
  String? get httpBaseUrl {
    final url = fakeLastUrl;
    if (url == null) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final scheme = uri.scheme == 'wss' ? 'https' : 'http';
    return '$scheme://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
  }

  @override
  Map<String, String> get bridgeAuthHeaders {
    final url = fakeLastUrl;
    if (url == null) return const {};
    final token = Uri.tryParse(url)?.queryParameters['token'];
    return token == null || token.isEmpty
        ? const {}
        : {'Authorization': 'Bearer $token'};
  }

  @override
  String? get bridgeVersion => fakeBridgeVersion;

  @override
  List<String> get allowedDirs => fakeAllowedDirs;

  @override
  ProtocolCompatibility? get protocolCompatibility => fakeProtocolCompatibility;

  @override
  Stream<BridgeConnectionState> get connectionStatus =>
      _connectionController.stream;

  @override
  UsageResultMessage? get lastUsageResult =>
      _isConnected ? const UsageResultMessage(providers: []) : null;

  @override
  void requestUsage({bool refreshAntigravity = false}) {}

  @override
  Future<void> connect(
    String url, {
    bool isAutoReconnect = false,
    bool allowReconnectAfterIntentionalDisconnect = true,
  }) async {
    connectedUrls.add(url);
  }

  @override
  void disconnect() {
    disconnectCalled = true;
    _isConnected = false;
    _connectionController.add(BridgeConnectionState.disconnected);
  }

  @override
  void dispose() {
    _connectionController.close();
    super.dispose();
  }
}

class _FakeSecureStorage extends Fake implements FlutterSecureStorage {
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => null;

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {}
}

class _SeededSettingsCubit extends SettingsCubit {
  _SeededSettingsCubit(super.prefs, {required String? activeMachineId}) {
    emit(state.copyWith(activeMachineId: activeMachineId));
  }
}

class _StaticMachineManagerService extends Fake
    implements MachineManagerService {
  _StaticMachineManagerService(this._statuses);

  final _controller = StreamController<List<MachineWithStatus>>.broadcast();
  final List<MachineWithStatus> _statuses;

  @override
  Stream<List<MachineWithStatus>> get machines => _controller.stream;

  @override
  List<MachineWithStatus> get machinesWithStatus => _statuses;

  @override
  List<Machine> get currentMachines =>
      _statuses.map((item) => item.machine).toList();

  @override
  Future<void> init() async => _controller.add(_statuses);

  @override
  Future<void> checkAllHealth() async => _controller.add(_statuses);

  @override
  Future<MachineStatus> checkHealth(
    String machineId, {
    Duration timeout = const Duration(seconds: 5),
    String? password,
    Future<String?> Function()? promptForPassword,
  }) async => MachineStatus.online;

  @override
  Future<String?> getApiKey(String machineId) async => 'secret-token';

  @override
  Future<String?> getSshPassword(String machineId) async => null;

  @override
  Future<String?> getSshPrivateKey(String machineId) async => null;

  @override
  Future<String?> getSshJumpPassword(String machineId) async => null;

  @override
  Future<String?> getSshJumpPrivateKey(String machineId) async => null;

  @override
  Future<void> updateMachine(
    Machine machine, {
    String? apiKey,
    String? sshPassword,
    String? sshPrivateKey,
    String? sshJumpPassword,
    String? sshJumpPrivateKey,
    bool clearApiKey = false,
    bool clearCredentials = false,
    bool clearJumpCredentials = false,
  }) async {}

  @override
  void dispose() => _controller.close();
}

MachineManagerCubit _createMachineManagerCubit(MachineManagerService service) {
  return MachineManagerCubit(
    service,
    null,
    latestVersionService: BridgeLatestVersionService(
      httpClient: MockClient(
        (_) async =>
            http.Response('{"version":"$recommendedBridgeVersion"}', 200),
      ),
    ),
  );
}

Widget _wrapWithApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    locale: const Locale('en'),
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'CC Pocket',
      packageName: 'com.k9i.ccpocket',
      version: '1.181.0',
      buildNumber: '337',
      buildSignature: '',
    );
    AppUpdateService.instance.debugCachedUpdate = null;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    AppUpdateService.instance.debugCachedUpdate = null;
  });

  group('SettingsCubit desktop text zoom', () {
    test(
      'supports 0.8 to 1.4 range and zoomIn/zoomOut/resetZoom on desktop',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final cubit = SettingsCubit(prefs);

        expect(SettingsCubit.maxTextScale, 1.4);
        expect(cubit.state.textScale, 1.0);

        cubit.zoomIn();
        expect(cubit.state.textScale, 1.1);
        cubit.zoomIn();
        cubit.zoomIn();
        cubit.zoomIn();
        expect(cubit.state.textScale, 1.4);
        cubit.zoomIn();
        expect(cubit.state.textScale, 1.4);

        cubit.resetZoom();
        expect(cubit.state.textScale, 1.0);

        cubit.zoomOut();
        expect(cubit.state.textScale, 0.9);
        cubit.zoomOut();
        expect(cubit.state.textScale, 0.8);
        cubit.zoomOut();
        expect(cubit.state.textScale, 0.8);

        await cubit.close();
      },
    );

    test('keeps 1.0 upper bound on mobile', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cubit = SettingsCubit(prefs);

      expect(SettingsCubit.maxTextScale, 1.0);
      cubit.zoomIn();
      expect(cubit.state.textScale, 1.0);
      cubit.zoomOut();
      expect(cubit.state.textScale, 0.9);

      await cubit.close();
    });
  });

  group('Desktop two-pane Settings & initialCategory', () {
    testWidgets(
      'uses two-pane layout at 720px width and honors initialCategory',
      (tester) async {
        tester.view.physicalSize = const Size(720, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final settingsCubit = _SeededSettingsCubit(
          prefs,
          activeMachineId: null,
        );
        final manager = MachineManagerService(prefs, _FakeSecureStorage());
        final machineCubit = _createMachineManagerCubit(manager);
        final bridge = _TestBridgeService(connected: false);

        await tester.pumpWidget(
          MultiRepositoryProvider(
            providers: [
              RepositoryProvider<BridgeService>.value(value: bridge),
              RepositoryProvider<RevenueCatService>.value(
                value: RevenueCatService(),
              ),
              RepositoryProvider<DatabaseService>.value(
                value: DatabaseService(),
              ),
              RepositoryProvider<InAppReviewService>.value(
                value: InAppReviewService(prefs: prefs),
              ),
            ],
            child: MultiBlocProvider(
              providers: [
                BlocProvider<SettingsCubit>.value(value: settingsCubit),
                BlocProvider<MachineManagerCubit>.value(value: machineCubit),
              ],
              child: const MaterialApp(
                locale: Locale('en'),
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: SettingsScreen(
                  initialCategory: SettingsCategory.shortcuts,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 720px >= kSettingsTwoPaneBreakpoint (680) => two-pane Preferences layout.
        expect(
          find.byKey(const ValueKey('settings_detail_shortcuts')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('shortcuts_settings_section')),
          findsOneWidget,
        );
        // Both Local Bridge and Keyboard Shortcuts are first-class categories on macOS.
        expect(
          find.byKey(const ValueKey('settings_category_localBridge')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('settings_category_shortcuts')),
          findsOneWidget,
        );

        await settingsCubit.close();
        await machineCubit.close();
        bridge.dispose();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets('Settings search reveals keyboard shortcuts category', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(960, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsCubit = _SeededSettingsCubit(prefs, activeMachineId: null);
      final manager = MachineManagerService(prefs, _FakeSecureStorage());
      final machineCubit = _createMachineManagerCubit(manager);
      final bridge = _TestBridgeService(connected: false);

      await tester.pumpWidget(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<BridgeService>.value(value: bridge),
            RepositoryProvider<RevenueCatService>.value(
              value: RevenueCatService(),
            ),
            RepositoryProvider<DatabaseService>.value(value: DatabaseService()),
            RepositoryProvider<InAppReviewService>.value(
              value: InAppReviewService(prefs: prefs),
            ),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider<SettingsCubit>.value(value: settingsCubit),
              BlocProvider<MachineManagerCubit>.value(value: machineCubit),
            ],
            child: const MaterialApp(
              locale: Locale('en'),
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: SettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('settings_search_field')),
        'shortcut',
      );
      await tester.pump();

      final result = find.byKey(
        const ValueKey('settings_search_result_keyboard_shortcuts'),
      );
      expect(result, findsOneWidget);
      await tester.tap(result);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('settings_detail_shortcuts')),
        findsOneWidget,
      );

      await settingsCubit.close();
      await machineCubit.close();
      bridge.dispose();
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  });

  group('ConnectedBridgeSettings & Diagnostics', () {
    testWidgets(
      'shows loopback local Bridge banner, diagnostics, edit sheet, and quick actions',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final settingsCubit = _SeededSettingsCubit(
          prefs,
          activeMachineId: 'local-mac',
        );
        final machineService = _StaticMachineManagerService([
          MachineWithStatus(
            machine: const Machine(
              id: 'local-mac',
              name: 'My Mac',
              host: '127.0.0.1',
              port: 8765,
            ),
            status: MachineStatus.online,
            versionInfo: BridgeVersionInfo(version: recommendedBridgeVersion),
          ),
        ]);
        final machineCubit = _createMachineManagerCubit(machineService);
        final bridge = _TestBridgeService(
          connected: true,
          fakeLastUrl: 'ws://127.0.0.1:8765?token=abc',
          fakeBridgeVersion: recommendedBridgeVersion,
          fakeAllowedDirs: const ['/Users/dev/work'],
          fakeProtocolCompatibility: ProtocolCompatibility.forBridge(
            minimumProtocolVersion: 1,
            protocolVersion: 1,
          ),
        );
        var openedLocalBridge = false;
        final mockToolsClient = MockClient(
          (_) async => http.Response('Not Found', 404),
        );

        await tester.pumpWidget(
          MultiRepositoryProvider(
            providers: [RepositoryProvider<BridgeService>.value(value: bridge)],
            child: MultiBlocProvider(
              providers: [
                BlocProvider<SettingsCubit>.value(value: settingsCubit),
                BlocProvider<MachineManagerCubit>.value(value: machineCubit),
              ],
              child: _wrapWithApp(
                SingleChildScrollView(
                  child: ConnectionSettingsSection(
                    state: settingsCubit.state,
                    visibility: const SettingsVisibility(
                      hasActiveMachine: true,
                      bridgeConnected: true,
                      hasBridgeUrl: true,
                      isMacOS: true,
                    ),
                    onUpdateBridge: (_) {},
                    onOpenLocalBridge: () => openedLocalBridge = true,
                    toolsHttpClient: mockToolsClient,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Loopback badge and jump button.
        expect(
          find.byKey(const ValueKey('settings_connected_local_bridge_banner')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('settings_jump_to_local_bridge_button')),
        );
        expect(openedLocalBridge, isTrue);

        // Diagnostics card shows endpoint, version, protocol, and allowed dirs.
        expect(
          find.byKey(const ValueKey('settings_bridge_diagnostics_card')),
          findsOneWidget,
        );
        expect(find.text('/Users/dev/work'), findsOneWidget);
        expect(find.text('v1'), findsOneWidget);

        // Reconnect action calls bridge.connect.
        await tester.tap(
          find.byKey(const ValueKey('settings_reconnect_bridge_button')),
        );
        expect(bridge.connectedUrls, ['ws://127.0.0.1:8765?token=abc']);

        // Tapping connected machine tile opens MachineEditSheet.
        await tester.tap(
          find.byKey(const ValueKey('settings_bridge_machine_tile')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(MachineEditSheet), findsOneWidget);
        Navigator.of(tester.element(find.byType(MachineEditSheet))).pop();
        await tester.pumpAndSettle();

        // Disconnect action calls bridge.disconnect.
        await tester.tap(
          find.byKey(const ValueKey('settings_disconnect_bridge_button')),
        );
        expect(bridge.disconnectCalled, isTrue);

        await settingsCubit.close();
        await machineCubit.close();
        machineService.dispose();
        bridge.dispose();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets(
      'ConnectedBridgeToolsCard fetches /tools with Bearer auth and handles 404/error',
      (tester) async {
        final bridge = _TestBridgeService(
          connected: true,
          fakeLastUrl: 'ws://100.64.0.1:8765?token=my-secret',
        );
        String? seenAuth;
        var mode = 'ok';
        final client = MockClient((request) async {
          seenAuth = request.headers['Authorization'];
          if (mode == '404') return http.Response('Not Found', 404);
          if (mode == '500') return http.Response('Internal Error', 500);
          return http.Response(
            jsonEncode({
              'ready': true,
              'tools': [
                {
                  'id': 'node',
                  'name': 'Node.js',
                  'requirement': 'required',
                  'installed': true,
                  'ready': true,
                  'version': 'v24.0.0',
                  'docsUrl': 'https://nodejs.org',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        await tester.pumpWidget(
          _wrapWithApp(
            SingleChildScrollView(
              child: ConnectedBridgeToolsCard(
                bridge: bridge,
                httpClient: client,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(seenAuth, 'Bearer my-secret');
        expect(find.text('Node.js'), findsOneWidget);
        expect(find.text('Required · v24.0.0'), findsOneWidget);

        // 404 hides the card gracefully.
        mode = '404';
        await tester.pumpWidget(
          _wrapWithApp(
            SingleChildScrollView(
              child: ConnectedBridgeToolsCard(
                key: const ValueKey('tools_404'),
                bridge: bridge,
                httpClient: client,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('connected_bridge_tools_section')),
          findsNothing,
        );

        // 500 shows error card with retry button.
        mode = '500';
        await tester.pumpWidget(
          _wrapWithApp(
            SingleChildScrollView(
              child: ConnectedBridgeToolsCard(
                key: const ValueKey('tools_500'),
                bridge: bridge,
                httpClient: client,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('connected_bridge_tools_error_card')),
          findsOneWidget,
        );

        // Retrying once server recovers loads the tools list.
        mode = 'ok';
        await tester.tap(
          find.byKey(const ValueKey('connected_bridge_tools_retry_button')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Node.js'), findsOneWidget);

        bridge.dispose();
      },
    );
  });

  group('KeyboardShortcuts UI & Dialog', () {
    testWidgets('renders macOS vs non-macOS keycaps and opens/closes dialog', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithApp(
          const SingleChildScrollView(
            child: ShortcutsSettingsSection(isMacOS: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('shortcut_row_open_settings')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('shortcut_row_open_local_bridge')),
        findsOneWidget,
      );
      expect(find.text('⌘'), findsWidgets);

      await tester.pumpWidget(
        _wrapWithApp(
          const SingleChildScrollView(
            child: ShortcutsSettingsSection(isMacOS: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('shortcut_row_open_local_bridge')),
        findsNothing,
      );
      expect(find.text('Ctrl'), findsWidgets);

      // Dialog show & close.
      await tester.pumpWidget(
        _wrapWithApp(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  KeyboardShortcutsDialog.show(context, isMacOS: true),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('keyboard_shortcuts_dialog')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('keyboard_shortcuts_close_button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('keyboard_shortcuts_dialog')),
        findsNothing,
      );
    });
  });

  group('AboutSettingsSection Check for Updates', () {
    testWidgets('shows manual Check for Updates tile only on macOS', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithApp(
          const SingleChildScrollView(
            child: AboutSettingsSection(
              visibility: SettingsVisibility(isMacOS: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings_check_for_updates_tile')),
        findsOneWidget,
      );

      await tester.pumpWidget(
        _wrapWithApp(
          const SingleChildScrollView(
            child: AboutSettingsSection(
              visibility: SettingsVisibility(isMacOS: false, isMobile: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings_check_for_updates_tile')),
        findsNothing,
      );
    });
  });

  group('LocalBridgeScreen inline mode', () {
    testWidgets('renders without an AppBar when showAppBar is false', (
      tester,
    ) async {
      final bridge = FakeLocalBridge();
      await tester.pumpWidget(
        _wrapWithApp(
          LocalBridgeScreen(
            embedded: true,
            showAppBar: false,
            createCubit: () => LocalBridgeCubit(
              clientFactory: bridge.client,
              launcher: FakeLauncher(bridge, available: false),
              startTimeout: const Duration(seconds: 1),
              restartPollInterval: const Duration(milliseconds: 10),
              restartTimeout: const Duration(seconds: 1),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('local_bridge_inline_view')),
        findsOneWidget,
      );
      expect(find.byType(AppBar), findsNothing);
      expect(find.text('Running'), findsOneWidget);
    });
  });
}
