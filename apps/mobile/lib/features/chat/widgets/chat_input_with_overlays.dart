import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:image_picker/image_picker.dart';
import 'package:super_clipboard/super_clipboard.dart';

import '../../../hooks/use_voice_input.dart';
import '../../../models/messages.dart';
import '../../../providers/bridge_cubits.dart';
import '../../../utils/diff_parser.dart';
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

  /// Diff selection to attach (set by parent when returning from DiffScreen).
  final DiffSelection? initialDiffSelection;

  /// Called after the diff selection is consumed into local state.
  final VoidCallback? onDiffSelectionConsumed;

  /// Called when the diff selection is cleared (sent or manually removed).
  final VoidCallback? onDiffSelectionCleared;

  /// Opens the diff screen with current selection state.
  final void Function(DiffSelection? currentSelection)? onOpenDiffScreen;

  /// Custom hint text for the input field (e.g. provider-specific).
  final String? hintText;

  const ChatInputWithOverlays({
    super.key,
    required this.sessionId,
    required this.status,
    required this.onScrollToBottom,
    required this.inputController,
    this.initialDiffSelection,
    this.onDiffSelectionConsumed,
    this.onDiffSelectionCleared,
    this.onOpenDiffScreen,
    this.hintText,
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

    // LayerLink for CompositedTransformFollower positioning
    final layerLink = useMemoized(() => LayerLink());

    // Filtered overlay items
    final filteredSlash = useState<List<SlashCommand>>(const []);
    final filteredFiles = useState<List<String>>(const []);

    // Image attachment state
    final attachedImage = useState<Uint8List?>(null);
    final attachedMimeType = useState<String?>(null);

    // Diff selection attachment state
    final attachedDiffSelection = useState<DiffSelection?>(null);

    // Consume initialDiffSelection from parent
    useEffect(() {
      if (initialDiffSelection != null && !initialDiffSelection!.isEmpty) {
        attachedDiffSelection.value = initialDiffSelection;
        onDiffSelectionConsumed?.call();
      }
      return null;
    }, [initialDiffSelection]);

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
      if (text.isEmpty &&
          attachedImage.value == null &&
          attachedDiffSelection.value == null) {
        return;
      }
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

      // Capture and clear diff selection
      DiffSelection? selection;
      if (attachedDiffSelection.value != null) {
        selection = attachedDiffSelection.value;
        attachedDiffSelection.value = null;
        onDiffSelectionCleared?.call();
      }

      // Build final message text with @mentions and/or diff block prepended
      var finalText = text;
      if (selection != null) {
        final parts = <String>[];

        // @mentions for fully selected files
        if (selection.mentions.isNotEmpty) {
          parts.add(selection.mentions.map((f) => '@$f').join(' '));
        }

        // Diff block for partially selected hunks
        if (selection.diffText.isNotEmpty) {
          parts.add('```diff\n${selection.diffText}\n```');
        }

        if (parts.isNotEmpty) {
          final prefix = parts.join('\n\n');
          finalText = finalText.isEmpty ? prefix : '$prefix\n\n$finalText';
        }
      }

      cubit.sendMessage(
        finalText.isEmpty ? 'What is in this image?' : finalText,
        imageBytes: imageBytes,
        imageMimeType: mimeType,
      );
      inputController.clear();
      onScrollToBottom();
    }

    Future<void> pickImageFromGallery() async {
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

    Future<void> pasteFromClipboard() async {
      final clipboard = SystemClipboard.instance;
      if (clipboard == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('クリップボードにアクセスできません')));
        }
        return;
      }

      try {
        final reader = await clipboard.read();

        // Try PNG first, then JPEG
        for (final format in [Formats.png, Formats.jpeg]) {
          if (reader.canProvide(format)) {
            reader.getFile(format, (file) async {
              try {
                final bytes = await file.readAll();
                if (context.mounted) {
                  attachedImage.value = bytes;
                  attachedMimeType.value = format == Formats.png
                      ? 'image/png'
                      : 'image/jpeg';
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('画像の読み込みに失敗しました')),
                  );
                }
              }
            });
            return;
          }
        }

        // No image found in clipboard
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('クリップボードに画像がありません')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('クリップボードの読み取りに失敗しました')));
        }
      }
    }

    Future<bool> hasClipboardImage() async {
      final clipboard = SystemClipboard.instance;
      if (clipboard == null) return false;
      try {
        final reader = await clipboard.read();
        return reader.canProvide(Formats.png) ||
            reader.canProvide(Formats.jpeg);
      } catch (_) {
        return false;
      }
    }

    Future<void> showAttachOptions() async {
      final hasClipImage = await hasClipboardImage();
      if (!context.mounted) return;

      showModalBottomSheet(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: const ValueKey('attach_from_gallery'),
                leading: const Icon(Icons.photo_library),
                title: const Text('ギャラリーから選択'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  pickImageFromGallery();
                },
              ),
              ListTile(
                key: const ValueKey('attach_from_clipboard'),
                leading: Icon(
                  Icons.content_paste,
                  color: hasClipImage
                      ? null
                      : Theme.of(sheetContext).colorScheme.outline,
                ),
                title: Text(
                  'クリップボードから貼付',
                  style: hasClipImage
                      ? null
                      : TextStyle(
                          color: Theme.of(sheetContext).colorScheme.outline,
                        ),
                ),
                enabled: hasClipImage,
                onTap: hasClipImage
                    ? () {
                        Navigator.pop(sheetContext);
                        pasteFromClipboard();
                      }
                    : null,
              ),
            ],
          ),
        ),
      );
    }

    void clearAttachment() {
      attachedImage.value = null;
      attachedMimeType.value = null;
    }

    void clearDiffSelection() {
      attachedDiffSelection.value = null;
      onDiffSelectionCleared?.call();
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

    Widget buildFollowerOverlay({required Widget child}) {
      return CompositedTransformFollower(
        link: layerLink,
        targetAnchor: Alignment.topLeft,
        followerAnchor: Alignment.bottomLeft,
        child: SizedBox(width: screenWidth - 16, child: child),
      );
    }

    return OverlayPortal(
      controller: slashPortalController,
      overlayChildBuilder: (_) => Positioned(
        left: 8,
        child: buildFollowerOverlay(
          child: SlashCommandOverlay(
            filteredCommands: filteredSlash.value,
            onSelect: onSlashCommandSelected,
            onDismiss: slashPortalController.hide,
          ),
        ),
      ),
      child: OverlayPortal(
        controller: filePortalController,
        overlayChildBuilder: (_) => Positioned(
          left: 8,
          child: buildFollowerOverlay(
            child: FileMentionOverlay(
              filteredFiles: filteredFiles.value,
              onSelect: onFileMentionSelected,
              onDismiss: filePortalController.hide,
            ),
          ),
        ),
        child: CompositedTransformTarget(
          link: layerLink,
          child: ChatInputBar(
            inputController: inputController,
            status: status,
            hasInputText:
                hasInputText.value ||
                attachedImage.value != null ||
                attachedDiffSelection.value != null,
            isVoiceAvailable: voice.isAvailable,
            isRecording: voice.isRecording,
            onSend: sendMessage,
            onStop: stopSession,
            onInterrupt: interruptSession,
            onToggleVoice: voice.toggle,
            onShowSlashCommands: showSlashCommandSheet,
            onAttachImage: showAttachOptions,
            attachedImageBytes: attachedImage.value,
            onClearAttachment: clearAttachment,
            attachedDiffSelection: attachedDiffSelection.value,
            onClearDiffSelection: clearDiffSelection,
            onTapDiffPreview: onOpenDiffScreen != null
                ? () => onOpenDiffScreen!(attachedDiffSelection.value)
                : null,
            hintText: hintText,
          ),
        ),
      ),
    );
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
