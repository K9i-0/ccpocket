import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceInputService {
  final SpeechToText _speech = SpeechToText();
  bool _isAvailable = false;
  bool _isListening = false;

  bool get isAvailable => _isAvailable;
  bool get isListening => _isListening;

  Future<bool> initialize() async {
    _isAvailable = await _speech.initialize();
    return _isAvailable;
  }

  Future<void> startListening({
    required void Function(String text, bool isFinal) onResult,
    required void Function() onDone,
  }) async {
    if (!_isAvailable || _isListening) return;
    _isListening = true;
    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      listenOptions: SpeechListenOptions(
        cancelOnError: true,
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
