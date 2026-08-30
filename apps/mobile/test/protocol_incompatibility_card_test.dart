import 'package:ccpocket/features/session_list/widgets/protocol_incompatibility_card.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/protocol_version.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget testApp(ProtocolCompatibility compatibility) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ProtocolIncompatibilityCard(compatibility: compatibility),
    ),
  );
}

void main() {
  testWidgets('tells the user to update the App for a newer Bridge protocol', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        ProtocolCompatibility.forBridge(
          minimumProtocolVersion: 2,
          protocolVersion: 2,
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('protocol_incompatibility_card')),
      findsOne,
    );
    expect(find.textContaining('Update CC Pocket'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('copy_bridge_update_command_button')),
      findsNothing,
    );
  });

  testWidgets('shows the pinned Bridge command for malformed declarations', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        ProtocolCompatibility.fromBridgeJson({'minimumProtocolVersion': 1}),
      ),
    );

    expect(find.text(bridgeStableMajorSetupCommand), findsOneWidget);
    expect(
      find.byKey(const ValueKey('copy_bridge_update_command_button')),
      findsOneWidget,
    );
  });
}
