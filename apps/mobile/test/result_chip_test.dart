import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/bubbles/result_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget subject({required bool showSuccessResultText}) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: ResultChip(
          message: const ResultMessage(
            subtype: 'success',
            result: 'Recovered final summary',
          ),
          showSuccessResultText: showSuccessResultText,
        ),
      ),
    );
  }

  testWidgets('successful result text stays hidden when assistant is present', (
    tester,
  ) async {
    await tester.pumpWidget(subject(showSuccessResultText: false));

    expect(find.text('Recovered final summary'), findsNothing);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets(
    'successful result text is available as a missing-answer fallback',
    (tester) async {
      await tester.pumpWidget(subject(showSuccessResultText: true));

      expect(find.text('Recovered final summary'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    },
  );
}
