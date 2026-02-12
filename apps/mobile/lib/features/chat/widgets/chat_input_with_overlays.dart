import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:image_picker/image_picker.dart';

import '../../../hooks/use_voice_input.dart';
import '../../../models/messages.dart';
import '../../../providers/bridge_cubits.dart';
import '../../../widgets/chat_input_bar.dart';
import '../../../widgets/file_mention_overlay.dart';
import '../../../widgets/slash_command_overlay.dart';
import '../../../widgets/slash_command_sheet.dart'
    show SlashCommand, SlashCommandSheet, fallbackSlashCommands;
import '../state/chat_session_cubit.dart';

/// Manages the chat input bar together with slash-command and @-mention
/// overlays using [OverlayPortal].
///
/// [inputController] is managed by the parent widget to preserve text across
/// rebuilds (e.g., when approval bar appears/disappears).
/// Overlay controllers and voice input are managed via hooks.
class ChatInputWithOverlays extends HookWidget {
  final String sessionId;
  final ProcessStatus status;
  final VoidCallback onScrollToBottom;
  final TextEditingController inputController;

  const ChatInputWithOverlays({
    super.key,
    required this.sessionId,
    required this.status,
    required this.onScrollToBottom,
    required this.inputController,
  });

  @override
  Widget build(BuildContext context) {
    // Track if input has text (initialize from controller's current value)
    final hasInputText = useState(inputController.text.trim().isNotEmpty);

    // Voice input
    final voice = useVoiceInput(inputController);

    // OverlayPortal controllers
    final slashPortalController = useMemoized(() => OverlayPortalController());
    final filePortalController = useMemoized(() => OverlayPortalController());

    // Filtered overlay items
    final filteredSlash = useState<List<SlashCommand>>(const []);
    final filteredFiles = useState<List<String>>(const []);

    // Image attachment state
    final attachedImage = useState<Uint8List?>(null);
    final attachedMimeType = useState<String?>(null);

    // Project files for @-mention
    final projectFiles = context.watch<FileListCubit>().state;

    // Slash commands from cubit
    final slashCommands = context.watch<ChatSessionCubit>().state.slashCommands;
    final commands = slashCommands.isNotEmpty
        ? slashCommands
        : fallbackSlashCommands;

    // Input change listener
    useEffect(() {
      void onChange() {
        final text = inputController.text;
        final trimHasText = text.trim().isNotEmpty;
        if (trimHasText != hasInputText.value) {
          hasInputText.value = trimHasText;
        }

        if (text.startsWith('/') && text.isNotEmpty) {
          // Slash command filtering
          final query = text.toLowerCase();
          final filtered = commands
              .where((c) => c.command.toLowerCase().startsWith(query))
              .toList();
          if (filtered.isNotEmpty) {
            filteredSlash.value = filtered;
            slashPortalController.show();
          } else {
            slashPortalController.hide();
          }
          filePortalController.hide();
        } else {
          slashPortalController.hide();
          // @-mention filtering
          final mentionQuery = _extractMentionQuery(
            text,
            inputController.selection.baseOffset,
          );
          if (mentionQuery != null && projectFiles.isNotEmpty) {
            final q = mentionQuery.toLowerCase();
            final filtered = projectFiles
                .where((f) => f.toLowerCase().contains(q))
                .take(15)
                .toList();
            if (filtered.isNotEmpty) {
              filteredFiles.value = filtered;
              filePortalController.show();
            } else {
              filePortalController.hide();
            }
          } else {
            filePortalController.hide();
          }
        }
      }

      inputController.addListener(onChange);
      return () => inputController.removeListener(onChange);
    }, [commands, projectFiles]);

    // Callbacks
    void onSlashCommandSelected(String command) {
      slashPortalController.hide();
      inputController.text = '$command ';
      inputController.selection = TextSelection.fromPosition(
        TextPosition(offset: inputController.text.length),
      );
    }

    void onFileMentionSelected(String filePath) {
      filePortalController.hide();
      final text = inputController.text;
      final cursorPos = inputController.selection.baseOffset;
      final beforeCursor = text.substring(0, cursorPos);
      final atIndex = beforeCursor.lastIndexOf('@');
      if (atIndex < 0) return;
      final afterCursor = text.substring(cursorPos);
      final newText = '${text.substring(0, atIndex)}@$filePath $afterCursor';
      inputController.text = newText;
      final newCursor = atIndex + 1 + filePath.length + 1;
      inputController.selection = TextSelection.fromPosition(
        TextPosition(offset: newCursor),
      );
    }

    void sendMessage() {
      final text = inputController.text.trim();
      if (text.isEmpty && attachedImage.value == null) return;
      HapticFeedback.lightImpact();

      final cubit = context.read<ChatSessionCubit>();

      Uint8List? imageBytes;
      String? mimeType;

      // Capture and clear attached image
      if (attachedImage.value != null && attachedMimeType.value != null) {
        imageBytes = attachedImage.value;
        mimeType = attachedMimeType.value;
        attachedImage.value = null;
        attachedMimeType.value = null;
      }

      cubit.sendMessage(
        text.isEmpty ? 'What is in this image?' : text,
        imageBytes: imageBytes,
        imageMimeType: mimeType,
      );
      inputController.clear();
      onScrollToBottom();
    }

    Future<void> pickImage() async {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        attachedImage.value = bytes;

        // Determine mime type from extension
        final ext = image.path.split('.').last.toLowerCase();
        attachedMimeType.value = switch (ext) {
          'png' => 'image/png',
          'gif' => 'image/gif',
          'webp' => 'image/webp',
          _ => 'image/jpeg',
        };
      }
    }

    void clearAttachment() {
      attachedImage.value = null;
      attachedMimeType.value = null;
    }

    void stopSession() {
      HapticFeedback.mediumImpact();
      context.read<ChatSessionCubit>().stop();
    }

    void interruptSession() {
      HapticFeedback.mediumImpact();
      context.read<ChatSessionCubit>().interrupt();
    }

    void showSlashCommandSheet() {
      showModalBottomSheet(
        context: context,
        builder: (_) => SlashCommandSheet(
          commands: commands,
          onSelect: onSlashCommandSelected,
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;

    return OverlayPortal(
      controller: slashPortalController,
      overlayChildBuilder: (_) => Positioned(
        bottom: _inputBarHeight(context),
        left: 8,
        width: screenWidth - 16,
        child: SlashCommandOverlay(
          filteredCommands: filteredSlash.value,
          onSelect: onSlashCommandSelected,
          onDismiss: slashPortalController.hide,
        ),
      ),
      child: OverlayPortal(
        controller: filePortalController,
        overlayChildBuilder: (_) => Positioned(
          bottom: _inputBarHeight(context),
          left: 8,
          width: screenWidth - 16,
          child: FileMentionOverlay(
            filteredFiles: filteredFiles.value,
            onSelect: onFileMentionSelected,
            onDismiss: filePortalController.hide,
          ),
        ),
        child: ChatInputBar(
          inputController: inputController,
          status: status,
          hasInputText: hasInputText.value || attachedImage.value != null,
          isVoiceAvailable: voice.isAvailable,
          isRecording: voice.isRecording,
          onSend: sendMessage,
          onStop: stopSession,
          onInterrupt: interruptSession,
          onToggleVoice: voice.toggle,
          onShowSlashCommands: showSlashCommandSheet,
          onAttachImage: pickImage,
          attachedImageBytes: attachedImage.value,
          onClearAttachment: clearAttachment,
        ),
      ),
    );
  }

  /// Estimate the input bar height for overlay positioning.
  double _inputBarHeight(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    // Base padding (8 top + 8 bottom + bottomPadding) + TextField (~44) + row (~40) + gap (4)
    return 8 + 44 + 4 + 40 + 8 + bottomPadding;
  }
}

/// Extract the file query after the last '@' before cursor position.
/// Returns null if no active @-mention is being typed.
String? _extractMentionQuery(String text, int cursorPos) {
  if (cursorPos < 0) return null;
  final beforeCursor = text.substring(0, cursorPos);
  final atIndex = beforeCursor.lastIndexOf('@');
  if (atIndex < 0) return null;
  // '@' must be at start or preceded by whitespace
  if (atIndex > 0 && !RegExp(r'\s').hasMatch(beforeCursor[atIndex - 1])) {
    return null;
  }
  final query = beforeCursor.substring(atIndex + 1);
  // No spaces in the query (file paths don't have spaces)
  if (query.contains(' ')) return null;
  return query;
}
