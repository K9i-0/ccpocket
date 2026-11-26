/// The code shown in README.md, compiled and pumped, so the documentation
/// cannot drift from the API.
library;

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';

class Reply extends StatelessWidget {
  const Reply({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return MarkdownView(
      data: text,
      builders: MarkdownBuilders(
        onLinkTap: (url, title) {
          // Open the link.
        },
      ),
    );
  }
}

class _Message {
  const _Message(this.id, this.text, {this.isStreaming = false});
  final String id;
  final String text;
  final bool isStreaming;
}

Widget _host(Widget child) => Directionality(
  textDirection: ui.TextDirection.ltr,
  child: MediaQuery(
    data: const MediaQueryData(size: Size(400, 600)),
    child: Overlay(initialEntries: [OverlayEntry(builder: (_) => child)]),
  ),
);

void main() {
  testWidgets('basic usage and streaming', (tester) async {
    await tester.pumpWidget(_host(const Reply(text: 'Hello **world**')));
    expect(find.textContaining('Hello', findRichText: true), findsOneWidget);

    const received = '```dart\nvoid main() {}\n``';
    const done = false;
    await tester.pumpWidget(
      _host(const MarkdownView(data: received, isStreaming: !done)),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a chat screen', (tester) async {
    const messages = [
      _Message('a', 'First'),
      _Message('b', 'Second **and more', isStreaming: true),
    ];
    final controller = MarkdownSelectionController(
      // A chat usually wants a selection to stay inside one message.
      allowCrossDocumentSelection: false,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        MarkdownSelectionScope(
          controller: controller,
          child: ListView.builder(
            reverse: true,
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[messages.length - 1 - index];
              return MarkdownView(
                data: message.text,
                // Only the block still being written is re-parsed and rebuilt.
                isStreaming: message.isStreaming,
                // A stable id lets the selection survive the item scrolling
                // away and the switch from streaming to finished.
                documentId: message.id,
                documentOrder: index,
                builders: MarkdownBuilders(
                  onLinkTap: (url, title) {
                    // Open the link.
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
    expect(controller.selectAll(documentId: 'a'), isTrue);
    expect(controller.getText(), 'First');
    // The unfinished bold is held while the reply streams.
    expect(controller.selectAll(documentId: 'b'), isTrue);
    expect(controller.getText(), 'Second');
  });

  testWidgets('theme and parser options', (tester) async {
    await tester.pumpWidget(
      _host(
        MarkdownTheme(
          data: MarkdownThemeData.dark().copyWith(
            bodyStyle: const TextStyle(fontSize: 16, height: 1.5),
          ),
          child: const MarkdownView(
            data: r'Costs $5, or $x^2$ as math.',
            parserOptions: MarkdownParserOptions(enableDollarLatex: true),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
