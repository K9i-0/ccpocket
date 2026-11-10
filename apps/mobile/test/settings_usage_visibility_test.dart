import 'dart:async';

import 'package:ccpocket/features/settings/models/settings_catalog.dart';
import 'package:ccpocket/features/settings/settings_screen.dart';
import 'package:ccpocket/features/settings/widgets/settings_home.dart';
import 'package:ccpocket/features/settings/widgets/settings_tiles.dart';
import 'package:ccpocket/features/settings/widgets/settings_visibility_builder.dart';
import 'package:ccpocket/features/settings/state/settings_cubit.dart';
import 'package:ccpocket/features/settings/state/settings_state.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/git_diff_interaction_mode.dart';
import 'package:ccpocket/models/image_paste_shortcut.dart';
import 'package:ccpocket/models/machine.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/models/new_session_tab.dart';
import 'package:ccpocket/providers/machine_manager_cubit.dart';
import 'package:ccpocket/services/app_update_service.dart';
import 'package:ccpocket/services/bridge_latest_version_service.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/services/database_service.dart';
import 'package:ccpocket/services/in_app_review_service.dart';
import 'package:ccpocket/services/machine_manager_service.dart';
import 'package:ccpocket/services/revenuecat_service.dart';
import 'package:ccpocket/services/ssh_startup_service.dart';
import 'package:ccpocket/services/support_banner_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/bridge_version_test_values.dart';

class _FakeBridgeService extends BridgeService {
  final _connectionController =
      StreamController<BridgeConnectionState>.broadcast();
  final _usageController = StreamController<UsageResultMessage>.broadcast();
  bool _connected;
  final UsageResultMessage? cachedUsage;
  final String? fakeLastUrl;
  bool disconnectCalled = false;

  _FakeBridgeService({
    required bool connected,
    this.cachedUsage,
    this.fakeLastUrl,
  }) : _connected = connected;

  @override
  bool get isConnected => _connected;

  @override
  String? get lastUrl => fakeLastUrl;

  @override
  Stream<BridgeConnectionState> get connectionStatus =>
      _connectionController.stream;

  @override
  Stream<UsageResultMessage> get usageResults => _usageController.stream;

  @override
  // Connected fakes answer with an empty result so the usage block in the
  // status card does not spin forever.
  UsageResultMessage? get lastUsageResult =>
      cachedUsage ??
      (_connected ? const UsageResultMessage(providers: []) : null);

  @override
  void requestUsage() {}

  @override
  void disconnect() {
    disconnectCalled = true;
    _connected = false;
    _connectionController.add(BridgeConnectionState.disconnected);
  }

  @override
  void dispose() {
    _connectionController.close();
    _usageController.close();
    super.dispose();
  }
}

class _FakeRevenueCatService extends RevenueCatService {
  _FakeRevenueCatService({required SupportCatalogState catalog})
    : super(publicApiKey: '', platform: TargetPlatform.iOS) {
    catalogState.value = catalog;
  }
}

class _SeededSettingsCubit extends SettingsCubit {
  _SeededSettingsCubit(super.prefs, {required String? activeMachineId}) {
    emit(state.copyWith(activeMachineId: activeMachineId));
  }
}

class _FakeSecureStorage extends Fake implements FlutterSecureStorage {
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
}

class _FakeSshStartupService extends SshStartupService {
  final Completer<SshResult> updateCompleter = Completer<SshResult>();

  _FakeSshStartupService(super.machineManager);

  @override
  Future<SshResult> updateBridgeServer(
    String machineId, {
    String? password,
    Future<String?> Function()? promptForPassword,
  }) {
    return updateCompleter.future;
  }
}

class _StaticMachineManagerService implements MachineManagerService {
  final _controller = StreamController<List<MachineWithStatus>>.broadcast();
  List<MachineWithStatus> _statuses;
  final String? sshPassword;

  _StaticMachineManagerService(this._statuses, {this.sshPassword});

  @override
  Stream<List<MachineWithStatus>> get machines => _controller.stream;

  @override
  Future<void> init() async {
    _controller.add(_statuses);
  }

  @override
  Future<void> checkAllHealth() async {
    _controller.add(_statuses);
  }

  @override
  Future<MachineStatus> checkHealth(
    String machineId, {
    Duration timeout = const Duration(seconds: 5),
    String? password,
    Future<String?> Function()? promptForPassword,
  }) async => _findStatus(machineId)?.status ?? MachineStatus.unknown;

  @override
  Future<Machine> recordConnection({
    required String host,
    required int port,
    String? apiKey,
    String? name,
    bool? useSsl,
    BridgeConnectionMode? connectionMode,
  }) async {
    return Machine(
      id: 'recorded',
      host: host,
      port: port,
      name: name,
      useSsl: useSsl ?? false,
      connectionMode: connectionMode ?? BridgeConnectionMode.automatic,
    );
  }

  @override
  Future<void> addMachine(
    Machine machine, {
    String? apiKey,
    String? sshPassword,
    String? sshPrivateKey,
    String? sshJumpPassword,
    String? sshJumpPrivateKey,
  }) async {}

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
  Future<void> deleteMachine(String id) async {}

  @override
  Future<void> toggleFavorite(String machineId) async {}

  @override
  Machine? getMachine(String id) => _findStatus(id)?.machine;

  @override
  Future<String?> getApiKey(String machineId) async => null;

  @override
  Future<String?> getSshPassword(String machineId) async => sshPassword;

  @override
  Future<String?> getSshPrivateKey(String machineId) async => null;

  @override
  Future<String?> getSshJumpPassword(String machineId) async => null;

  @override
  Future<String?> getSshJumpPrivateKey(String machineId) async => null;

  @override
  Future<String> buildWsUrl(String machineId) async => 'ws://127.0.0.1:8765';

  @override
  Future<String> buildWsUrlWithSshCredentials(
    String machineId, {
    String? password,
    Future<String?> Function()? promptForPassword,
  }) async => 'ws://127.0.0.1:8765';

  @override
  void configureBridgeTunnelResolvers({
    BridgeWsUrlResolver? wsUrlResolver,
    BridgeHttpBaseUrlResolver? httpBaseUrlResolver,
  }) {}

  @override
  Machine createNew({
    String? name,
    required String host,
    int port = 8765,
    bool useSsl = false,
  }) {
    return Machine(
      id: 'new',
      host: host,
      port: port,
      name: name,
      useSsl: useSsl,
    );
  }

  @override
  void startPeriodicHealthCheck({Duration? interval}) {}

  @override
  void stopPeriodicHealthCheck() {}

  @override
  List<Machine> get currentMachines =>
      _statuses.map((status) => status.machine).toList();

  @override
  List<MachineWithStatus> get machinesWithStatus => _statuses;

  @override
  void markConnected(String host, int port) {}

  @override
  Machine? findByHostPort(String host, int port) {
    for (final status in _statuses) {
      if (status.machine.host == host && status.machine.port == port) {
        return status.machine;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _controller.close();
  }

  void replaceStatuses(List<MachineWithStatus> statuses) {
    _statuses = statuses;
    _controller.add(_statuses);
  }

  MachineWithStatus? _findStatus(String id) {
    for (final status in _statuses) {
      if (status.machine.id == id) return status;
    }
    return null;
  }
}

Future<Widget> _buildScreen({
  required BridgeService bridge,
  required SettingsCubit settingsCubit,
  required MachineManagerCubit machineManagerCubit,
  RevenueCatService? revenueCatService,
  InAppReviewService? inAppReviewService,
  SupportBannerService? supportBannerService,
  bool focusConnection = false,
  bool focusSupport = false,
  bool focusUsage = false,
  bool focusAppUpdate = false,
  bool embedded = false,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final screen = MultiRepositoryProvider(
    providers: [
      RepositoryProvider<BridgeService>.value(value: bridge),
      RepositoryProvider<RevenueCatService>.value(
        value: revenueCatService ?? RevenueCatService(),
      ),
      RepositoryProvider<DatabaseService>.value(value: DatabaseService()),
      RepositoryProvider<InAppReviewService>.value(
        value: inAppReviewService ?? InAppReviewService(prefs: prefs),
      ),
    ],
    child: MultiBlocProvider(
      providers: [
        BlocProvider<SettingsCubit>.value(value: settingsCubit),
        BlocProvider<MachineManagerCubit>.value(value: machineManagerCubit),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: SettingsScreen(
          focusConnection: focusConnection,
          focusSupport: focusSupport,
          focusUsage: focusUsage,
          focusAppUpdate: focusAppUpdate,
          embedded: embedded,
        ),
      ),
    ),
  );
  if (supportBannerService == null) return screen;
  return ChangeNotifierProvider<SupportBannerService>.value(
    value: supportBannerService,
    child: screen,
  );
}

/// Opens a category from the settings home list (single-pane layout).
Future<void> _openCategory(
  WidgetTester tester,
  SettingsCategory category,
) async {
  // A previous pumpWidget can keep an earlier category page on the stack.
  tester
      .state<NavigatorState>(find.byType(Navigator).first)
      .popUntil((route) => route.isFirst);
  await tester.pumpAndSettle();
  final tile = find.byKey(ValueKey('settings_category_${category.name}'));
  await tester.scrollUntilVisible(
    tile,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

BridgeLatestVersionService _recommendedLatestVersionService() {
  return BridgeLatestVersionService(
    httpClient: MockClient(
      (_) async =>
          http.Response('{"version":"$recommendedBridgeVersion"}', 200),
    ),
  );
}

MachineManagerCubit _createMachineManagerCubit(MachineManagerService service) {
  return MachineManagerCubit(
    service,
    null,
    latestVersionService: _recommendedLatestVersionService(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const platformEnvironmentChannel = MethodChannel(
    'ccpocket/platform_environment',
  );

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'CC Pocket',
      packageName: 'dev.test.ccpocket',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platformEnvironmentChannel, null);
  });

  group('Settings usage visibility', () {
    testWidgets(
      'shows bridge update button only when connected machine is old',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final settingsCubit = _SeededSettingsCubit(
          prefs,
          activeMachineId: 'machine-1',
        );
        final machineManagerService = _StaticMachineManagerService([
          MachineWithStatus(
            machine: Machine(
              id: 'machine-1',
              name: 'Remote Mac',
              host: '100.64.0.1',
              sshEnabled: true,
              sshUsername: 'k9i',
            ),
            status: MachineStatus.online,
            versionInfo: BridgeVersionInfo(
              version: olderThanRecommendedBridgeVersion,
            ),
          ),
        ]);
        final machineManagerCubit = _createMachineManagerCubit(
          machineManagerService,
        );
        final bridge = _FakeBridgeService(
          connected: true,
          fakeLastUrl: 'ws://100.64.0.1:8765',
        );

        await tester.pumpWidget(
          await _buildScreen(
            bridge: bridge,
            settingsCubit: settingsCubit,
            machineManagerCubit: machineManagerCubit,
          ),
        );
        await tester.pumpAndSettle();
        await _openCategory(tester, SettingsCategory.connection);
        final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));

        expect(find.text(l.bridgeUpdateAvailable), findsOneWidget);
        expect(
          find.byKey(const ValueKey('settings_update_bridge_button')),
          findsOneWidget,
        );

        await settingsCubit.close();
        await machineManagerCubit.close();
        machineManagerService.dispose();
        bridge.dispose();
      },
    );

    testWidgets('disconnects and marks machine updating when update starts', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsCubit = _SeededSettingsCubit(
        prefs,
        activeMachineId: 'machine-1',
      );
      final machine = Machine(
        id: 'machine-1',
        name: 'Remote Mac',
        host: '100.64.0.1',
        sshEnabled: true,
        sshUsername: 'k9i',
      );
      final machineManagerService = _StaticMachineManagerService([
        MachineWithStatus(
          machine: machine,
          status: MachineStatus.online,
          versionInfo: BridgeVersionInfo(
            version: olderThanRecommendedBridgeVersion,
          ),
        ),
      ], sshPassword: 'secret');
      final sshService = _FakeSshStartupService(machineManagerService);
      final machineManagerCubit = MachineManagerCubit(
        machineManagerService,
        sshService,
        latestVersionService: _recommendedLatestVersionService(),
      );
      final bridge = _FakeBridgeService(
        connected: true,
        fakeLastUrl: 'ws://100.64.0.1:8765',
      );

      await tester.pumpWidget(
        await _buildScreen(
          bridge: bridge,
          settingsCubit: settingsCubit,
          machineManagerCubit: machineManagerCubit,
          embedded: true,
        ),
      );
      await tester.pumpAndSettle();
      await _openCategory(tester, SettingsCategory.connection);

      await tester.tap(
        find.byKey(const ValueKey('settings_update_bridge_button')),
      );
      await tester.pump();

      expect(bridge.disconnectCalled, isTrue);
      expect(machineManagerCubit.state.updatingMachineId, 'machine-1');

      machineManagerService.replaceStatuses([
        MachineWithStatus(
          machine: machine,
          status: MachineStatus.online,
          versionInfo: BridgeVersionInfo(version: recommendedBridgeVersion),
        ),
      ]);
      sshService.updateCompleter.complete(SshResult.success());
      await tester.pump();
      await tester.pump();

      await settingsCubit.close();
      await machineManagerCubit.close();
      machineManagerService.dispose();
      bridge.dispose();
    });

    testWidgets(
      'does not prompt for SSH password when updating with private key',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final settingsCubit = _SeededSettingsCubit(
          prefs,
          activeMachineId: 'machine-1',
        );
        final machine = Machine(
          id: 'machine-1',
          name: 'Remote Mac',
          host: '100.64.0.1',
          sshEnabled: true,
          sshUsername: 'k9i',
          sshAuthType: SshAuthType.privateKey,
          hasCredentials: true,
        );
        final machineManagerService = _StaticMachineManagerService([
          MachineWithStatus(
            machine: machine,
            status: MachineStatus.online,
            versionInfo: BridgeVersionInfo(
              version: olderThanRecommendedBridgeVersion,
            ),
          ),
        ]);
        final sshService = _FakeSshStartupService(machineManagerService);
        final machineManagerCubit = MachineManagerCubit(
          machineManagerService,
          sshService,
          latestVersionService: _recommendedLatestVersionService(),
        );
        final bridge = _FakeBridgeService(
          connected: true,
          fakeLastUrl: 'ws://100.64.0.1:8765',
        );

        await tester.pumpWidget(
          await _buildScreen(
            bridge: bridge,
            settingsCubit: settingsCubit,
            machineManagerCubit: machineManagerCubit,
            embedded: true,
          ),
        );
        await tester.pumpAndSettle();
        await _openCategory(tester, SettingsCategory.connection);

        await tester.tap(
          find.byKey(const ValueKey('settings_update_bridge_button')),
        );
        await tester.pump();

        final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
        expect(find.text(l.sshPassword), findsNothing);
        expect(bridge.disconnectCalled, isTrue);
        expect(machineManagerCubit.state.updatingMachineId, 'machine-1');

        machineManagerService.replaceStatuses([
          MachineWithStatus(
            machine: machine,
            status: MachineStatus.online,
            versionInfo: BridgeVersionInfo(version: recommendedBridgeVersion),
          ),
        ]);
        sshService.updateCompleter.complete(SshResult.success());
        await tester.pump();
        await tester.pump();

        await settingsCubit.close();
        await machineManagerCubit.close();
        machineManagerService.dispose();
        bridge.dispose();
      },
    );

    testWidgets(
      'shows bridge update button when npm latest is newer than required version',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final settingsCubit = _SeededSettingsCubit(
          prefs,
          activeMachineId: 'machine-1',
        );
        final machineManagerService = _StaticMachineManagerService([
          MachineWithStatus(
            machine: Machine(
              id: 'machine-1',
              name: 'Remote Mac',
              host: '100.64.0.1',
              sshEnabled: true,
              sshUsername: 'k9i',
            ),
            status: MachineStatus.online,
            versionInfo: BridgeVersionInfo(version: recommendedBridgeVersion),
          ),
        ]);
        final machineManagerCubit = MachineManagerCubit(
          machineManagerService,
          null,
          latestVersionService: BridgeLatestVersionService(
            httpClient: MockClient(
              (_) async => http.Response(
                '{"version":"$newerThanRecommendedBridgeVersion"}',
                200,
              ),
            ),
          ),
        );
        await machineManagerCubit.refreshLatestBridgeVersion();
        final bridge = _FakeBridgeService(
          connected: true,
          fakeLastUrl: 'ws://100.64.0.1:8765',
        );

        await tester.pumpWidget(
          await _buildScreen(
            bridge: bridge,
            settingsCubit: settingsCubit,
            machineManagerCubit: machineManagerCubit,
          ),
        );
        await tester.pumpAndSettle();
        await _openCategory(tester, SettingsCategory.connection);
        final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));

        expect(find.text(l.bridgeUpdateAvailable), findsOneWidget);
        expect(
          find.text(
            l.bridgeVersionCurrentLatest(
              recommendedBridgeVersion,
              newerThanRecommendedBridgeVersion,
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('settings_update_bridge_button')),
          findsOneWidget,
        );

        await settingsCubit.close();
        await machineManagerCubit.close();
        machineManagerService.dispose();
        bridge.dispose();
      },
    );

    testWidgets('hides bridge update button when latest or SSH is missing', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final latestSettingsCubit = _SeededSettingsCubit(
        prefs,
        activeMachineId: 'machine-1',
      );
      final latestService = _StaticMachineManagerService([
        MachineWithStatus(
          machine: Machine(
            id: 'machine-1',
            name: 'Remote Mac',
            host: '100.64.0.1',
            sshEnabled: true,
            sshUsername: 'k9i',
          ),
          status: MachineStatus.online,
          versionInfo: BridgeVersionInfo(version: recommendedBridgeVersion),
        ),
      ]);
      final latestCubit = _createMachineManagerCubit(latestService);
      final latestBridge = _FakeBridgeService(
        connected: true,
        fakeLastUrl: 'ws://100.64.0.1:8765',
      );

      await tester.pumpWidget(
        await _buildScreen(
          bridge: latestBridge,
          settingsCubit: latestSettingsCubit,
          machineManagerCubit: latestCubit,
        ),
      );
      await tester.pumpAndSettle();
      await _openCategory(tester, SettingsCategory.connection);
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));

      expect(find.text(l.bridgeIsUpToDate), findsOneWidget);
      expect(
        find.byKey(const ValueKey('settings_update_bridge_button')),
        findsNothing,
      );

      await latestSettingsCubit.close();
      await latestCubit.close();
      latestService.dispose();
      latestBridge.dispose();

      final latestMissingSshSettingsCubit = _SeededSettingsCubit(
        prefs,
        activeMachineId: 'machine-1',
      );
      final latestMissingSshService = _StaticMachineManagerService([
        MachineWithStatus(
          machine: Machine(
            id: 'machine-1',
            name: 'Remote Mac',
            host: '100.64.0.1',
            sshEnabled: false,
          ),
          status: MachineStatus.online,
          versionInfo: BridgeVersionInfo(version: recommendedBridgeVersion),
        ),
      ]);
      final latestMissingSshCubit = _createMachineManagerCubit(
        latestMissingSshService,
      );
      final latestMissingSshBridge = _FakeBridgeService(
        connected: true,
        fakeLastUrl: 'ws://100.64.0.1:8765',
      );

      await tester.pumpWidget(
        await _buildScreen(
          bridge: latestMissingSshBridge,
          settingsCubit: latestMissingSshSettingsCubit,
          machineManagerCubit: latestMissingSshCubit,
        ),
      );
      await tester.pumpAndSettle();
      await _openCategory(tester, SettingsCategory.connection);

      expect(find.text(l.bridgeIsUpToDate), findsOneWidget);
      expect(
        find.text(
          l.bridgeVersionCurrentExpected(
            recommendedBridgeVersion,
            recommendedBridgeVersion,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('settings_bridge_update_setup_tile')),
        findsNothing,
      );

      await latestMissingSshSettingsCubit.close();
      await latestMissingSshCubit.close();
      latestMissingSshService.dispose();
      latestMissingSshBridge.dispose();

      final missingSshSettingsCubit = _SeededSettingsCubit(
        prefs,
        activeMachineId: 'machine-1',
      );
      final missingSshService = _StaticMachineManagerService([
        MachineWithStatus(
          machine: Machine(
            id: 'machine-1',
            name: 'Remote Mac',
            host: '100.64.0.1',
            sshEnabled: false,
          ),
          status: MachineStatus.online,
          versionInfo: BridgeVersionInfo(
            version: olderThanRecommendedBridgeVersion,
          ),
        ),
      ]);
      final missingSshCubit = _createMachineManagerCubit(missingSshService);
      final missingSshBridge = _FakeBridgeService(
        connected: true,
        fakeLastUrl: 'ws://100.64.0.1:8765',
      );

      await tester.pumpWidget(
        await _buildScreen(
          bridge: missingSshBridge,
          settingsCubit: missingSshSettingsCubit,
          machineManagerCubit: missingSshCubit,
        ),
      );
      await tester.pumpAndSettle();
      await _openCategory(tester, SettingsCategory.connection);

      expect(find.text(l.bridgeUpdateRequiresSetup), findsOneWidget);
      expect(
        find.byKey(const ValueKey('settings_update_bridge_button')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('settings_bridge_update_setup_tile')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('settings_bridge_update_setup_tile')),
      );
      await tester.pumpAndSettle();

      expect(find.text(l.bridgeUpdateSetupTitle), findsOneWidget);
      expect(find.text(l.bridgeUpdateSetupEnableSsh), findsOneWidget);
      expect(find.text(l.bridgeUpdateSetupCommand), findsOneWidget);

      await missingSshSettingsCubit.close();
      await missingSshCubit.close();
      missingSshService.dispose();
      missingSshBridge.dispose();
    });

    testWidgets(
      'hides usage section when disconnected even with cached usage',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final settingsCubit = _SeededSettingsCubit(
          prefs,
          activeMachineId: null,
        );
        final manager = MachineManagerService(prefs, _FakeSecureStorage());
        final machineManagerCubit = _createMachineManagerCubit(manager);
        final bridge = _FakeBridgeService(
          connected: false,
          cachedUsage: const UsageResultMessage(
            providers: [
              UsageInfo(
                provider: 'codex',
                fiveHour: UsageWindow(
                  utilization: 0.08,
                  resetsAt: '2026-04-12T10:19:42Z',
                ),
              ),
            ],
          ),
        );
        await tester.pumpWidget(
          await _buildScreen(
            bridge: bridge,
            settingsCubit: settingsCubit,
            machineManagerCubit: machineManagerCubit,
          ),
        );
        await tester.pumpAndSettle();

        final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));

        expect(find.text(l.settingsUsageSectionTitle), findsNothing);
        expect(find.byKey(const ValueKey('usage_card_codex')), findsNothing);
        expect(
          find.byKey(const ValueKey('settings_category_usage')),
          findsNothing,
        );
        expect(find.byKey(const ValueKey('settings_item_usage')), findsNothing);
        expect(
          find.byKey(const ValueKey('settings_category_appearance')),
          findsOneWidget,
        );

        await settingsCubit.close();
        await machineManagerCubit.close();
        bridge.dispose();
      },
    );

    testWidgets('groups appearance and input settings in a stable order', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsCubit = _SeededSettingsCubit(prefs, activeMachineId: null);
      final manager = MachineManagerService(prefs, _FakeSecureStorage());
      final machineManagerCubit = _createMachineManagerCubit(manager);
      final bridge = _FakeBridgeService(connected: false);

      await tester.pumpWidget(
        await _buildScreen(
          bridge: bridge,
          settingsCubit: settingsCubit,
          machineManagerCubit: machineManagerCubit,
        ),
      );
      await tester.pumpAndSettle();

      double top(String id) =>
          tester.getTopLeft(find.byKey(ValueKey('settings_item_$id'))).dy;

      await _openCategory(tester, SettingsCategory.appearance);
      expect(top(SettingsEntryIds.theme), lessThan(top('language')));
      expect(top('language'), lessThan(top('app_icon')));
      expect(top('app_icon'), lessThan(top('text_density')));
      expect(find.byKey(const ValueKey('app_icon_tile')), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await _openCategory(tester, SettingsCategory.input);
      expect(
        top(SettingsEntryIds.defaultInputDelivery),
        lessThan(top(SettingsEntryIds.voiceInput)),
      );
      expect(
        top(SettingsEntryIds.voiceInput),
        lessThan(top(SettingsEntryIds.hideVoiceInput)),
      );
      expect(
        top(SettingsEntryIds.hideVoiceInput),
        lessThan(top(SettingsEntryIds.openGalleryDirectly)),
      );

      await settingsCubit.close();
      await machineManagerCubit.close();
      bridge.dispose();
    });

    testWidgets('shows both agent controls when both agents are enabled', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsCubit = _SeededSettingsCubit(prefs, activeMachineId: null);
      final manager = MachineManagerService(prefs, _FakeSecureStorage());
      final machineManagerCubit = _createMachineManagerCubit(manager);
      final bridge = _FakeBridgeService(connected: false);

      await tester.pumpWidget(
        await _buildScreen(
          bridge: bridge,
          settingsCubit: settingsCubit,
          machineManagerCubit: machineManagerCubit,
        ),
      );
      await tester.pumpAndSettle();
      await _openCategory(tester, SettingsCategory.agents);

      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('enabled_agents_selector')),
        180,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('enabled_agents_selector')),
        findsOneWidget,
      );
      expect(find.text(l.settingsNewSessionTabs), findsOneWidget);
      expect(find.text(l.showHiddenDirectories), findsOneWidget);
      expect(
        find.byKey(const ValueKey('show_hidden_directories_toggle')),
        findsOneWidget,
      );
      expect(find.text(l.autoRenameCodexSessions), findsOneWidget);
      expect(find.text(l.showExtendedCodexEfforts), findsOneWidget);
      expect(find.text(l.autoRenameClaudeSessions), findsOneWidget);

      await settingsCubit.close();
      await machineManagerCubit.close();
      bridge.dispose();
    });

    testWidgets('toggles hidden directories from agent settings', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsCubit = _SeededSettingsCubit(prefs, activeMachineId: null);
      final manager = MachineManagerService(prefs, _FakeSecureStorage());
      final machineManagerCubit = _createMachineManagerCubit(manager);
      final bridge = _FakeBridgeService(connected: false);

      await tester.pumpWidget(
        await _buildScreen(
          bridge: bridge,
          settingsCubit: settingsCubit,
          machineManagerCubit: machineManagerCubit,
        ),
      );
      await tester.pumpAndSettle();
      await _openCategory(tester, SettingsCategory.agents);

      final toggle = find.byKey(
        const ValueKey('show_hidden_directories_toggle'),
      );
      await tester.scrollUntilVisible(toggle, 180);
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      expect(settingsCubit.state.showHiddenDirectories, isFalse);

      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(settingsCubit.state.showHiddenDirectories, isTrue);
      expect(prefs.getBool('settings_show_hidden_directories'), isTrue);

      await settingsCubit.close();
      await machineManagerCubit.close();
      bridge.dispose();
    });

    testWidgets('toggles extended Codex Efforts from agent settings', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsCubit = _SeededSettingsCubit(prefs, activeMachineId: null);
      final manager = MachineManagerService(prefs, _FakeSecureStorage());
      final machineManagerCubit = _createMachineManagerCubit(manager);
      final bridge = _FakeBridgeService(connected: false);

      await tester.pumpWidget(
        await _buildScreen(
          bridge: bridge,
          settingsCubit: settingsCubit,
          machineManagerCubit: machineManagerCubit,
        ),
      );
      await tester.pumpAndSettle();
      await _openCategory(tester, SettingsCategory.agents);

      final toggle = find.byKey(
        const ValueKey('show_extended_codex_efforts_toggle'),
      );
      await tester.scrollUntilVisible(toggle, 180);
      await tester.pumpAndSettle();

      expect(settingsCubit.state.showExtendedCodexEfforts, isFalse);
      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(settingsCubit.state.showExtendedCodexEfforts, isTrue);
      expect(prefs.getBool('settings_show_extended_codex_efforts'), isTrue);

      await settingsCubit.close();
      await machineManagerCubit.close();
      bridge.dispose();
    });

    testWidgets('hides Claude agent controls when only Codex is enabled', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'settings_new_session_tabs': tabsToJson(const [NewSessionTab.codex]),
      });
      final prefs = await SharedPreferences.getInstance();
      final settingsCubit = _SeededSettingsCubit(prefs, activeMachineId: null);
      final manager = MachineManagerService(prefs, _FakeSecureStorage());
      final machineManagerCubit = _createMachineManagerCubit(manager);
      final bridge = _FakeBridgeService(connected: false);

      await tester.pumpWidget(
        await _buildScreen(
          bridge: bridge,
          settingsCubit: settingsCubit,
          machineManagerCubit: machineManagerCubit,
        ),
      );
      await tester.pumpAndSettle();
      await _openCategory(tester, SettingsCategory.agents);

      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('enabled_agents_selector')),
        180,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('enabled_agents_selector')),
        findsOneWidget,
      );
      expect(find.text(l.autoRenameCodexSessions), findsOneWidget);
      expect(find.text(l.showExtendedCodexEfforts), findsOneWidget);
      expect(find.text(l.settingsNewSessionTabs), findsNothing);
      expect(find.text(l.autoRenameClaudeSessions), findsNothing);

      await settingsCubit.close();
      await machineManagerCubit.close();
      bridge.dispose();
    });

    testWidgets('shows weekly-only Codex usage without a five-hour row', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsCubit = _SeededSettingsCubit(
        prefs,
        activeMachineId: 'machine-1',
      );
      final manager = MachineManagerService(prefs, _FakeSecureStorage());
      final machineManagerCubit = _createMachineManagerCubit(manager);
      final resetsAt = DateTime.now().add(
        const Duration(days: 6, hours: 13, minutes: 34, seconds: 55),
      );
      final bridge = _FakeBridgeService(
        connected: true,
        fakeLastUrl: 'ws://127.0.0.1:8765',
        cachedUsage: UsageResultMessage(
          providers: [
            UsageInfo(
              provider: 'codex',
              sevenDay: UsageWindow(
                utilization: 0.09,
                resetsAt: resetsAt.toIso8601String(),
              ),
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        await _buildScreen(
          bridge: bridge,
          settingsCubit: settingsCubit,
          machineManagerCubit: machineManagerCubit,
        ),
      );
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('usage_card_codex')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text(l.settingsUsageSectionTitle), findsOneWidget);
      expect(find.byKey(const ValueKey('usage_card_codex')), findsOneWidget);
      final codexCard = find.byKey(const ValueKey('usage_card_codex'));
      expect(
        find.descendant(of: codexCard, matching: find.text('1w')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: codexCard, matching: find.text('5h')),
        findsNothing,
      );
      expect(find.textContaining('Resets in 6d 13h'), findsOneWidget);

      await settingsCubit.close();
      await machineManagerCubit.close();
      bridge.dispose();
    });

    testWidgets('shows Claude and Codex usage cards without Claude links', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsCubit = _SeededSettingsCubit(
        prefs,
        activeMachineId: 'machine-1',
      );
      final manager = MachineManagerService(prefs, _FakeSecureStorage());
      final machineManagerCubit = _createMachineManagerCubit(manager);
      final resetsAt = DateTime.now()
          .add(const Duration(hours: 3))
          .toIso8601String();
      final bridge = _FakeBridgeService(
        connected: true,
        fakeLastUrl: 'ws://127.0.0.1:8765',
        cachedUsage: UsageResultMessage(
          providers: [
            UsageInfo(
              provider: 'codex',
              sevenDay: UsageWindow(utilization: 53, resetsAt: resetsAt),
            ),
            UsageInfo(
              provider: 'claude',
              fiveHour: UsageWindow(utilization: 20, resetsAt: resetsAt),
              sevenDay: UsageWindow(utilization: 64, resetsAt: resetsAt),
              modelWindows: [
                UsageModelWindow(
                  label: 'Fable',
                  utilization: 28,
                  resetsAt: resetsAt,
                ),
              ],
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        await _buildScreen(
          bridge: bridge,
          settingsCubit: settingsCubit,
          machineManagerCubit: machineManagerCubit,
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('usage_card_codex')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      final claudeCard = find.byKey(const ValueKey('usage_card_claude'));
      final codexCard = find.byKey(const ValueKey('usage_card_codex'));
      expect(claudeCard, findsOneWidget);
      expect(codexCard, findsOneWidget);
      // Claude is listed before Codex regardless of the Bridge order.
      expect(
        tester.getTopLeft(claudeCard).dy,
        lessThan(tester.getTopLeft(codexCard).dy),
      );
      expect(
        find.descendant(of: claudeCard, matching: find.text('Claude')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: claudeCard, matching: find.text('5h')),
        findsOneWidget,
      );
      // Remaining mode applies to both providers.
      expect(
        find.descendant(of: claudeCard, matching: find.text('36%')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: codexCard, matching: find.text('47%')),
        findsOneWidget,
      );
      // Model-scoped weekly limits only appear for accounts that have them.
      final fableRow = find.byKey(const ValueKey('usage_model_window_Fable'));
      expect(find.descendant(of: claudeCard, matching: fableRow), findsOne);
      expect(find.descendant(of: codexCard, matching: fableRow), findsNothing);
      expect(
        find.descendant(of: fableRow, matching: find.text('Fable')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: fableRow, matching: find.text('72%')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('claude_api_billing_tile')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('claude_subscription_usage_tile')),
        findsNothing,
      );

      settingsCubit.toggleUsageDisplayMode();
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: claudeCard, matching: find.text('64%')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: codexCard, matching: find.text('53%')),
        findsOneWidget,
      );

      await settingsCubit.close();
      await machineManagerCubit.close();
      bridge.dispose();
    });

    testWidgets('shows only Claude when Codex usage is absent', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsCubit = _SeededSettingsCubit(
        prefs,
        activeMachineId: 'machine-1',
      );
      final manager = MachineManagerService(prefs, _FakeSecureStorage());
      final machineManagerCubit = _createMachineManagerCubit(manager);
      final bridge = _FakeBridgeService(
        connected: true,
        fakeLastUrl: 'ws://127.0.0.1:8765',
        cachedUsage: const UsageResultMessage(
          providers: [
            UsageInfo(
              provider: 'claude',
              fiveHour: UsageWindow(
                utilization: 20,
                resetsAt: '2026-04-12T10:19:42Z',
              ),
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        await _buildScreen(
          bridge: bridge,
          settingsCubit: settingsCubit,
          machineManagerCubit: machineManagerCubit,
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('usage_card_claude')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const ValueKey('usage_card_codex')), findsNothing);
      expect(
        find.byKey(const ValueKey('usage_card_placeholder')),
        findsNothing,
      );

      await settingsCubit.close();
      await machineManagerCubit.close();
      bridge.dispose();
    });

    testWidgets('focuses usage and shows pace guidance', (tester) async {
      tester.view.physicalSize = const Size(390, 560);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsCubit = _SeededSettingsCubit(prefs, activeMachineId: null);
      final manager = MachineManagerService(prefs, _FakeSecureStorage());
      final machineManagerCubit = _createMachineManagerCubit(manager);
      final resetsAt = DateTime.now().add(const Duration(hours: 3));
      final bridge = _FakeBridgeService(
        connected: true,
        fakeLastUrl: 'ws://127.0.0.1:8765',
        cachedUsage: UsageResultMessage(
          providers: [
            UsageInfo(
              provider: 'codex',
              fiveHour: UsageWindow(
                utilization: 40,
                resetsAt: resetsAt.toIso8601String(),
              ),
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        await _buildScreen(
          bridge: bridge,
          settingsCubit: settingsCubit,
          machineManagerCubit: machineManagerCubit,
          focusUsage: true,
        ),
      );
      await tester.pumpAndSettle();

      // The whole status card glows instead of a rectangular tint.
      expect(
        tester
            .widget<SettingsItem>(
              find.byWidgetPredicate(
                (w) => w is SettingsItem && w.id == 'usage',
              ),
            )
            .framed,
        isTrue,
      );
      // Usage is on the settings home, so no extra page is pushed and a
      // single back leaves settings.
      expect(find.byType(SettingsHome), findsOneWidget);
      expect(
        tester.state<NavigatorState>(find.byType(Navigator).first).canPop(),
        isFalse,
      );
      expect(find.byKey(const ValueKey('usage_card_codex')), findsOneWidget);
      // Compact card: pace label inline, expected usage as a bar marker,
      // and no "will last" sentence.
      expect(
        find.textContaining('On pace', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('usage_expected_marker')),
        findsOneWidget,
      );
      expect(find.text('On track to last until reset'), findsNothing);
      final usageRect = tester.getRect(
        find.byKey(const ValueKey('usage_card_codex')),
      );
      final listRect = tester.getRect(
        find.byKey(const PageStorageKey('settings_list')),
      );
      expect(usageRect.overlaps(listRect), isTrue);

      await settingsCubit.close();
      await machineManagerCubit.close();
      bridge.dispose();
    });

    testWidgets('focusUsage glows the status card then fades', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsCubit = _SeededSettingsCubit(prefs, activeMachineId: null);
      final manager = MachineManagerService(prefs, _FakeSecureStorage());
      final machineManagerCubit = _createMachineManagerCubit(manager);
      final bridge = _FakeBridgeService(
        connected: true,
        fakeLastUrl: 'ws://127.0.0.1:8765',
      );

      await tester.pumpWidget(
        await _buildScreen(
          bridge: bridge,
          settingsCubit: settingsCubit,
          machineManagerCubit: machineManagerCubit,
          focusUsage: true,
        ),
      );
      bool glowing() => tester
          .widget<SettingsItemHighlight>(
            find.descendant(
              of: find.byKey(const ValueKey('settings_item_usage')),
              matching: find.byType(SettingsItemHighlight),
            ),
          )
          .highlighted;

      expect(glowing(), isFalse);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(glowing(), isTrue);
      expect(find.byType(SettingsHighlightFrame), findsWidgets);
      await tester.pump(const Duration(milliseconds: 2500));
      await tester.pumpAndSettle();
      expect(glowing(), isFalse);

      await settingsCubit.close();
      await machineManagerCubit.close();
      bridge.dispose();
    });

    testWidgets('defaults to remaining mode and toggles to used', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsCubit = _SeededSettingsCubit(
        prefs,
        activeMachineId: 'machine-1',
      );
      final manager = MachineManagerService(prefs, _FakeSecureStorage());
      final machineManagerCubit = _createMachineManagerCubit(manager);
      final bridge = _FakeBridgeService(
        connected: true,
        fakeLastUrl: 'ws://127.0.0.1:8765',
        cachedUsage: const UsageResultMessage(
          providers: [
            UsageInfo(
              provider: 'codex',
              fiveHour: UsageWindow(
                utilization: 14,
                resetsAt: '2026-04-12T10:19:42Z',
              ),
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        await _buildScreen(
          bridge: bridge,
          settingsCubit: settingsCubit,
          machineManagerCubit: machineManagerCubit,
        ),
      );
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('usage_card_codex')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text(l.usageDisplayModeRemaining), findsOneWidget);
      expect(find.text('86%'), findsOneWidget);

      await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('usage_display_mode_button'))),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('usage_display_mode_button')));
      await tester.pumpAndSettle();

      expect(find.text(l.usageDisplayModeUsed), findsOneWidget);
      expect(find.text('14%'), findsOneWidget);

      await settingsCubit.close();
      await machineManagerCubit.close();
      bridge.dispose();
    });

    test('usage display mode persists through SettingsCubit reload', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final firstCubit = SettingsCubit(prefs);

      expect(firstCubit.state.usageDisplayMode, UsageDisplayMode.remaining);

      firstCubit.setUsageDisplayMode(UsageDisplayMode.used);
      await firstCubit.close();

      final secondCubit = SettingsCubit(prefs);
      expect(secondCubit.state.usageDisplayMode, UsageDisplayMode.used);

      await secondCubit.close();
    });

    testWidgets('hides spread appeal before review thresholds are met', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsCubit = _SeededSettingsCubit(
        prefs,
        activeMachineId: 'machine-1',
      );
      final manager = MachineManagerService(prefs, _FakeSecureStorage());
      final machineManagerCubit = _createMachineManagerCubit(manager);
      final bridge = _FakeBridgeService(
        connected: true,
        fakeLastUrl: 'ws://127.0.0.1:8765',
      );

      await tester.pumpWidget(
        await _buildScreen(
          bridge: bridge,
          settingsCubit: settingsCubit,
          machineManagerCubit: machineManagerCubit,
          inAppReviewService: InAppReviewService(
            prefs: prefs,
            now: () => DateTime(2026, 4, 15, 12),
            appVersionLoader: () async => '1.50.0',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openCategory(tester, SettingsCategory.support);
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));

      await tester.scrollUntilVisible(
        find.text(l.shareApp),
        500,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('spread_appeal_message')), findsNothing);
      expect(find.text(l.spreadAppealMessage), findsNothing);

      await settingsCubit.close();
      await machineManagerCubit.close();
      bridge.dispose();
    });

    testWidgets('shows spread appeal after review thresholds are met', (
      tester,
    ) async {
      final now = DateTime(2026, 4, 15, 12);
      SharedPreferences.setMockInitialValues({
        'review.first_seen_at_ms': now
            .subtract(const Duration(days: 5))
            .millisecondsSinceEpoch,
        'review.successful_connections': 3,
        'review.created_sessions': 3,
        'review.usage_days': const ['2026-04-13', '2026-04-15'],
      });
      final prefs = await SharedPreferences.getInstance();
      final settingsCubit = _SeededSettingsCubit(
        prefs,
        activeMachineId: 'machine-1',
      );
      final manager = MachineManagerService(prefs, _FakeSecureStorage());
      final machineManagerCubit = _createMachineManagerCubit(manager);
      final bridge = _FakeBridgeService(
        connected: true,
        fakeLastUrl: 'ws://127.0.0.1:8765',
      );

      await tester.pumpWidget(
        await _buildScreen(
          bridge: bridge,
          settingsCubit: settingsCubit,
          machineManagerCubit: machineManagerCubit,
          inAppReviewService: InAppReviewService(
            prefs: prefs,
            now: () => now,
            appVersionLoader: () async => '1.50.0',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openCategory(tester, SettingsCategory.support);
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('spread_appeal_message')),
        500,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump();

      expect(find.text(l.spreadAppealMessage), findsOneWidget);
      expect(l.spreadAppealMessage, isNot(contains('GitHub')));
      expect(find.text(l.shareApp), findsOneWidget);
      expect(find.text(l.starOnGithub), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(l.shareApp)).dy,
        lessThan(tester.getTopLeft(find.text(l.starOnGithub)).dy),
      );

      await settingsCubit.close();
      await machineManagerCubit.close();
      bridge.dispose();
    });

    testWidgets('shows spread appeal when debug force support prompts is on', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsCubit = _SeededSettingsCubit(
        prefs,
        activeMachineId: 'machine-1',
      );
      final manager = MachineManagerService(prefs, _FakeSecureStorage());
      final machineManagerCubit = _createMachineManagerCubit(manager);
      final bridge = _FakeBridgeService(
        connected: true,
        fakeLastUrl: 'ws://127.0.0.1:8765',
      );
      final reviewService = InAppReviewService(
        prefs: prefs,
        now: () => DateTime(2026, 4, 15, 12),
        appVersionLoader: () async => '1.50.0',
      );
      final supportBannerService = SupportBannerService(
        prefs: prefs,
        reviewService: reviewService,
      );
      await supportBannerService.setDebugForceShowOverride(true);

      await tester.pumpWidget(
        await _buildScreen(
          bridge: bridge,
          settingsCubit: settingsCubit,
          machineManagerCubit: machineManagerCubit,
          inAppReviewService: reviewService,
          supportBannerService: supportBannerService,
        ),
      );
      await tester.pumpAndSettle();
      await _openCategory(tester, SettingsCategory.support);
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('spread_appeal_message')),
        500,
        scrollable: find.byType(Scrollable),
      );
      await tester.pump();

      expect(find.text(l.spreadAppealMessage), findsOneWidget);
      expect(find.text(l.shareApp), findsOneWidget);

      await settingsCubit.close();
      await machineManagerCubit.close();
      bridge.dispose();
    });

    testWidgets('focusSupport scrolls support entry into view', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 560);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsCubit = _SeededSettingsCubit(
        prefs,
        activeMachineId: 'machine-1',
      );
      final manager = MachineManagerService(prefs, _FakeSecureStorage());
      final machineManagerCubit = _createMachineManagerCubit(manager);
      final bridge = _FakeBridgeService(
        connected: true,
        fakeLastUrl: 'ws://127.0.0.1:8765',
      );
      final revenueCat = _FakeRevenueCatService(
        catalog: const SupportCatalogState(
          isAvailable: true,
          isLoading: false,
          isSupporter: false,
          packages: [
            SupportPackage(
              id: r'$rc_monthly',
              productId: 'supporter_monthly_10',
              title: 'Supporter \$9.99/mo',
              priceLabel: '\$9.99',
              kind: SupportPackageKind.monthly,
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        await _buildScreen(
          bridge: bridge,
          settingsCubit: settingsCubit,
          machineManagerCubit: machineManagerCubit,
          revenueCatService: revenueCat,
          focusSupport: true,
        ),
      );
      // Reaching the lazily built support section can take several frames.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }

      final supportDy = tester
          .getTopLeft(find.byKey(const ValueKey('supporter_entry_button')))
          .dy;
      expect(supportDy, greaterThanOrEqualTo(0));
      expect(supportDy, lessThan(560));

      await settingsCubit.close();
      await machineManagerCubit.close();
      bridge.dispose();
    });
  });

  group('Settings app update focus', () {
    Future<(_SeededSettingsCubit, MachineManagerCubit, _FakeBridgeService)>
    pumpSettings(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsCubit = _SeededSettingsCubit(prefs, activeMachineId: null);
      final manager = MachineManagerService(prefs, _FakeSecureStorage());
      final machineManagerCubit = _createMachineManagerCubit(manager);
      final bridge = _FakeBridgeService(connected: false);
      await tester.pumpWidget(
        await _buildScreen(
          bridge: bridge,
          settingsCubit: settingsCubit,
          machineManagerCubit: machineManagerCubit,
          focusAppUpdate: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      return (settingsCubit, machineManagerCubit, bridge);
    }

    final appUpdateItem = find.byWidgetPredicate(
      (w) => w is SettingsItem && w.id == SettingsEntryIds.appUpdate,
    );

    testWidgets('opens about and highlights the update card', (tester) async {
      AppUpdateService.instance.debugCachedUpdate = const AppUpdateInfo(
        latestVersion: '9.9.9',
        currentVersion: '1.0.0',
        downloadUrl: 'https://example.com/app.dmg',
        releaseUrl: 'https://example.com/release',
        installMode: AppUpdateInstallMode.nativeUpdater,
      );
      addTearDown(() => AppUpdateService.instance.debugCachedUpdate = null);

      final (settingsCubit, machineManagerCubit, bridge) = await pumpSettings(
        tester,
      );

      expect(appUpdateItem, findsOneWidget);
      expect(tester.widget<SettingsItem>(appUpdateItem).framed, isTrue);
      final frame = find.descendant(
        of: appUpdateItem,
        matching: find.byType(SettingsHighlightFrame),
      );
      expect(SettingsItemHighlight.of(tester.element(frame)), isTrue);
      expect(find.text('Update'), findsOneWidget);

      await tester.pumpAndSettle(const Duration(seconds: 3));
      await settingsCubit.close();
      await machineManagerCubit.close();
      bridge.dispose();
    });

    testWidgets('stays on the home without a pending update', (tester) async {
      final (settingsCubit, machineManagerCubit, bridge) = await pumpSettings(
        tester,
      );

      expect(find.byType(SettingsHome), findsOneWidget);
      expect(appUpdateItem, findsNothing);
      expect(
        tester.state<NavigatorState>(find.byType(Navigator).first).canPop(),
        isFalse,
      );

      await tester.pumpAndSettle();
      await settingsCubit.close();
      await machineManagerCubit.close();
      bridge.dispose();
    });
  });

  group('Settings macOS native app link', () {
    testWidgets('shows link when iOS app is running on Mac', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platformEnvironmentChannel, (call) async {
            if (call.method == 'isIOSAppOnMac') return true;
            return null;
          });
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsCubit = _SeededSettingsCubit(prefs, activeMachineId: null);
      final manager = MachineManagerService(prefs, _FakeSecureStorage());
      final machineManagerCubit = _createMachineManagerCubit(manager);
      final bridge = _FakeBridgeService(connected: false);

      await tester.pumpWidget(
        await _buildScreen(
          bridge: bridge,
          settingsCubit: settingsCubit,
          machineManagerCubit: machineManagerCubit,
        ),
      );
      await tester.pumpAndSettle();
      await _openCategory(tester, SettingsCategory.about);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('macos_native_app_settings_tile')),
        500,
        scrollable: find.byType(Scrollable).first,
      );

      expect(
        find.byKey(const ValueKey('macos_native_app_settings_tile')),
        findsOneWidget,
      );

      await settingsCubit.close();
      await machineManagerCubit.close();
      bridge.dispose();
    });

    testWidgets('hides link when not running as an iOS app on Mac', (
      tester,
    ) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platformEnvironmentChannel, (call) async {
            if (call.method == 'isIOSAppOnMac') return false;
            return null;
          });
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsCubit = _SeededSettingsCubit(prefs, activeMachineId: null);
      final manager = MachineManagerService(prefs, _FakeSecureStorage());
      final machineManagerCubit = _createMachineManagerCubit(manager);
      final bridge = _FakeBridgeService(connected: false);

      await tester.pumpWidget(
        await _buildScreen(
          bridge: bridge,
          settingsCubit: settingsCubit,
          machineManagerCubit: machineManagerCubit,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('macos_native_app_settings_tile')),
        findsNothing,
      );

      await settingsCubit.close();
      await machineManagerCubit.close();
      bridge.dispose();
    });
  });

  group('Settings git diff interaction mode', () {
    test('persists through SettingsCubit reload', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final firstCubit = SettingsCubit(prefs);

      expect(
        firstCubit.state.gitDiffInteractionMode,
        GitDiffInteractionMode.quickActions,
      );

      firstCubit.setGitDiffInteractionMode(GitDiffInteractionMode.scrollFirst);
      await firstCubit.close();

      final secondCubit = SettingsCubit(prefs);
      expect(
        secondCubit.state.gitDiffInteractionMode,
        GitDiffInteractionMode.scrollFirst,
      );
      expect(secondCubit.state.gitDiffFocusAutoLandscape, isFalse);

      secondCubit.setGitDiffFocusAutoLandscape(true);
      await secondCubit.close();

      final thirdCubit = SettingsCubit(prefs);
      expect(thirdCubit.state.gitDiffFocusAutoLandscape, isTrue);
      await thirdCubit.close();
    });

    testWidgets('shows mode selector in editor settings', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsCubit = _SeededSettingsCubit(prefs, activeMachineId: null);
      final manager = MachineManagerService(prefs, _FakeSecureStorage());
      final machineManagerCubit = _createMachineManagerCubit(manager);
      final bridge = _FakeBridgeService(connected: false);

      await tester.pumpWidget(
        await _buildScreen(
          bridge: bridge,
          settingsCubit: settingsCubit,
          machineManagerCubit: machineManagerCubit,
        ),
      );
      await tester.pumpAndSettle();
      await _openCategory(tester, SettingsCategory.git);
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));

      await tester.scrollUntilVisible(
        find.text(l.gitDiffInteractionMode),
        300,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.text(l.gitDiffInteractionMode), findsOneWidget);
      expect(find.text(l.gitDiffQuickActions), findsOneWidget);
      expect(find.text(l.gitDiffScrollFirst), findsOneWidget);

      await tester.tap(find.text(l.gitDiffScrollFirst));
      await tester.pumpAndSettle();

      expect(
        settingsCubit.state.gitDiffInteractionMode,
        GitDiffInteractionMode.scrollFirst,
      );

      final autoLandscapeToggle = find.byKey(
        const ValueKey('git_diff_focus_auto_landscape_toggle'),
      );
      await tester.ensureVisible(autoLandscapeToggle);
      await tester.pumpAndSettle();

      expect(find.text(l.gitDiffFocusAutoLandscape), findsOneWidget);
      expect(autoLandscapeToggle, findsOneWidget);

      await tester.tap(autoLandscapeToggle);
      await tester.pumpAndSettle();

      expect(settingsCubit.state.gitDiffFocusAutoLandscape, isTrue);

      await settingsCubit.close();
      await machineManagerCubit.close();
      bridge.dispose();
    });
  });

  group('Settings image paste shortcut', () {
    test('persists through SettingsCubit reload', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final firstCubit = SettingsCubit(prefs);

      expect(firstCubit.state.imagePasteShortcut, ImagePasteShortcut.ctrlV);

      firstCubit.setImagePasteShortcut(ImagePasteShortcut.commandV);
      await firstCubit.close();

      final secondCubit = SettingsCubit(prefs);
      expect(secondCubit.state.imagePasteShortcut, ImagePasteShortcut.commandV);
      await secondCubit.close();
    });
  });

  group('Settings direct gallery selection', () {
    test('defaults to attachment menu and persists enabled value', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final firstCubit = SettingsCubit(prefs);

      expect(firstCubit.state.openGalleryDirectly, isFalse);

      firstCubit.setOpenGalleryDirectly(true);
      await firstCubit.close();

      final secondCubit = SettingsCubit(prefs);
      expect(secondCubit.state.openGalleryDirectly, isTrue);
      await secondCubit.close();
    });

    testWidgets('toggle updates the setting', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsCubit = _SeededSettingsCubit(prefs, activeMachineId: null);
      final manager = MachineManagerService(prefs, _FakeSecureStorage());
      final machineManagerCubit = _createMachineManagerCubit(manager);
      final bridge = _FakeBridgeService(connected: false);

      await tester.pumpWidget(
        await _buildScreen(
          bridge: bridge,
          settingsCubit: settingsCubit,
          machineManagerCubit: machineManagerCubit,
        ),
      );
      await tester.pumpAndSettle();
      await _openCategory(tester, SettingsCategory.input);

      final toggle = find.byKey(const ValueKey('open_gallery_directly_toggle'));
      expect(toggle, findsOneWidget);
      expect(settingsCubit.state.openGalleryDirectly, isFalse);

      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(settingsCubit.state.openGalleryDirectly, isTrue);

      await settingsCubit.close();
      await machineManagerCubit.close();
      bridge.dispose();
    });
  });

  group('Settings categories', () {
    test('catalog keeps every setting that the old single list had', () {
      expect(settingsEntries.map((e) => e.id).toSet(), {
        'bridge_machine',
        'local_url',
        'bridge_update',
        'prompt_history',
        'push_notifications',
        'push_privacy',
        'notification_language',
        'usage',
        'theme',
        'language',
        'app_icon',
        'text_density',
        'multi_pane_breakpoint',
        'code_font',
        'indent_size',
        'voice_input',
        'hide_voice_input',
        'default_input_delivery',
        'skill_trigger_style',
        'open_gallery_directly',
        'image_paste_shortcut',
        'lite_mode',
        'enabled_agents',
        'new_session_tabs',
        'auto_rename_codex',
        'extended_codex_efforts',
        'auto_rename_claude',
        'show_hidden_directories',
        'show_bridge_name',
        'terminal_app',
        'git_diff_mode',
        'git_diff_auto_landscape',
        'remote_git_status_badge',
        'supporter',
        'rate_app',
        'share_app',
        'star_on_github',
        'version',
        'macos_native_app',
        'changelog',
        'setup_guide',
        'github_repository',
        'licenses',
      });
      expect(
        settingsEntries.map((e) => e.id).toSet().length,
        settingsEntries.length,
        reason: 'entry ids must be unique',
      );
    });

    test('search matches titles, categories and keywords', () async {
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      String title(SettingsCategory c) => c.name;
      List<String> ids(String query) => searchSettingsEntries(
        query: query,
        l: l,
        visibility: const SettingsVisibility(),
        categoryTitle: title,
      ).map((e) => e.id).toList();

      expect(ids('dark'), contains('theme'));
      expect(ids('ダーク'), contains('theme'));
      expect(ids('git landscape'), ['git_diff_auto_landscape']);
      expect(ids('   '), isEmpty);
      // Hidden rows are not searchable.
      expect(ids('notification'), isNot(contains('push_privacy')));
    });

    for (final connected in [false, true]) {
      testWidgets('every visible entry renders on its category page '
          '(connected: $connected)', (tester) async {
        tester.view.physicalSize = const Size(400, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final settingsCubit = _SeededSettingsCubit(
          prefs,
          activeMachineId: connected ? 'machine-1' : null,
        );
        final machineManagerService = _StaticMachineManagerService([
          if (connected)
            MachineWithStatus(
              machine: Machine(
                id: 'machine-1',
                name: 'Remote Mac',
                host: '100.64.0.1',
              ),
              status: MachineStatus.online,
              versionInfo: BridgeVersionInfo(version: recommendedBridgeVersion),
            ),
        ]);
        final machineManagerCubit = _createMachineManagerCubit(
          machineManagerService,
        );
        final bridge = _FakeBridgeService(
          connected: connected,
          fakeLastUrl: connected ? 'ws://100.64.0.1:8765' : null,
          // Cached usage keeps the usage page from waiting on a request.
          cachedUsage: const UsageResultMessage(providers: []),
        );

        await tester.pumpWidget(
          await _buildScreen(
            bridge: bridge,
            settingsCubit: settingsCubit,
            machineManagerCubit: machineManagerCubit,
          ),
        );
        await tester.pumpAndSettle();

        final homeContext = tester.element(find.byType(SettingsHome));
        final visibility = resolveSettingsVisibility(
          homeContext,
          state: settingsCubit.state,
          environment: const SettingsEnvironment(),
          catalog: homeContext.read<RevenueCatService>().catalogState.value,
        );
        final categories = visibleSettingsCategories(visibility);
        expect(categories.contains(SettingsCategory.connection), connected);
        expect(categories, isNot(contains(SettingsCategory.usage)));
        // Usage is part of the status card on the home instead.
        expect(
          find.byKey(const ValueKey('settings_item_usage')),
          connected ? findsOneWidget : findsNothing,
        );
        expect(categories, contains(SettingsCategory.appearance));

        for (final category in categories) {
          await _openCategory(tester, category);
          final expected = visibleSettingsEntries(
            category,
            visibility,
          ).map((e) => e.id).toSet();
          final rendered = tester
              .widgetList<SettingsItem>(find.byType(SettingsItem))
              .map((item) => item.id)
              .toSet();
          expect(rendered, expected, reason: 'category ${category.name}');
        }

        await settingsCubit.close();
        await machineManagerCubit.close();
        machineManagerService.dispose();
        bridge.dispose();
      });
    }

    testWidgets('search result opens its category and reveals the row', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsCubit = _SeededSettingsCubit(prefs, activeMachineId: null);
      final manager = MachineManagerService(prefs, _FakeSecureStorage());
      final machineManagerCubit = _createMachineManagerCubit(manager);
      final bridge = _FakeBridgeService(connected: false);

      await tester.pumpWidget(
        await _buildScreen(
          bridge: bridge,
          settingsCubit: settingsCubit,
          machineManagerCubit: machineManagerCubit,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('settings_search_field')),
        'zzzz-nothing',
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('settings_search_empty')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('settings_search_field')),
        'landscape',
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('settings_category_appearance')),
        findsNothing,
      );
      final result = find.byKey(
        const ValueKey('settings_search_result_git_diff_auto_landscape'),
      );
      expect(result, findsOneWidget);

      await tester.tap(result);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('settings_category_page_git')),
        findsOneWidget,
      );
      final toggle = find.byKey(
        const ValueKey('git_diff_focus_auto_landscape_toggle'),
      );
      expect(toggle, findsOneWidget);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(settingsCubit.state.gitDiffFocusAutoLandscape, isTrue);

      await settingsCubit.close();
      await machineManagerCubit.close();
      bridge.dispose();
    });

    testWidgets('theme picker updates the theme mode', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsCubit = _SeededSettingsCubit(prefs, activeMachineId: null);
      final manager = MachineManagerService(prefs, _FakeSecureStorage());
      final machineManagerCubit = _createMachineManagerCubit(manager);
      final bridge = _FakeBridgeService(connected: false);

      await tester.pumpWidget(
        await _buildScreen(
          bridge: bridge,
          settingsCubit: settingsCubit,
          machineManagerCubit: machineManagerCubit,
        ),
      );
      await tester.pumpAndSettle();
      await _openCategory(tester, SettingsCategory.appearance);

      await tester.tap(find.byKey(const ValueKey('theme_option_dark')));
      await tester.pumpAndSettle();
      expect(settingsCubit.state.themeMode, ThemeMode.dark);

      await settingsCubit.close();
      await machineManagerCubit.close();
      bridge.dispose();
    });

    testWidgets('wide layout shows the category list beside the detail', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsCubit = _SeededSettingsCubit(prefs, activeMachineId: null);
      final manager = MachineManagerService(prefs, _FakeSecureStorage());
      final machineManagerCubit = _createMachineManagerCubit(manager);
      final bridge = _FakeBridgeService(connected: false);

      await tester.pumpWidget(
        await _buildScreen(
          bridge: bridge,
          settingsCubit: settingsCubit,
          machineManagerCubit: machineManagerCubit,
        ),
      );
      await tester.pumpAndSettle();

      // Disconnected: the first visible category is selected by default.
      expect(
        find.byKey(const ValueKey('settings_detail_appearance')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('settings_category_git')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('settings_detail_git')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('settings_category_page_git')),
        findsNothing,
        reason: 'wide layout must not push a page',
      );
      expect(
        find.byKey(const ValueKey('settings_category_appearance')),
        findsOneWidget,
      );

      await settingsCubit.close();
      await machineManagerCubit.close();
      bridge.dispose();
    });

    testWidgets('focusConnection opens the connection category', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsCubit = _SeededSettingsCubit(
        prefs,
        activeMachineId: 'machine-1',
      );
      final machineManagerService = _StaticMachineManagerService([
        MachineWithStatus(
          machine: Machine(id: 'machine-1', name: 'Remote Mac', host: 'h'),
          status: MachineStatus.online,
          versionInfo: BridgeVersionInfo(version: recommendedBridgeVersion),
        ),
      ]);
      final machineManagerCubit = _createMachineManagerCubit(
        machineManagerService,
      );
      final bridge = _FakeBridgeService(
        connected: true,
        fakeLastUrl: 'ws://h:8765',
      );

      await tester.pumpWidget(
        await _buildScreen(
          bridge: bridge,
          settingsCubit: settingsCubit,
          machineManagerCubit: machineManagerCubit,
          focusConnection: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('settings_category_page_connection')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('settings_connection_section_card')),
        findsOneWidget,
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings_status_card')),
        findsOneWidget,
      );

      await settingsCubit.close();
      await machineManagerCubit.close();
      machineManagerService.dispose();
      bridge.dispose();
    });

    testWidgets('open category page goes blank when the machine disconnects', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsCubit = _SeededSettingsCubit(
        prefs,
        activeMachineId: 'machine-1',
      );
      final machineManagerService = _StaticMachineManagerService([
        MachineWithStatus(
          machine: Machine(id: 'machine-1', name: 'Remote Mac', host: 'h'),
          status: MachineStatus.online,
          versionInfo: BridgeVersionInfo(version: recommendedBridgeVersion),
        ),
      ]);
      final machineManagerCubit = _createMachineManagerCubit(
        machineManagerService,
      );
      final bridge = _FakeBridgeService(
        connected: true,
        fakeLastUrl: 'ws://h:8765',
      );

      await tester.pumpWidget(
        await _buildScreen(
          bridge: bridge,
          settingsCubit: settingsCubit,
          machineManagerCubit: machineManagerCubit,
        ),
      );
      await tester.pumpAndSettle();
      await _openCategory(tester, SettingsCategory.notifications);
      expect(
        find.byKey(const ValueKey('settings_item_push_notifications')),
        findsOneWidget,
      );

      settingsCubit.emit(settingsCubit.state.copyWith(activeMachineId: null));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('settings_item_push_notifications')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('settings_category_unavailable')),
        findsOneWidget,
      );

      await settingsCubit.close();
      await machineManagerCubit.close();
      machineManagerService.dispose();
      bridge.dispose();
    });

    testWidgets('status card fits a 320px screen at 1.5x text', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsCubit = _SeededSettingsCubit(
        prefs,
        activeMachineId: 'machine-1',
      );
      final machineManagerService = _StaticMachineManagerService([
        MachineWithStatus(
          machine: Machine(
            id: 'machine-1',
            name: 'A rather long machine name for testing',
            host: 'h',
            sshEnabled: true,
            sshUsername: 'k9i',
          ),
          status: MachineStatus.online,
          versionInfo: BridgeVersionInfo(
            version: olderThanRecommendedBridgeVersion,
          ),
        ),
      ]);
      final machineManagerCubit = _createMachineManagerCubit(
        machineManagerService,
      );
      final resetsAt = DateTime.now().add(const Duration(hours: 3));
      final bridge = _FakeBridgeService(
        connected: true,
        fakeLastUrl: 'ws://h:8765',
        cachedUsage: UsageResultMessage(
          providers: [
            UsageInfo(
              provider: 'claude',
              fiveHour: UsageWindow(
                utilization: 26,
                resetsAt: resetsAt.toIso8601String(),
              ),
              modelWindows: [
                UsageModelWindow(
                  label: 'Fable',
                  utilization: 28,
                  resetsAt: resetsAt.toIso8601String(),
                ),
              ],
            ),
            UsageInfo(
              provider: 'codex',
              sevenDay: UsageWindow(
                utilization: 66,
                resetsAt: resetsAt.toIso8601String(),
              ),
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        await _buildScreen(
          bridge: bridge,
          settingsCubit: settingsCubit,
          machineManagerCubit: machineManagerCubit,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('settings_item_usage')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('settings_status_update_button')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await settingsCubit.close();
      await machineManagerCubit.close();
      machineManagerService.dispose();
      bridge.dispose();
    });
  });
}
