import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../services/voice_input_service.dart';

/// Result record returned by [useVoiceInput].
typedef VoiceInputResult = ({
  bool isAvailable,
  bool isRecording,
  void Function() toggle,
});

/// Manages [VoiceInputService] lifecycle: initialization, start/stop, and
/// disposal.
///
/// The [controller] is updated in real-time with recognized speech text.
VoiceInputResult useVoiceInput(TextEditingController controller) {
  final context = useContext();
  final voiceInput = useMemoized(() => VoiceInputService());
  final isAvailable = useState(false);
  final isRecording = useState(false);

  useEffect(() {
    voiceInput.initialize().then((available) {
      if (context.mounted) isAvailable.value = available;
    });
    return voiceInput.dispose;
  }, const []);

  void toggle() {
    if (isRecording.value) {
      voiceInput.stopListening();
      isRecording.value = false;
    } else {
      HapticFeedback.mediumImpact();
      isRecording.value = true;
      voiceInput.startListening(
        onResult: (text, isFinal) {
          controller.text = text;
          if (isFinal) {
            controller.selection = TextSelection.fromPosition(
              TextPosition(offset: controller.text.length),
            );
          }
        },
        onDone: () {
          if (context.mounted) isRecording.value = false;
        },
      );
    }
  }

  return (
    isAvailable: isAvailable.value,
    isRecording: isRecording.value,
    toggle: toggle,
  );
}
