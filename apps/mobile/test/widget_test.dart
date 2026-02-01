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

    // API key field
    expect(find.byKey(const ValueKey('api_key_field')), findsOneWidget);

    // Connect button
    expect(find.byKey(const ValueKey('connect_button')), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);

    // Connect to Bridge Server text
    expect(find.text('Connect to Bridge Server'), findsOneWidget);
  });
}
