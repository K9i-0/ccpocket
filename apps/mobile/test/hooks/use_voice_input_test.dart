import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/hooks/use_voice_input.dart';

void main() {
  group('useVoiceInput', () {
    testWidgets('returns initial state correctly', (tester) async {
      late VoiceInputResult result;
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              result = useVoiceInput(controller);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      // Voice input is not available by default (SpeechToText init fails in
      // test environment).
      expect(result.isAvailable, isFalse);
      expect(result.isRecording, isFalse);

      controller.dispose();
    });
  });
}
