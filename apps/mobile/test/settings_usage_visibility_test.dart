import 'dart:async';

import 'package:ccpocket/features/settings/settings_screen.dart';
import 'package:ccpocket/features/settings/state/settings_cubit.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/providers/machine_manager_cubit.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/services/database_service.dart';
import 'package:ccpocket/services/machine_manager_service.dart';
import 'package:ccpocket/services/revenuecat_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBridgeService extends BridgeService {
  final _connectionController =
      StreamController<BridgeConnectionState>.broadcast();
  final _usageController = StreamController<UsageResultMessage>.broadcast();
  final bool connected;
  final UsageResultMessage? cachedUsage;
  final String? fakeLastUrl;

  _FakeBridgeService({
    required this.connected,
    this.cachedUsage,
    this.fakeLastUrl,
  });

  @override
  bool get isConnected => connected;

  @override
  String? get lastUrl => fakeLastUrl;

  @override
  Stream<BridgeConnectionState> get connectionStatus =>
      _connectionController.stream;

  @override
  Stream<UsageResultMessage> get usageResults => _usageController.stream;

  @override
  UsageResultMessage? get lastUsageResult => cachedUsage;

  @override
  void requestUsage() {}

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

Future<Widget> _buildScreen({
  required BridgeService bridge,
  required SettingsCubit settingsCubit,
  required MachineManagerCubit machineManagerCubit,
  RevenueCatService? revenueCatService,
  bool focusSupport = false,
}) async {
  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<BridgeService>.value(value: bridge),
      RepositoryProvider<RevenueCatService>.value(
        value: revenueCatService ?? RevenueCatService(),
      ),
      RepositoryProvider<DatabaseService>.value(value: DatabaseService()),
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
        home: SettingsScreen(focusSupport: focusSupport),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'CC Pocket',
      packageName: 'dev.test.ccpocket',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  group('Settings usage visibility', () {
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
        final machineManagerCubit = MachineManagerCubit(manager, null);
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
        expect(find.byKey(const ValueKey('codex_usage_card')), findsNothing);
        expect(find.byKey(const ValueKey('app_icon_tile')), findsOneWidget);

        await settingsCubit.close();
        await machineManagerCubit.close();
        bridge.dispose();
      },
    );

    testWidgets('shows usage section when connected', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsCubit = _SeededSettingsCubit(
        prefs,
        activeMachineId: 'machine-1',
      );
      final manager = MachineManagerService(prefs, _FakeSecureStorage());
      final machineManagerCubit = MachineManagerCubit(manager, null);
      final bridge = _FakeBridgeService(
        connected: true,
        fakeLastUrl: 'ws://127.0.0.1:8765',
        cachedUsage: const UsageResultMessage(
          providers: [
            UsageInfo(
              provider: 'codex',
              fiveHour: UsageWindow(
                utilization: 0.08,
                resetsAt: '2026-04-12T10:19:42Z',
              ),
              sevenDay: UsageWindow(
                utilization: 0.09,
                resetsAt: '2026-04-17T00:19:19Z',
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

      expect(find.byKey(const ValueKey('app_icon_tile')), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('codex_usage_card')),
        300,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.text(l.settingsUsageSectionTitle), findsOneWidget);
      expect(find.byKey(const ValueKey('codex_usage_card')), findsOneWidget);

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
      final machineManagerCubit = MachineManagerCubit(manager, null);
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

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
}
