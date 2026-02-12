import 'package:bloc_test/bloc_test.dart';
import 'package:ccpocket/features/chat/state/streaming_state.dart';
import 'package:ccpocket/features/chat/state/streaming_state_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StreamingStateCubit', () {
    late StreamingStateCubit cubit;

    setUp(() {
      cubit = StreamingStateCubit();
    });

    tearDown(() {
      cubit.close();
    });

    test('initial state has empty text, thinking, and isStreaming false', () {
      expect(cubit.state, const StreamingState());
      expect(cubit.state.text, isEmpty);
      expect(cubit.state.thinking, isEmpty);
      expect(cubit.state.isStreaming, false);
    });

    group('appendText', () {
      blocTest<StreamingStateCubit, StreamingState>(
        'emits accumulated text with isStreaming true',
        build: () => StreamingStateCubit(),
        act: (cubit) {
          cubit.appendText('Hello ');
          cubit.appendText('world');
        },
        expect: () => [
          const StreamingState(text: 'Hello ', isStreaming: true),
          const StreamingState(text: 'Hello world', isStreaming: true),
        ],
      );

      test('appends empty string without changing text content', () {
        cubit.appendText('');

        expect(cubit.state.text, isEmpty);
        expect(cubit.state.isStreaming, true);
      });

      test('handles special characters', () {
        cubit.appendText('日本語');
        cubit.appendText(' & <html>');

        expect(cubit.state.text, '日本語 & <html>');
        expect(cubit.state.isStreaming, true);
      });

      test('handles multiline text', () {
        cubit.appendText('line1\n');
        cubit.appendText('line2\n');

        expect(cubit.state.text, 'line1\nline2\n');
      });
    });

    group('appendThinking', () {
      blocTest<StreamingStateCubit, StreamingState>(
        'emits accumulated thinking text',
        build: () => StreamingStateCubit(),
        act: (cubit) {
          cubit.appendThinking('Thinking...');
          cubit.appendThinking(' more');
        },
        expect: () => [
          const StreamingState(thinking: 'Thinking...'),
          const StreamingState(thinking: 'Thinking... more'),
        ],
      );

      test('does not set isStreaming', () {
        cubit.appendThinking('thought');

        expect(cubit.state.thinking, 'thought');
        expect(cubit.state.isStreaming, false);
      });

      test('appends empty string without error', () {
        cubit.appendThinking('');

        expect(cubit.state.thinking, isEmpty);
      });
    });

    group('mixed appendText and appendThinking', () {
      test('tracks text and thinking independently', () {
        cubit.appendText('response ');
        cubit.appendThinking('thought ');
        cubit.appendText('continues');
        cubit.appendThinking('deeper');

        expect(cubit.state.text, 'response continues');
        expect(cubit.state.thinking, 'thought deeper');
        expect(cubit.state.isStreaming, true);
      });
    });

    group('reset', () {
      blocTest<StreamingStateCubit, StreamingState>(
        'clears all state back to initial',
        build: () => StreamingStateCubit(),
        act: (cubit) {
          cubit.appendText('text');
          cubit.appendThinking('thought');
          cubit.reset();
        },
        expect: () => [
          const StreamingState(text: 'text', isStreaming: true),
          const StreamingState(
            text: 'text',
            thinking: 'thought',
            isStreaming: true,
          ),
          const StreamingState(),
        ],
      );

      test('reset on already-empty state emits default state', () {
        cubit.reset();

        expect(cubit.state, const StreamingState());
      });

      test('can append after reset', () {
        cubit.appendText('first');
        cubit.reset();
        cubit.appendText('second');

        expect(cubit.state.text, 'second');
        expect(cubit.state.isStreaming, true);
      });
    });
  });
}
