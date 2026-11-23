import 'package:ccpocket/features/session_list/widgets/bridge_auth_required_card.dart';
import 'package:ccpocket/features/session_list/widgets/connect_form.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<void> pumpForm(
  WidgetTester tester, {
  required bool showLocalBridge,
  BridgeAuthRejection? rejection,
}) => tester.pumpWidget(
  MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ConnectForm(
        onScanQrCode: () {},
        showLocalBridge: showLocalBridge,
        authRejection: rejection,
      ),
    ),
  ),
);

Finder key(String value) => find.byKey(ValueKey(value));

void main() {
  testWidgets('the connect form offers the Bridge on this Mac', (tester) async {
    await pumpForm(tester, showLocalBridge: true);
    expect(key('connect_local_bridge_button'), findsOneWidget);
    expect(find.text('Bridge on this Mac'), findsOneWidget);

    await pumpForm(tester, showLocalBridge: false);
    expect(key('connect_local_bridge_button'), findsNothing);
  });

  testWidgets('a rejected local Bridge points to its management screen', (
    tester,
  ) async {
    await pumpForm(
      tester,
      showLocalBridge: true,
      rejection: const BridgeAuthRejection(host: 'localhost', port: 8765),
    );
    expect(key('bridge_auth_open_local_bridge_button'), findsOneWidget);
    expect(key('copy_bridge_qr_command_button'), findsNothing);
    expect(find.textContaining('management screen'), findsOneWidget);
  });

  testWidgets('a rejected remote Bridge keeps the terminal command', (
    tester,
  ) async {
    await pumpForm(
      tester,
      showLocalBridge: true,
      rejection: const BridgeAuthRejection(host: '100.64.0.1', port: 8765),
    );
    expect(key('bridge_auth_open_local_bridge_button'), findsNothing);
    expect(key('copy_bridge_qr_command_button'), findsOneWidget);
    expect(find.byType(BridgeAuthRequiredCard), findsOneWidget);
  });
}
