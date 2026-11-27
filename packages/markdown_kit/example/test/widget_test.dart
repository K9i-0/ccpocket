import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';
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

  testWidgets('toggles Hold syntax and streams presets in chat', (
    tester,
  ) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('chat-speed-fast')));
    await tester.tap(find.byKey(const ValueKey('chat-hold-syntax')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('chat-preset-streaming')));
    await tester.pump(const Duration(milliseconds: 32));
    expect(find.text('Streaming · raw mode (Hold syntax off)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chat-hold-syntax')));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('Streaming · holding unfinished syntax'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chat-stop')));
    await tester.pump();
    expect(find.byKey(const ValueKey('chat-reset')), findsOneWidget);
    expect(tester.takeException(), isNull);
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
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
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

    expect(find.text('Copy'), findsWidgets);
    // Tap the overlay context menu Copy button (distinct from the status bar).
    await tester.tap(
      find.descendant(
        of: find.byType(MarkdownDefaultContextMenu),
        matching: find.text('Copy'),
      ),
    );
    await tester.pump();
    expect(clipboard, 'See');
  });

  testWidgets('switches between Chat, Editor and Showcase tabs and Dark mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ExampleApp());
    await tester.pump();

    // Switch to Editor tab.
    await tester.tap(find.byKey(const ValueKey('tab-editor')));
    await tester.pump();
    expect(find.byKey(const ValueKey('sync-scroll')), findsOneWidget);
    expect(find.byKey(const ValueKey('status')), findsOneWidget);

    // Switch to Showcase tab.
    await tester.tap(find.byKey(const ValueKey('tab-showcase')));
    await tester.pump();
    expect(find.byType(SliverMarkdownView), findsOneWidget);
    expect(
      find.textContaining('Feature showcase', findRichText: true),
      findsOneWidget,
    );

    // Toggle Dark mode across the shell.
    await tester.tap(find.byKey(const ValueKey('app-dark')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Showcase toggles math, custom syntax, and inspects copy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

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
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(const ExampleApp(initialTab: ExampleTab.showcase));
    await tester.pump();

    // Toggle math mode between Typeset and Unicode fallback.
    expect(find.text('Math: Typeset'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('showcase-math')));
    await tester.pump();
    expect(find.text('Math: Unicode'), findsOneWidget);

    // Toggle custom inline rule (#42).
    await tester.tap(find.byKey(const ValueKey('showcase-custom-inline')));
    await tester.pump();
    expect(tester.takeException(), isNull);

    // Select all and copy as Markdown to verify the inspector output.
    await tester.tap(find.byKey(const ValueKey('showcase-select-all')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('showcase-copy-markdown')));
    await tester.pump();

    expect(clipboard, contains('# Feature showcase'));
    expect(
      find.byKey(const ValueKey('showcase-copied-preview')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('showcase-dismiss-preview')));
    await tester.pump();
    expect(find.byKey(const ValueKey('showcase-copied-preview')), findsNothing);
  });
}
