import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit_example/main.dart';

void main() {
  testWidgets('renders the sample and streams it again', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('markdown_kit', findRichText: true), findsWidgets);

    await tester.tap(find.text('Stream'));
    // Long enough for the whole sample at six characters per frame.
    for (var i = 0; i < 400; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
    }
    expect(find.text('Hidden until opened.', findRichText: true), findsNothing);
    expect(
      find.textContaining('Footnotes are collected', findRichText: true),
      findsWidgets,
    );
  });

  testWidgets('a long-press offers Copy without any menu builder', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );

    await tester.pumpWidget(const ExampleApp());
    await tester.pump();
    final heading = find.text('Lists', findRichText: true).first;
    final gesture = await tester.startGesture(
      tester.getCenter(heading),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Copy'), findsOneWidget);
    await tester.tap(find.text('Copy'));
    await tester.pump();
    expect(clipboard, 'Lists');
  });
}
