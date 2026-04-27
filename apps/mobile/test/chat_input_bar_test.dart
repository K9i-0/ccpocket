import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/utils/diff_parser.dart';
import 'package:ccpocket/widgets/chat_input_bar.dart';

void main() {
  late TextEditingController inputController;

  setUp(() {
    inputController = TextEditingController();
  });

  tearDown(() {
    inputController.dispose();
  });

  Widget buildSubject({
    ProcessStatus status = ProcessStatus.idle,
    bool hasInputText = false,
    bool isInputEmpty = true,
    bool isVoiceAvailable = false,
    bool isRecording = false,
    VoidCallback? onSend,
    VoidCallback? onStop,
    VoidCallback? onInterrupt,
    VoidCallback? onToggleVoice,
    VoidCallback? onIndent,
    VoidCallback? onDedent,
    bool canDedent = true,
    VoidCallback? onSlashCommand,
    VoidCallback? onMention,
    VoidCallback? onDollarMention,
    bool isInMentionContext = false,
    bool showDollarButton = false,
    DiffSelection? attachedDiffSelection,
    KeyEventResult Function(KeyEvent event)? onCompletionKeyEvent,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: ChatInputBar(
          inputController: inputController,
          status: status,
          hasInputText: hasInputText,
          isInputEmpty: isInputEmpty,
          isVoiceAvailable: isVoiceAvailable,
          isRecording: isRecording,
          onSend: onSend ?? () {},
          onStop: onStop ?? () {},
          onInterrupt: onInterrupt ?? () {},
          onToggleVoice: onToggleVoice ?? () {},
          onIndent: onIndent ?? () {},
          onDedent: onDedent ?? () {},
          canDedent: canDedent,
          onSlashCommand: onSlashCommand ?? () {},
          onMention: onMention ?? () {},
          onDollarMention: onDollarMention,
          isInMentionContext: isInMentionContext,
          showDollarButton: showDollarButton,
          attachedDiffSelection: attachedDiffSelection,
          onCompletionKeyEvent: onCompletionKeyEvent,
        ),
      ),
    );
  }

  group('ChatInputBar', () {
    testWidgets('shows send button when text is present', (tester) async {
      await tester.pumpWidget(buildSubject(hasInputText: true));

      expect(find.byKey(const ValueKey('send_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('stop_button')), findsNothing);
      expect(find.byKey(const ValueKey('voice_button')), findsNothing);
    });

    testWidgets('shows stop button when running and no text', (tester) async {
      await tester.pumpWidget(buildSubject(status: ProcessStatus.running));

      expect(find.byKey(const ValueKey('stop_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('send_button')), findsNothing);
    });

    testWidgets('shows voice button when idle, no text, and voice available', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(isVoiceAvailable: true));

      expect(find.byKey(const ValueKey('voice_button')), findsOneWidget);
      // Voice button is now in left toolbar, send button always shown on right
      expect(find.byKey(const ValueKey('send_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('stop_button')), findsNothing);
    });

    testWidgets('shows send button when idle, no text, no voice', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byKey(const ValueKey('send_button')), findsOneWidget);
    });

    testWidgets('voice button stays visible when text present', (tester) async {
      await tester.pumpWidget(
        buildSubject(hasInputText: true, isVoiceAvailable: true),
      );

      // Both voice (left toolbar) and send (right) are visible
      expect(find.byKey(const ValueKey('send_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('voice_button')), findsOneWidget);
    });

    testWidgets('send callback fires on button tap', (tester) async {
      var sent = false;
      await tester.pumpWidget(
        buildSubject(hasInputText: true, onSend: () => sent = true),
      );

      await tester.tap(find.byKey(const ValueKey('send_button')));
      expect(sent, isTrue);
    });

    testWidgets('interrupt callback fires on stop button tap', (tester) async {
      var interrupted = false;
      await tester.pumpWidget(
        buildSubject(
          status: ProcessStatus.running,
          onInterrupt: () => interrupted = true,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('stop_button')));
      expect(interrupted, isTrue);
    });

    testWidgets('stop callback fires on long press', (tester) async {
      var stopped = false;
      await tester.pumpWidget(
        buildSubject(
          status: ProcessStatus.running,
          onStop: () => stopped = true,
        ),
      );

      await tester.longPress(find.byKey(const ValueKey('stop_button')));
      expect(stopped, isTrue);
    });

    testWidgets('indent button fires callback', (tester) async {
      var indented = false;
      await tester.pumpWidget(buildSubject(onIndent: () => indented = true));

      await tester.tap(find.byKey(const ValueKey('indent_button')));
      expect(indented, isTrue);
    });

    testWidgets('dedent button fires callback when enabled', (tester) async {
      var dedented = false;
      await tester.pumpWidget(
        buildSubject(
          isInputEmpty: false,
          onDedent: () => dedented = true,
          canDedent: true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('dedent_button')));
      expect(dedented, isTrue);
    });

    testWidgets('dedent button is disabled when canDedent is false', (
      tester,
    ) async {
      var dedented = false;
      await tester.pumpWidget(
        buildSubject(
          isInputEmpty: false,
          onDedent: () => dedented = true,
          canDedent: false,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('dedent_button')));
      expect(dedented, isFalse);
    });

    testWidgets('voice toggle callback fires', (tester) async {
      var toggled = false;
      await tester.pumpWidget(
        buildSubject(
          isVoiceAvailable: true,
          onToggleVoice: () => toggled = true,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('voice_button')));
      expect(toggled, isTrue);
    });

    testWidgets('shows dollar button when enabled', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildSubject(
          showDollarButton: true,
          onDollarMention: () => tapped = true,
        ),
      );

      expect(find.byKey(const ValueKey('dollar_button')), findsOneWidget);
      final tooltip = tester.widget<Tooltip>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('dollar_button')),
              matching: find.byType(Tooltip),
            )
            .first,
      );
      expect(tooltip.message, 'Insert skill or app');

      await tester.tap(find.byKey(const ValueKey('dollar_button')));
      expect(tapped, isTrue);
    });

    testWidgets('shows disabled send button when starting', (tester) async {
      await tester.pumpWidget(buildSubject(status: ProcessStatus.starting));

      // Send button is visible but stop button is not
      expect(find.byKey(const ValueKey('send_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('stop_button')), findsNothing);

      // Send button should be disabled (onPressed is null)
      final iconButton = tester.widget<IconButton>(
        find.byKey(const ValueKey('send_button')),
      );
      expect(iconButton.onPressed, isNull);
    });

    testWidgets('text field is disabled when starting', (tester) async {
      await tester.pumpWidget(buildSubject(status: ProcessStatus.starting));

      final textField = tester.widget<TextField>(
        find.byKey(const ValueKey('message_input')),
      );
      expect(textField.enabled, isFalse);
    });

    testWidgets('message input field exists', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byKey(const ValueKey('message_input')), findsOneWidget);
    });

    testWidgets('completion handler suppresses Tab indentation', (
      tester,
    ) async {
      var indented = false;
      var handledTab = false;
      await tester.pumpWidget(
        buildSubject(
          onIndent: () => indented = true,
          onCompletionKeyEvent: (event) {
            if (event.logicalKey == LogicalKeyboardKey.tab) {
              handledTab = true;
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
        ),
      );

      await tester.tap(find.byKey(const ValueKey('message_input')));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.tab);

      expect(handledTab, isTrue);
      expect(indented, isFalse);
    });

    testWidgets('Tab still indents when completion ignores key', (
      tester,
    ) async {
      var indented = false;
      await tester.pumpWidget(
        buildSubject(
          onIndent: () => indented = true,
          onCompletionKeyEvent: (_) => KeyEventResult.ignored,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('message_input')));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.tab);

      expect(indented, isTrue);
    });

    testWidgets('completion handler suppresses Enter send', (tester) async {
      var sent = false;
      var handledEnter = false;
      await tester.pumpWidget(
        buildSubject(
          hasInputText: true,
          onSend: () => sent = true,
          onCompletionKeyEvent: (event) {
            if (event.logicalKey == LogicalKeyboardKey.enter) {
              handledEnter = true;
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
        ),
      );

      await tester.tap(find.byKey(const ValueKey('message_input')));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);

      expect(handledEnter, isTrue);
      expect(sent, isFalse);
    });

    testWidgets('Ctrl+K deletes from cursor to end of line', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byKey(const ValueKey('message_input')));
      inputController.value = const TextEditingValue(
        text: 'first line\nsecond line',
        selection: TextSelection.collapsed(offset: 8),
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      expect(inputController.text, 'first li\nsecond line');
      expect(inputController.selection.baseOffset, 8);
    });

    testWidgets('Ctrl+K deletes selected text', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byKey(const ValueKey('message_input')));
      inputController.value = const TextEditingValue(
        text: 'delete selected text',
        selection: TextSelection(baseOffset: 7, extentOffset: 15),
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      expect(inputController.text, 'delete  text');
      expect(inputController.selection.baseOffset, 7);
    });

    testWidgets('Ctrl+D deletes next character', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byKey(const ValueKey('message_input')));
      inputController.value = const TextEditingValue(
        text: 'abc',
        selection: TextSelection.collapsed(offset: 1),
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      expect(inputController.text, 'ac');
      expect(inputController.selection.baseOffset, 1);
    });

    testWidgets('text field supports multiline input', (tester) async {
      await tester.pumpWidget(buildSubject());

      final textField = tester.widget<TextField>(
        find.byKey(const ValueKey('message_input')),
      );
      expect(textField.maxLines, 6);
      expect(textField.minLines, 1);
      expect(textField.keyboardType, TextInputType.multiline);
    });

    testWidgets('send button shows when running with text', (tester) async {
      // When hasInputText=true, the stop condition (!hasInputText) is false,
      // so it falls through to send button even when running.
      // SDK (Claude Code) accepts messages during processing.
      await tester.pumpWidget(
        buildSubject(status: ProcessStatus.running, hasInputText: true),
      );

      expect(find.byKey(const ValueKey('send_button')), findsOneWidget);
    });

    group('mention button (@)', () {
      testWidgets('mention button exists between indent and attach', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());

        // All three buttons should be present
        final indentFinder = find.byKey(const ValueKey('indent_button'));
        final mentionFinder = find.byKey(const ValueKey('mention_button'));
        final attachFinder = find.byKey(const ValueKey('attach_image_button'));

        expect(indentFinder, findsOneWidget);
        expect(mentionFinder, findsOneWidget);
        expect(attachFinder, findsOneWidget);

        // Verify order: indent center.dx < mention center.dx < attach center.dx
        final indentCenter = tester.getCenter(indentFinder);
        final mentionCenter = tester.getCenter(mentionFinder);
        final attachCenter = tester.getCenter(attachFinder);
        expect(mentionCenter.dx, greaterThan(indentCenter.dx));
        expect(mentionCenter.dx, lessThan(attachCenter.dx));
      });

      testWidgets('mention button fires callback on tap', (tester) async {
        var tapped = false;
        await tester.pumpWidget(buildSubject(onMention: () => tapped = true));

        await tester.tap(find.byKey(const ValueKey('mention_button')));
        expect(tapped, isTrue);
      });

      testWidgets('mention button tooltip includes plugins', (tester) async {
        await tester.pumpWidget(buildSubject());

        final tooltip = tester.widget<Tooltip>(
          find
              .ancestor(
                of: find.byKey(const ValueKey('mention_button')),
                matching: find.byType(Tooltip),
              )
              .first,
        );
        expect(tooltip.message, 'Mention file or plugin');
      });

      testWidgets(
        'mention button is disabled when isInMentionContext is true',
        (tester) async {
          var tapped = false;
          await tester.pumpWidget(
            buildSubject(
              isInMentionContext: true,
              onMention: () => tapped = true,
            ),
          );

          await tester.tap(find.byKey(const ValueKey('mention_button')));
          expect(tapped, isFalse);
        },
      );
    });

    group('slash command button (input empty swap)', () {
      testWidgets('shows slash command button when input is empty', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject(isInputEmpty: true));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('slash_command_button')),
          findsOneWidget,
        );
        final tooltipMessages = tester
            .widgetList<Tooltip>(find.byType(Tooltip))
            .map((tooltip) => tooltip.message)
            .toList();
        expect(tooltipMessages, contains('Insert command or skill'));
        expect(find.byKey(const ValueKey('dedent_button')), findsNothing);
      });

      testWidgets('shows dedent button when input is not empty', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject(isInputEmpty: false));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('dedent_button')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('slash_command_button')),
          findsNothing,
        );
      });

      testWidgets('slash command button fires callback on tap', (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          buildSubject(isInputEmpty: true, onSlashCommand: () => tapped = true),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('slash_command_button')));
        expect(tapped, isTrue);
      });
    });

    testWidgets('diff preview shows hunk-focused summary and metadata', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          hasInputText: true,
          isInputEmpty: false,
          attachedDiffSelection: const DiffSelection(
            diffText:
                'diff --git a/lib/todo_list.dart b/lib/todo_list.dart\n'
                '--- a/lib/todo_list.dart\n'
                '+++ b/lib/todo_list.dart\n'
                '@@ -5,7 +5,7 @@ class TodoList {\n'
                ' List<Todo> get items => List.unmodifiable(_items);\n'
                '-void add(String title) {\n'
                '+void add(String title, {Priority priority = Priority.medium}) {\n'
                '   final id = DateTime.now().millisecondsSinceEpoch.toString();\n'
                '   _items.add(Todo(id: id, title: title));\n'
                ' }',
          ),
        ),
      );

      expect(find.text('2 changed lines · 1 hunk'), findsOneWidget);
      expect(find.textContaining('lib/todo_list.dart'), findsOneWidget);
      expect(
        find.textContaining('@@ -5,7 +5,7 @@ class TodoList {'),
        findsOneWidget,
      );
      expect(find.text('12 diff lines'), findsNothing);
      expect(
        find.textContaining('diff --git a/lib/todo_list.dart'),
        findsNothing,
      );
      expect(find.textContaining('@mentioned'), findsNothing);
    });

    testWidgets(
      'diff preview summarizes file request changes by changed lines and hunks',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            hasInputText: true,
            isInputEmpty: false,
            attachedDiffSelection: const DiffSelection(
              diffText:
                  'diff --git a/lib/a.dart b/lib/a.dart\n'
                  '--- a/lib/a.dart\n'
                  '+++ b/lib/a.dart\n'
                  '@@ -1,2 +1,2 @@\n'
                  '-old\n'
                  '+new\n'
                  ' same\n'
                  '@@ -10,2 +10,2 @@\n'
                  '-old2\n'
                  '+new2\n'
                  ' same2',
            ),
          ),
        );

        expect(find.text('4 changed lines · 2 hunks'), findsOneWidget);
        expect(find.textContaining('lib/a.dart'), findsOneWidget);
        expect(find.textContaining('@@ -1,2 +1,2 @@'), findsOneWidget);
        expect(find.textContaining('--- a/lib/a.dart'), findsNothing);
      },
    );
  });
}
