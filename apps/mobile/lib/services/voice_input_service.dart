import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../utils/platform_helper.dart';
import '../features/file_peek/playback/background_media_handler.dart';

class VoiceInputService {
  final SpeechToText _speech = SpeechToText();
  bool _isAvailable = false;
  bool _isListening = false;

  /// Whether this platform can offer voice input at all.
  ///
  /// This is a cheap check that never touches the speech plugin, so it does
  /// not trigger microphone / speech recognition permission prompts.
  bool get isPlatformSupported => !kIsWeb && !isDesktopPlatform;

  /// Whether [initialize] has succeeded (permissions granted and a recognizer
  /// is available).
  bool get isAvailable => _isAvailable;
  bool get isListening => _isListening;

  /// Initializes the speech recognizer.
  ///
  /// On Android this requests RECORD_AUDIO, and on iOS it requests microphone
  /// and speech recognition access, so only call it in response to the user
  /// asking for voice input.
  Future<bool> initialize() async {
    if (!isPlatformSupported) {
      _isAvailable = false;
      return false;
    }
    _isAvailable = await _speech.initialize(
      options: [SpeechToText.androidNoBluetooth],
    );
    return _isAvailable;
  }

  Future<void> startListening({
    required void Function(String text, bool isFinal) onResult,
    required void Function() onDone,
    String? localeId,
  }) async {
    if (!_isAvailable || _isListening) return;
    _isListening = true;
    await BackgroundMediaHandler.instance?.pause();
    if (!_isListening) return;
    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      listenOptions: SpeechListenOptions(
        cancelOnError: true,
        localeId: localeId,
        partialResults: true,
      ),
    );
    // SpeechToText calls onDone via statusListener when done
    _speech.statusListener = (status) {
      if (status == 'done' || status == 'notListening') {
        _isListening = false;
        onDone();
      }
    };
  }

  Future<void> stopListening() async {
    if (!_isListening) return;
    await _speech.stop();
    _isListening = false;
  }

  void dispose() {
    _speech.cancel();
    _isListening = false;
  }
}
