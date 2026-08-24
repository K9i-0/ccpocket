import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/bubbles/streaming_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('coalesces rapid markdown updates and renders the latest text', (
    tester,
  ) async {
    var beforeTextUpdateCalls = 0;

    Future<void> pumpBubble(String text) {
      return tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: StreamingBubble(
            text: text,
            onBeforeTextUpdate: () => beforeTextUpdateCalls++,
          ),
        ),
      );
    }

    await pumpBubble('first');
    final initialStyle = tester
        .widget<MarkdownBody>(find.byType(MarkdownBody))
        .styleSheet;

    await pumpBubble('first second');
    var markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
    expect(markdown.data, 'first');
    expect(identical(markdown.styleSheet, initialStyle), isTrue);

    await tester.pump(const Duration(milliseconds: 12));
    await pumpBubble('first second latest');
    markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
    expect(markdown.data, 'first');
    expect(beforeTextUpdateCalls, 0);

    await tester.pump(const Duration(milliseconds: 20));
    markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
    expect(markdown.data, 'first second latest');
    expect(beforeTextUpdateCalls, 1);
  });

  testWidgets('renders a large delta immediately', (tester) async {
    final largeDelta = List.filled(128, 'x').join();

    Future<void> pumpBubble(String text) {
      return tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: StreamingBubble(text: text),
        ),
      );
    }

    await pumpBubble('first');
    await pumpBubble('first$largeDelta');

    final markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
    expect(markdown.data, 'first$largeDelta');
  });

  testWidgets('cancels a pending markdown update when disposed', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const StreamingBubble(text: 'first'),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const StreamingBubble(text: 'second'),
      ),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 32));

    expect(tester.takeException(), isNull);
  });
}
