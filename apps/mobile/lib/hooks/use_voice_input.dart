import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../features/settings/state/settings_cubit.dart';
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
/// Speech locale is read from [SettingsCubit].
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
      final localeId = context.read<SettingsCubit>().state.speechLocaleId;
      final baseInputValue = controller.value;
      voiceInput.startListening(
        onResult: (text, _) {
          controller.value = composeVoiceInputValue(baseInputValue, text);
        },
        onDone: () {
          if (context.mounted) isRecording.value = false;
        },
        localeId: localeId.isNotEmpty ? localeId : null,
      );
    }
  }

  return (
    isAvailable: isAvailable.value,
    isRecording: isRecording.value,
    toggle: toggle,
  );
}

@visibleForTesting
TextEditingValue composeVoiceInputValue(
  TextEditingValue baseValue,
  String recognizedText,
) {
  final baseText = baseValue.text;
  final selection = baseValue.selection;
  final rawStart = selection.isValid ? selection.start : baseText.length;
  final rawEnd = selection.isValid ? selection.end : baseText.length;
  final start = _clampOffset(rawStart, baseText.length);
  final end = _clampOffset(rawEnd, baseText.length);
  final insertStart = start < end ? start : end;
  final insertEnd = start < end ? end : start;
  final nextText = baseText.replaceRange(
    insertStart,
    insertEnd,
    recognizedText,
  );
  final cursorOffset = insertStart + recognizedText.length;

  return TextEditingValue(
    text: nextText,
    selection: TextSelection.collapsed(offset: cursorOffset),
  );
}

int _clampOffset(int offset, int max) => offset.clamp(0, max).toInt();
