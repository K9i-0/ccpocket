import 'package:ccpocket/features/session_list/widgets/bridge_auth_required_card.dart';
import 'package:ccpocket/features/session_list/widgets/machine_card.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/models/machine.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/models/protocol_version.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.lightTheme,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

const _rejection = BridgeAuthRejection(host: '192.168.1.20', port: 8765);

void main() {
  group('BridgeAuthRequiredCard', () {
    testWidgets('explains the rejection and shows the qr command', (
      tester,
    ) async {
      var scanned = 0;
      var entered = 0;
      await tester.pumpWidget(
        _wrap(
          BridgeAuthRequiredCard(
            rejection: _rejection,
            onScanQrCode: () => scanned++,
            onEnterApiKey: () => entered++,
          ),
        ),
      );

      expect(find.text('Bridge authentication required'), findsOneWidget);
      expect(find.textContaining('192.168.1.20:8765'), findsOneWidget);
      expect(find.text(bridgeStableMajorQrCommand), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('bridge_auth_scan_qr_button')),
      );
      await tester.tap(
        find.byKey(const ValueKey('bridge_auth_enter_api_key_button')),
      );
      expect(scanned, 1);
      expect(entered, 1);
    });

    testWidgets('hides actions that are unavailable', (tester) async {
      await tester.pumpWidget(
        _wrap(const BridgeAuthRequiredCard(rejection: _rejection)),
      );

      expect(
        find.byKey(const ValueKey('bridge_auth_scan_qr_button')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('bridge_auth_enter_api_key_button')),
        findsNothing,
      );
    });
  });

  group('MachineCard api key hint', () {
    Future<void> pump(
      WidgetTester tester, {
      required bool authRequired,
      required bool hasApiKey,
    }) {
      return tester.pumpWidget(
        _wrap(
          MachineCard(
            machineWithStatus: MachineWithStatus(
              machine: Machine(
                id: 'm1',
                host: '192.168.1.20',
                hasApiKey: hasApiKey,
              ),
              status: MachineStatus.online,
              authRequired: authRequired,
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
    }

    testWidgets('shows when the bridge requires a key the app lacks', (
      tester,
    ) async {
      await pump(tester, authRequired: true, hasApiKey: false);
      expect(
        find.byKey(const ValueKey('machine_api_key_required')),
        findsOneWidget,
      );
    });

    testWidgets('stays hidden when a key is stored or not required', (
      tester,
    ) async {
      await pump(tester, authRequired: true, hasApiKey: true);
      expect(
        find.byKey(const ValueKey('machine_api_key_required')),
        findsNothing,
      );

      await pump(tester, authRequired: false, hasApiKey: false);
      expect(
        find.byKey(const ValueKey('machine_api_key_required')),
        findsNothing,
      );
    });
  });
}
