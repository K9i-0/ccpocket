import 'package:ccpocket/features/session_list/widgets/machine_card.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/machine.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
  bool sshEnabled = true,
  String? sshUsername = 'k9i',
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
        onConnect: () {},
        onStart: () {},
        onEdit: () {},
        onDelete: () {},
        onUpdate: () {},
        onStop: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('MachineCard menu', () {
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
      await _pumpCard(tester, status: MachineStatus.offline, version: '1.46.0');

      await tester.tap(find.byKey(const ValueKey('machine_menu_m1')));
      await tester.pumpAndSettle();

      expect(find.text('Update Bridge'), findsNothing);

      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      await _pumpCard(tester, status: MachineStatus.online, version: '1.46.0');

      await tester.tap(find.byKey(const ValueKey('machine_menu_m1')));
      await tester.pumpAndSettle();

      expect(find.text('Update Bridge'), findsOneWidget);
    });
  });

  group('MachineCard primary action', () {
    testWidgets('shows update button for online old bridge with SSH', (
      tester,
    ) async {
      await _pumpCard(tester, status: MachineStatus.online, version: '1.46.0');

      expect(
        find.byKey(const ValueKey('machine_update_bridge_button')),
        findsOneWidget,
      );
      expect(find.text('Update'), findsOneWidget);
    });

    testWidgets(
      'hides update button for latest, offline, missing SSH, or unknown version',
      (tester) async {
        await _pumpCard(
          tester,
          status: MachineStatus.online,
          version: '1.47.1',
        );
        expect(
          find.byKey(const ValueKey('machine_update_bridge_button')),
          findsNothing,
        );

        await _pumpCard(
          tester,
          status: MachineStatus.offline,
          version: '1.46.0',
        );
        expect(
          find.byKey(const ValueKey('machine_update_bridge_button')),
          findsNothing,
        );

        await _pumpCard(
          tester,
          status: MachineStatus.online,
          version: '1.46.0',
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
  });
}
