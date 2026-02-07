import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/widgets/bubbles/tool_use_summary_bubble.dart';
import 'package:ccpocket/theme/app_theme.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  group('ToolUseSummaryBubble', () {
    testWidgets('displays summary text', (tester) async {
      await tester.pumpWidget(
        wrap(
          const ToolUseSummaryBubble(
            message: ToolUseSummaryMessage(
              summary: 'Read 3 files and fixed type errors',
              precedingToolUseIds: ['tu-1', 'tu-2', 'tu-3'],
            ),
          ),
        ),
      );

      expect(find.text('Read 3 files and fixed type errors'), findsOneWidget);
    });

    testWidgets('displays subagent icon', (tester) async {
      await tester.pumpWidget(
        wrap(
          const ToolUseSummaryBubble(
            message: ToolUseSummaryMessage(
              summary: 'Analyzed codebase',
              precedingToolUseIds: [],
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
    });

    testWidgets('handles long summary text', (tester) async {
      await tester.pumpWidget(
        wrap(
          const ToolUseSummaryBubble(
            message: ToolUseSummaryMessage(
              summary:
                  'Read package.json, analyzed 15 source files, fixed 3 TypeScript errors, updated 2 test files, and committed changes',
              precedingToolUseIds: ['tu-1', 'tu-2', 'tu-3', 'tu-4', 'tu-5'],
            ),
          ),
        ),
      );

      expect(find.textContaining('Read package.json'), findsOneWidget);
    });
  });
}
