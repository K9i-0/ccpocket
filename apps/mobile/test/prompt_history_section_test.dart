import 'package:ccpocket/features/settings/widgets/prompt_history_section.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/services/database_service.dart';
import 'package:ccpocket/services/machine_manager_service.dart';
import 'package:ccpocket/services/prompt_history_service.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'shows migration card only for legacy history on supported Bridge',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final machineManager = MachineManagerService(
        prefs,
        const FlutterSecureStorage(),
      );

      await tester.pumpWidget(
        _app(
          bridge: _FakeBridgeService(
            connected: true,
            promptHistoryBridgeId: 'bridge-1',
          ),
          service: _FakePromptHistoryService(hasLegacyHistory: true),
          machineManager: machineManager,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('prompt_history_migration_tile')),
        findsOneWidget,
      );
    },
  );

  testWidgets('hides migration card when there is no legacy history', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      _app(
        bridge: _FakeBridgeService(
          connected: true,
          promptHistoryBridgeId: 'bridge-1',
        ),
        service: _FakePromptHistoryService(hasLegacyHistory: false),
        machineManager: MachineManagerService(
          prefs,
          const FlutterSecureStorage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('prompt_history_migration_tile')),
      findsNothing,
    );
  });

  testWidgets(
    'hides migration card when Bridge does not support prompt history',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        _app(
          bridge: _FakeBridgeService(connected: true),
          service: _FakePromptHistoryService(hasLegacyHistory: true),
          machineManager: MachineManagerService(
            prefs,
            const FlutterSecureStorage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('prompt_history_migration_tile')),
        findsNothing,
      );
    },
  );

  testWidgets('dismisses migration card permanently', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = _FakePromptHistoryService(hasLegacyHistory: true);

    await tester.pumpWidget(
      _app(
        bridge: _FakeBridgeService(
          connected: true,
          promptHistoryBridgeId: 'bridge-1',
        ),
        service: service,
        machineManager: MachineManagerService(
          prefs,
          const FlutterSecureStorage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('prompt_history_migration_dismiss_button')),
    );
    await tester.pumpAndSettle();

    expect(service.legacyMigrationDismissed, isTrue);
    expect(
      find.byKey(const ValueKey('prompt_history_migration_tile')),
      findsNothing,
    );
  });

  testWidgets('shows registered machine names for synced Bridge status', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final machineManager = MachineManagerService(
      prefs,
      const FlutterSecureStorage(),
    );
    await machineManager.recordConnection(
      host: 'mini.tailnet.ts.net',
      port: 8765,
    );
    await machineManager.recordConnection(
      host: '127.0.0.1',
      port: 8765,
      name: 'mini',
    );

    await tester.pumpWidget(
      _app(
        bridge: _FakeBridgeService(
          connected: true,
          promptHistoryBridgeId: 'cfbddf14-4245-44b5-b783-60576b8c1121',
        ),
        service: _FakePromptHistoryService(
          hasLegacyHistory: false,
          statuses: [
            PromptHistorySyncStatus(
              bridgeId: 'cfbddf14-4245-44b5-b783-60576b8c1121',
              bridgeUrl: 'ws://127.0.0.1:8765',
              bridgeName: 'cfbddf14-4245-44b5-b783-60576b8c1121',
              lastSyncAt: DateTime.utc(2026, 5, 1, 12, 56),
              revision: 1,
              entryCount: 298,
            ),
            PromptHistorySyncStatus(
              bridgeId: 'mini.tailnet.ts.net:8765',
              bridgeUrl: 'ws://mini.tailnet.ts.net:8765',
              bridgeName: 'mini.tailnet.ts.net:8765',
              lastSyncAt: DateTime.utc(2026, 5, 1, 11),
              revision: 1,
              entryCount: 298,
            ),
          ],
          bridgeAliases: const {
            '127.0.0.1:8765': 'cfbddf14-4245-44b5-b783-60576b8c1121',
            'mini.tailnet.ts.net:8765': 'cfbddf14-4245-44b5-b783-60576b8c1121',
          },
        ),
        machineManager: machineManager,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Synced Bridges: 1'), findsOneWidget);
    expect(find.text('mini / 127.0.0.1:8765'), findsOneWidget);
    expect(find.textContaining('Bridge ID: cfbddf14...1121'), findsOneWidget);
    expect(
      find.textContaining('Other registrations: mini.tailnet.ts.net:8765'),
      findsOneWidget,
    );
    expect(find.text('298'), findsOneWidget);
  });
}

Widget _app({
  required BridgeService bridge,
  required PromptHistoryService service,
  required MachineManagerService machineManager,
}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: PromptHistorySection(
          bridgeService: bridge,
          promptHistoryService: service,
          machineManagerService: machineManager,
        ),
      ),
    ),
  );
}

class _FakeBridgeService extends BridgeService {
  final bool connected;
  final String? fakePromptHistoryBridgeId;

  _FakeBridgeService({required this.connected, String? promptHistoryBridgeId})
    : fakePromptHistoryBridgeId = promptHistoryBridgeId;

  @override
  bool get isConnected => connected;

  @override
  String? get promptHistoryBridgeId => fakePromptHistoryBridgeId;
}

class _FakePromptHistoryService extends PromptHistoryService {
  final bool legacyHistory;
  final List<PromptHistorySyncStatus> statuses;
  final Map<String, String> bridgeAliases;
  bool legacyMigrationDismissed = false;

  _FakePromptHistoryService({
    required bool hasLegacyHistory,
    this.statuses = const [],
    this.bridgeAliases = const {},
  }) : legacyHistory = hasLegacyHistory,
       super(DatabaseService());

  @override
  Future<List<PromptHistorySyncStatus>> getSyncStatuses() async => statuses;

  @override
  Future<Map<String, String>> getBridgeAliasMap() async => bridgeAliases;

  @override
  Future<bool> hasLegacyHistory() async => legacyHistory;

  @override
  Future<bool> isLegacyMigrationDismissed() async => legacyMigrationDismissed;

  @override
  Future<void> setLegacyMigrationDismissed(bool value) async {
    legacyMigrationDismissed = value;
  }

  @override
  Future<PromptHistoryFilters> getDefaultFilters() async =>
      const PromptHistoryFilters();

  @override
  Future<void> setDefaultFilters(PromptHistoryFilters filters) async {}

  @override
  Future<List<PromptHistorySyncStatus>> syncAll({
    MachineManagerService? machineManager,
    BridgeService? bridgeService,
  }) async => statuses;

  @override
  Future<bool> importLegacyToCurrentBridge({
    required BridgeService bridgeService,
  }) async => true;
}
