import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
    bool isVoiceAvailable = false,
    bool isRecording = false,
    VoidCallback? onSend,
    VoidCallback? onStop,
    VoidCallback? onInterrupt,
    VoidCallback? onToggleVoice,
    VoidCallback? onShowSlashCommands,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ChatInputBar(
          inputController: inputController,
          status: status,
          hasInputText: hasInputText,
          isVoiceAvailable: isVoiceAvailable,
          isRecording: isRecording,
          onSend: onSend ?? () {},
          onStop: onStop ?? () {},
          onInterrupt: onInterrupt ?? () {},
          onToggleVoice: onToggleVoice ?? () {},
          onShowSlashCommands: onShowSlashCommands ?? () {},
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

    testWidgets('slash command button fires callback', (tester) async {
      var shown = false;
      await tester.pumpWidget(
        buildSubject(onShowSlashCommands: () => shown = true),
      );

      await tester.tap(find.byKey(const ValueKey('slash_command_button')));
      expect(shown, isTrue);
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
      await tester.pumpWidget(
        buildSubject(status: ProcessStatus.running, hasInputText: true),
      );

      expect(find.byKey(const ValueKey('send_button')), findsOneWidget);
    });
  });
}
