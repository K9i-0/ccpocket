import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
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
    bool isInMentionContext = false,
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
          isInMentionContext: isInMentionContext,
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
  });
}
