import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../features/settings/state/settings_cubit.dart';
import '../l10n/app_localizations.dart';
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
/// The speech recognizer is initialized lazily on the first [toggle] so that
/// opening a chat does not trigger microphone / speech recognition permission
/// prompts. `isAvailable` reflects platform support only, so the voice button
/// stays visible until the user actually tries it. If initialization fails
/// (e.g. permission denied), a SnackBar is shown and the next tap retries.
///
/// The [controller] is updated in real-time with recognized speech text.
/// Speech locale is read from [SettingsCubit].
VoiceInputResult useVoiceInput(
  TextEditingController controller, {
  @visibleForTesting VoiceInputService Function()? createService,
}) {
  final context = useContext();
  final voiceInput = useMemoized(createService ?? VoiceInputService.new);
  final isRecording = useState(false);
  final isInitializing = useRef(false);

  useEffect(() => voiceInput.dispose, const []);

  void startListening() {
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

  Future<void> initializeAndStart() async {
    isInitializing.value = true;
    var available = false;
    try {
      available = await voiceInput.initialize();
    } catch (_) {
      available = false;
    } finally {
      isInitializing.value = false;
    }
    if (!context.mounted) return;
    if (!available) {
      _showUnavailableMessage(context);
      return;
    }
    startListening();
  }

  void toggle() {
    if (isRecording.value) {
      voiceInput.stopListening();
      isRecording.value = false;
      return;
    }
    if (isInitializing.value) return;
    if (voiceInput.isAvailable) {
      startListening();
    } else {
      unawaited(initializeAndStart());
    }
  }

  return (
    isAvailable: voiceInput.isPlatformSupported,
    isRecording: isRecording.value,
    toggle: toggle,
  );
}

void _showUnavailableMessage(BuildContext context) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).voiceInputUnavailable),
      ),
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
