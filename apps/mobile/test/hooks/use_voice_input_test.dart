import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ccpocket/features/settings/state/settings_cubit.dart';
import 'package:ccpocket/hooks/use_voice_input.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/services/voice_input_service.dart';

void main() {
  group('useVoiceInput', () {
    test('inserts recognized text at the cursor position', () {
      const baseValue = TextEditingValue(
        text: 'before after',
        selection: TextSelection.collapsed(offset: 7),
      );

      final result = composeVoiceInputValue(baseValue, 'voice ');

      expect(result.text, 'before voice after');
      expect(result.selection, const TextSelection.collapsed(offset: 13));
    });

    test('replaces the selected range with recognized text', () {
      const baseValue = TextEditingValue(
        text: 'replace this text',
        selection: TextSelection(baseOffset: 8, extentOffset: 12),
      );

      final result = composeVoiceInputValue(baseValue, 'that');

      expect(result.text, 'replace that text');
      expect(result.selection, const TextSelection.collapsed(offset: 12));
    });

    test('uses the end of the text when selection is invalid', () {
      const baseValue = TextEditingValue(text: 'append');

      final result = composeVoiceInputValue(baseValue, ' voice');

      expect(result.text, 'append voice');
      expect(result.selection, const TextSelection.collapsed(offset: 12));
    });

    group('lazy initialization', () {
      late SettingsCubit settingsCubit;
      late TextEditingController controller;

      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        settingsCubit = SettingsCubit(await SharedPreferences.getInstance());
        controller = TextEditingController();
      });

      tearDown(() async {
        controller.dispose();
        await settingsCubit.close();
      });

      Future<VoiceInputResult Function()> pumpHook(
        WidgetTester tester,
        _FakeVoiceInputService service,
      ) async {
        late VoiceInputResult result;
        await tester.pumpWidget(
          BlocProvider.value(
            value: settingsCubit,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('en'),
              home: Scaffold(
                body: HookBuilder(
                  builder: (context) {
                    result = useVoiceInput(
                      controller,
                      createService: () => service,
                    );
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        );
        return () => result;
      }

      testWidgets('mounting does not initialize speech recognition', (
        tester,
      ) async {
        final service = _FakeVoiceInputService();
        final result = await pumpHook(tester, service);
        await tester.pumpAndSettle();

        expect(service.initializeCalls, 0);
        expect(service.startCalls, 0);
        // Platform support alone keeps the button visible before any
        // permission prompt.
        expect(result().isAvailable, isTrue);
        expect(result().isRecording, isFalse);
      });

      testWidgets('is unavailable when the platform does not support voice', (
        tester,
      ) async {
        final service = _FakeVoiceInputService(platformSupported: false);
        final result = await pumpHook(tester, service);

        expect(result().isAvailable, isFalse);
        expect(service.initializeCalls, 0);
      });

      testWidgets('first tap initializes and then starts listening', (
        tester,
      ) async {
        final service = _FakeVoiceInputService();
        final result = await pumpHook(tester, service);

        result().toggle();
        await tester.pump();

        expect(service.initializeCalls, 1);
        expect(service.startCalls, 1);
        expect(result().isRecording, isTrue);

        service.emitResult('hello');
        expect(controller.text, 'hello');

        // Stopping does not re-initialize.
        result().toggle();
        await tester.pump();
        expect(service.stopCalls, 1);
        expect(result().isRecording, isFalse);

        // Subsequent taps reuse the initialized recognizer.
        result().toggle();
        await tester.pump();
        expect(service.initializeCalls, 1);
        expect(service.startCalls, 2);
      });

      testWidgets('shows a message and keeps button when init fails', (
        tester,
      ) async {
        final service = _FakeVoiceInputService(initializeResult: false);
        final result = await pumpHook(tester, service);

        result().toggle();
        await tester.pump();
        await tester.pump();

        expect(service.initializeCalls, 1);
        expect(service.startCalls, 0);
        expect(result().isRecording, isFalse);
        expect(result().isAvailable, isTrue);
        expect(
          find.text(
            lookupAppLocalizations(const Locale('en')).voiceInputUnavailable,
          ),
          findsOneWidget,
        );

        // Tapping again retries initialization (e.g. after granting
        // permission in system settings).
        service.initializeResult = true;
        result().toggle();
        await tester.pump();
        expect(service.initializeCalls, 2);
        expect(service.startCalls, 1);
      });

      testWidgets('ignores taps while initialization is in flight', (
        tester,
      ) async {
        final service = _FakeVoiceInputService(holdInitialize: true);
        final result = await pumpHook(tester, service);

        result().toggle();
        result().toggle();
        await tester.pump();
        expect(service.initializeCalls, 1);

        service.completeInitialize(true);
        await tester.pump();
        await tester.pump();
        expect(service.startCalls, 1);
        expect(result().isRecording, isTrue);
      });
    });

    testWidgets('returns initial state correctly', (tester) async {
      late VoiceInputResult result;
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: HookBuilder(
            builder: (context) {
              result = useVoiceInput(controller);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      // The default service reports desktop/test hosts as unsupported
      // without touching the speech plugin.
      expect(result.isAvailable, isFalse);
      expect(result.isRecording, isFalse);

      controller.dispose();
    });
  });
}

class _FakeVoiceInputService implements VoiceInputService {
  _FakeVoiceInputService({
    this.platformSupported = true,
    this.initializeResult = true,
    this.holdInitialize = false,
  });

  final bool platformSupported;
  bool initializeResult;
  final bool holdInitialize;

  int initializeCalls = 0;
  int startCalls = 0;
  int stopCalls = 0;
  bool _available = false;
  bool _listening = false;
  Completer<bool>? _pendingInit;
  void Function(String text, bool isFinal)? _onResult;

  @override
  bool get isPlatformSupported => platformSupported;

  @override
  bool get isAvailable => _available;

  @override
  bool get isListening => _listening;

  @override
  Future<bool> initialize() async {
    initializeCalls++;
    if (holdInitialize) {
      _pendingInit = Completer<bool>();
      _available = await _pendingInit!.future;
    } else {
      _available = initializeResult;
    }
    return _available;
  }

  void completeInitialize(bool value) => _pendingInit!.complete(value);

  void emitResult(String text) => _onResult?.call(text, false);

  @override
  Future<void> startListening({
    required void Function(String text, bool isFinal) onResult,
    required void Function() onDone,
    String? localeId,
  }) async {
    startCalls++;
    _listening = true;
    _onResult = onResult;
  }

  @override
  Future<void> stopListening() async {
    stopCalls++;
    _listening = false;
  }

  @override
  void dispose() {}
}
