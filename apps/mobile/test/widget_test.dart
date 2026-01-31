import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/main.dart';

void main() {
  testWidgets('Initial screen shows connect UI', (WidgetTester tester) async {
    await tester.pumpWidget(const CcpocketApp());

    // App title
    expect(find.text('ccpocket'), findsOneWidget);

    // Server URL field
    expect(find.byKey(const ValueKey('server_url_field')), findsOneWidget);

    // Connect button
    expect(find.byKey(const ValueKey('connect_button')), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);

    // Message input should NOT be visible (not connected)
    expect(find.byKey(const ValueKey('message_input')), findsNothing);

    // Send button should NOT be visible
    expect(find.byKey(const ValueKey('send_button')), findsNothing);
  });

  testWidgets('Status indicator shows idle by default',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CcpocketApp());

    expect(find.byKey(const ValueKey('status_indicator')), findsOneWidget);
    expect(find.text('Idle'), findsOneWidget);
  });
}
