import 'package:ccpocket/features/settings/widgets/bridge_update_status_tile.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/models/machine.dart';
import 'package:ccpocket/services/ssh_startup_service.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers/bridge_version_test_values.dart';

MachineWithStatus _machine({
  required bool ssh,
  String? managedBy,
  String? platform = 'darwin',
  String? version,
}) {
  return MachineWithStatus(
    machine: Machine(
      id: 'm1',
      name: 'Remote Mac',
      host: '100.64.0.1',
      sshEnabled: ssh,
      sshUsername: ssh ? 'k9i' : null,
    ),
    status: MachineStatus.online,
    versionInfo: BridgeVersionInfo(
      version: version ?? olderThanRecommendedBridgeVersion,
      platform: platform,
      managedBy: managedBy,
    ),
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    theme: AppTheme.lightTheme,
    home: Scaffold(body: child),
  );
}

void main() {
  group('BridgeVersionInfo.managedBy', () {
    test('is read from /version and absent on older Bridges', () {
      final desktop = BridgeVersionInfo.fromJson({
        'version': '1.0.0',
        'managedBy': 'desktop-app',
      });
      final old = BridgeVersionInfo.fromJson({'version': '1.0.0'});

      expect(desktop.isManagedByDesktopApp, isTrue);
      expect(old.managedBy, isNull);
      expect(old.isManagedByDesktopApp, isFalse);
    });
  });

  group('BridgeUpdateStatus', () {
    test('a desktop app Bridge is never updated over SSH', () {
      final withSsh = BridgeUpdateStatus.resolve(
        machineWithStatus: _machine(ssh: true, managedBy: 'desktop-app'),
      );
      final withoutSsh = BridgeUpdateStatus.resolve(
        machineWithStatus: _machine(ssh: false, managedBy: 'desktop-app'),
      );

      for (final status in [withSsh, withoutSsh]) {
        expect(status.updateFromDesktopApp, isTrue);
        expect(status.needsUpdate, isFalse);
        expect(status.canShowSetupHelp, isFalse);
      }
    });

    test('other Bridges keep the SSH update and the setup help', () {
      final withSsh = BridgeUpdateStatus.resolve(
        machineWithStatus: _machine(ssh: true, managedBy: 'other'),
      );
      final withoutSsh = BridgeUpdateStatus.resolve(
        machineWithStatus: _machine(ssh: false, managedBy: 'other'),
      );

      expect(withSsh.needsUpdate, isTrue);
      expect(withSsh.updateFromDesktopApp, isFalse);
      expect(withoutSsh.canShowSetupHelp, isTrue);
      expect(withoutSsh.setupMayNotApply, isFalse);
    });

    test('an unreported launcher may be the desktop app only on a Mac', () {
      final mac = BridgeUpdateStatus.resolve(
        machineWithStatus: _machine(ssh: false),
      );
      final linux = BridgeUpdateStatus.resolve(
        machineWithStatus: _machine(ssh: false, platform: 'linux'),
      );

      expect(mac.canShowSetupHelp, isTrue);
      expect(mac.setupMayNotApply, isTrue);
      expect(linux.setupMayNotApply, isFalse);
    });

    test('an up-to-date desktop app Bridge shows no update guidance', () {
      final status = BridgeUpdateStatus.resolve(
        machineWithStatus: _machine(
          ssh: false,
          managedBy: 'desktop-app',
          version: recommendedBridgeVersion,
        ),
      );

      expect(status.updateFromDesktopApp, isFalse);
      expect(status.isKnownUpToDate, isTrue);
    });
  });

  group('MachineWithStatus.canUpdateOverSsh', () {
    test('excludes a desktop app Bridge', () {
      expect(
        _machine(
          ssh: true,
          managedBy: 'desktop-app',
        ).canUpdateOverSsh(recommendedBridgeVersion),
        isFalse,
      );
      expect(
        _machine(ssh: true).canUpdateOverSsh(recommendedBridgeVersion),
        isTrue,
      );
      expect(
        _machine(ssh: false).canUpdateOverSsh(recommendedBridgeVersion),
        isFalse,
      );
    });
  });

  group('BridgeUpdateStatusTile', () {
    testWidgets('explains the desktop app restart instead of setup', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BridgeUpdateStatusTile(
            machineWithStatus: _machine(ssh: true, managedBy: 'desktop-app'),
            isUpdating: false,
            onUpdate: () {},
          ),
        ),
      );
      final l = AppLocalizations.of(
        tester.element(find.byType(BridgeUpdateStatusTile)),
      );

      expect(find.text(l.bridgeUpdateFromDesktopApp), findsOneWidget);
      expect(
        find.byKey(const ValueKey('settings_update_bridge_button')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey('settings_bridge_update_desktop_tile')),
      );
      await tester.pumpAndSettle();

      expect(find.text(l.bridgeUpdateDesktopTitle), findsOneWidget);
      expect(find.text(l.bridgeUpdateDesktopStepRestart), findsOneWidget);
      expect(find.text(l.bridgeUpdateDesktopNoSetup), findsOneWidget);
      expect(find.text(l.bridgeUpdateSetupCommand), findsNothing);
    });

    testWidgets('opens Bridge on this Mac when the Bridge is local', (
      tester,
    ) async {
      var opened = 0;
      await tester.pumpWidget(
        _wrap(
          BridgeUpdateStatusTile(
            machineWithStatus: _machine(ssh: false, managedBy: 'desktop-app'),
            isUpdating: false,
            onOpenLocalBridge: () => opened++,
          ),
        ),
      );
      final l = AppLocalizations.of(
        tester.element(find.byType(BridgeUpdateStatusTile)),
      );

      expect(find.text(l.bridgeUpdateRestartHere), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('settings_bridge_update_desktop_tile')),
      );
      await tester.pumpAndSettle();

      expect(opened, 1);
      expect(find.text(l.bridgeUpdateDesktopTitle), findsNothing);
    });

    testWidgets('warns in the setup sheet when the launcher is unknown', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BridgeUpdateStatusTile(
            machineWithStatus: _machine(ssh: false),
            isUpdating: false,
          ),
        ),
      );
      final l = AppLocalizations.of(
        tester.element(find.byType(BridgeUpdateStatusTile)),
      );

      await tester.tap(
        find.byKey(const ValueKey('settings_bridge_update_setup_tile')),
      );
      await tester.pumpAndSettle();

      expect(find.text(l.bridgeUpdateSetupCommand), findsOneWidget);
      expect(find.text(l.bridgeUpdateSetupDesktopNote), findsOneWidget);
    });

    testWidgets('keeps the setup sheet plain for a Linux Bridge', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BridgeUpdateStatusTile(
            machineWithStatus: _machine(ssh: false, platform: 'linux'),
            isUpdating: false,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('settings_bridge_update_setup_tile')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('bridge_update_sheet_note')),
        findsNothing,
      );
    });
  });

  group('SSH preflight', () {
    test('points to the desktop app when its launcher runs the Bridge', () {
      final preflight = SshStartupService.startPreflightCommandForTest;
      final desktopIndex = preflight.indexOf('com.k9i.ccpocket.bridge-agent');
      final setupIndex = preflight.indexOf(
        'Bridge auto-start setup is required',
      );

      expect(desktopIndex, isNonNegative);
      expect(desktopIndex, lessThan(setupIndex));
      expect(preflight, contains('Do not run the setup command'));
      // Only reads the launcher's state: the desktop app owns that service.
      expect(preflight, isNot(contains('kickstart')));
    });
  });
}
