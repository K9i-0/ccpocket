import 'package:ccpocket/features/session_list/widgets/machine_card.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/machine.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/bridge_version_test_values.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    theme: AppTheme.lightTheme,
    home: Scaffold(body: child),
  );
}

Machine _machine({bool sshEnabled = true, String? sshUsername = 'k9i'}) {
  return Machine(
    id: 'm1',
    name: 'Remote Mac',
    host: '100.64.0.1',
    sshEnabled: sshEnabled,
    sshUsername: sshUsername,
    hasCredentials: sshEnabled && sshUsername != null,
  );
}

Future<void> _pumpCard(
  WidgetTester tester, {
  required MachineStatus status,
  String? version,
  String? latestBridgeVersion,
  bool sshEnabled = true,
  String? sshUsername = 'k9i',
  VoidCallback? onConnect,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
}) async {
  await tester.pumpWidget(
    _wrap(
      MachineCard(
        machineWithStatus: MachineWithStatus(
          machine: _machine(sshEnabled: sshEnabled, sshUsername: sshUsername),
          status: status,
          versionInfo: version == null
              ? null
              : BridgeVersionInfo(version: version),
        ),
        onConnect: onConnect ?? () {},
        onStart: () {},
        onEdit: onEdit ?? () {},
        onDelete: onDelete ?? () {},
        onUpdate: () {},
        onStop: () {},
        latestBridgeVersion: latestBridgeVersion,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('MachineCard menu', () {
    testWidgets('uses a full touch target and routes edit and delete taps', (
      tester,
    ) async {
      var connectCount = 0;
      var editCount = 0;
      var deleteCount = 0;
      await _pumpCard(
        tester,
        status: MachineStatus.online,
        onConnect: () => connectCount++,
        onEdit: () => editCount++,
        onDelete: () => deleteCount++,
      );

      final menuButton = find.byKey(const ValueKey('machine_menu_m1'));
      expect(
        tester.getSize(menuButton),
        const Size.square(kMinInteractiveDimension),
      );

      await tester.tap(menuButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(editCount, 1);
      expect(connectCount, 0);

      await tester.tap(menuButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(deleteCount, 1);
      expect(connectCount, 0);
    });

    testWidgets('shows stop server only while bridge is online', (
      tester,
    ) async {
      await _pumpCard(tester, status: MachineStatus.offline);

      await tester.tap(find.byKey(const ValueKey('machine_menu_m1')));
      await tester.pumpAndSettle();

      expect(find.text('Stop Server'), findsNothing);

      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      await _pumpCard(tester, status: MachineStatus.online);

      await tester.tap(find.byKey(const ValueKey('machine_menu_m1')));
      await tester.pumpAndSettle();

      expect(find.text('Stop Server'), findsOneWidget);
    });

    testWidgets('shows update menu only for online old bridge with SSH', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        status: MachineStatus.offline,
        version: olderThanRecommendedBridgeVersion,
      );

      await tester.tap(find.byKey(const ValueKey('machine_menu_m1')));
      await tester.pumpAndSettle();

      expect(find.text('Update Bridge'), findsNothing);

      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      await _pumpCard(
        tester,
        status: MachineStatus.online,
        version: olderThanRecommendedBridgeVersion,
      );

      await tester.tap(find.byKey(const ValueKey('machine_menu_m1')));
      await tester.pumpAndSettle();

      expect(find.text('Update Bridge'), findsOneWidget);
    });
  });

  group('MachineCard primary action', () {
    testWidgets('keeps connect button for online old bridge with SSH', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        status: MachineStatus.online,
        version: olderThanRecommendedBridgeVersion,
      );

      expect(
        find.byKey(const ValueKey('machine_update_bridge_button')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('machine_connect_button')),
        findsOneWidget,
      );
      expect(find.text('Connect'), findsOneWidget);
    });

    testWidgets(
      'hides update button for recommended, offline, missing SSH, or unknown version',
      (tester) async {
        await _pumpCard(
          tester,
          status: MachineStatus.online,
          version: recommendedBridgeVersion,
        );
        expect(
          find.byKey(const ValueKey('machine_update_bridge_button')),
          findsNothing,
        );

        await _pumpCard(
          tester,
          status: MachineStatus.offline,
          version: olderThanRecommendedBridgeVersion,
        );
        expect(
          find.byKey(const ValueKey('machine_update_bridge_button')),
          findsNothing,
        );

        await _pumpCard(
          tester,
          status: MachineStatus.online,
          version: olderThanRecommendedBridgeVersion,
          sshEnabled: false,
          sshUsername: null,
        );
        expect(
          find.byKey(const ValueKey('machine_update_bridge_button')),
          findsNothing,
        );

        await _pumpCard(tester, status: MachineStatus.online);
        expect(
          find.byKey(const ValueKey('machine_update_bridge_button')),
          findsNothing,
        );
      },
    );

    testWidgets('uses latest bridge version for update metadata', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        status: MachineStatus.online,
        version: recommendedBridgeVersion,
        latestBridgeVersion: newerThanRecommendedBridgeVersion,
      );

      await tester.tap(find.byKey(const ValueKey('machine_menu_m1')));
      await tester.pumpAndSettle();

      expect(find.text('Update Bridge'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('machine_connect_button')),
        findsOneWidget,
      );
    });
  });
}
