import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit_example/main.dart';

void main() {
  testWidgets('streams a new reply into the chat', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      find.text('Reading a JSON file', findRichText: true),
      findsOneWidget,
    );

    await tester.tap(find.text('Ask'));
    // Two characters per frame: enough frames for the whole reply.
    for (var i = 0; i < sampleReply.length ~/ 2 + 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
    }
    // The list is reversed, so the end of the new reply is what is on screen.
    expect(
      find.textContaining('dart:convert docs', findRichText: true),
      findsWidgets,
    );
  });

  testWidgets('typesets the formulas of the reply', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byType(Math).first,
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byType(Math), findsWidgets);
    expect(tester.takeException(), isNull);
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
          clipboard =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );

    await tester.pumpWidget(const ExampleApp());
    await tester.pump();
    // The list is reversed: the last paragraph of the reply is on screen.
    final lastLine = find.textContaining(
      'dart:convert docs',
      findRichText: true,
    );
    final gesture = await tester.startGesture(
      tester.getTopLeft(lastLine) + const Offset(4, 8),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Copy'), findsOneWidget);
    await tester.tap(find.text('Copy'));
    await tester.pump();
    expect(clipboard, 'See');
  });
}
