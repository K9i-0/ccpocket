import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/bubbles/tool_result_bubble.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

ToolResultMessage _msg({
  String content = 'line1\nline2\nline3',
  String? toolName = 'Read',
  List<ImageRef> images = const [],
}) {
  return ToolResultMessage(
    toolUseId: 'test-tool-1',
    content: content,
    toolName: toolName,
    images: images,
  );
}

void main() {
  group('ToolResultBubble - collapsed state', () {
    testWidgets('collapsed shows no background container', (tester) async {
      await tester.pumpWidget(_wrap(ToolResultBubble(message: _msg())));

      // Collapsed: should show tool name and chevron_right
      expect(find.text('Read'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      // Should NOT show expand_more or expand_less
      expect(find.byIcon(Icons.expand_more), findsNothing);
      expect(find.byIcon(Icons.expand_less), findsNothing);

      // The colored dot should be present (6x6 circle container)
      final dotFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final deco = w.decoration as BoxDecoration;
          return deco.shape == BoxShape.circle;
        }
        return false;
      });
      expect(dotFinder, findsOneWidget);

      // No card-style background container with toolResultBackground
      // (The only Container with BoxDecoration should be the dot)
      final cardFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final deco = w.decoration as BoxDecoration;
          return deco.borderRadius != null && deco.color != null;
        }
        return false;
      });
      // Only the dot has a decoration — no card
      expect(cardFinder, findsNothing);
    });

    testWidgets('collapsed shows summary as plain text', (tester) async {
      await tester.pumpWidget(_wrap(ToolResultBubble(message: _msg())));

      // Summary should be "3 lines"
      expect(find.text('3 lines'), findsOneWidget);
    });

    testWidgets('collapsed hides images', (tester) async {
      final msg = ToolResultMessage(
        toolUseId: 'test-img',
        content: 'some content',
        toolName: 'Read',
        images: [
          const ImageRef(
            id: 'img-1',
            url: '/images/test.png',
            mimeType: 'image/png',
          ),
        ],
      );

      await tester.pumpWidget(
        _wrap(ToolResultBubble(message: msg, httpBaseUrl: 'http://localhost')),
      );

      // In collapsed state, no ImagePreviewWidget should render
      // (Image.network won't be present)
      expect(find.byType(Image), findsNothing);
    });
  });

  group('ToolResultBubble - expansion cycle', () {
    testWidgets('tap cycles collapsed → preview → expanded → collapsed', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ToolResultBubble(
            message: _msg(
              content: 'line1\nline2\nline3\nline4\nline5\nline6\nline7\nline8',
            ),
          ),
        ),
      );

      // Initially collapsed — chevron_right
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      // Tap → preview
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(find.textContaining('more lines'), findsOneWidget);

      // Tap → expanded
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.expand_less), findsOneWidget);

      // Tap → back to collapsed
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('preview shows card background', (tester) async {
      await tester.pumpWidget(_wrap(ToolResultBubble(message: _msg())));

      // Tap to enter preview
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      // Card background should now exist
      final cardFinder = find.byWidgetPredicate((w) {
        if (w is Container && w.decoration is BoxDecoration) {
          final deco = w.decoration as BoxDecoration;
          return deco.borderRadius != null && deco.color != null;
        }
        return false;
      });
      expect(cardFinder, findsOneWidget);
    });
  });

  group('ToolResultBubble - long press copy', () {
    testWidgets('long press copies content to clipboard', (tester) async {
      // Set up clipboard mock
      String? clipboardContent;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            final args = methodCall.arguments as Map;
            clipboardContent = args['text'] as String?;
          }
          return null;
        },
      );

      await tester.pumpWidget(
        _wrap(ToolResultBubble(message: _msg(content: 'test content'))),
      );

      // Long press on collapsed row
      await tester.longPress(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      expect(clipboardContent, 'test content');
      expect(find.text('Copied to clipboard'), findsOneWidget);
    });
  });

  group('ToolResultBubble - collapseNotifier', () {
    testWidgets('auto-collapses when notifier fires', (tester) async {
      final notifier = ValueNotifier<int>(0);

      await tester.pumpWidget(
        _wrap(ToolResultBubble(message: _msg(), collapseNotifier: notifier)),
      );

      // Expand to preview
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.expand_more), findsOneWidget);

      // Fire notifier
      notifier.value++;
      await tester.pumpAndSettle();

      // Should be collapsed again
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });
  });

  group('ToolResultBubble - summary formatting', () {
    testWidgets('Edit tool shows +/-  summary', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ToolResultBubble(
            message: _msg(
              toolName: 'Edit',
              content: '--- a/file\n+++ b/file\n+added\n-removed\n+added2',
            ),
          ),
        ),
      );

      expect(find.text('+2/-1 lines'), findsOneWidget);
    });

    testWidgets('short single line shows content as summary', (tester) async {
      await tester.pumpWidget(
        _wrap(ToolResultBubble(message: _msg(content: 'OK'))),
      );

      expect(find.text('OK'), findsOneWidget);
    });
  });
}
