import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../utils/platform_helper.dart';
import '../models/messages.dart';
import '../utils/diff_parser.dart';
import 'bubbles/image_preview.dart';

/// Bottom input bar with slash-command button, text field, and action buttons.
///
/// Pure presentation — all actions are dispatched via callbacks.
///
/// Desktop keyboard shortcuts (handled in [_InputTextField]):
/// - Tab: indent current line(s)
/// - Shift+Tab: dedent current line(s)
class ChatInputBar extends StatelessWidget {
  final TextEditingController inputController;
  final ProcessStatus status;
  final bool hasInputText;
  final bool isInputEmpty;
  final bool isVoiceAvailable;
  final bool isRecording;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onInterrupt;
  final VoidCallback onToggleVoice;
  final VoidCallback onIndent;
  final VoidCallback onDedent;
  final bool canDedent;
  final VoidCallback onSlashCommand;
  final VoidCallback onMention;
  final bool isInMentionContext;
  final VoidCallback? onShowPromptHistory;
  final VoidCallback? onAttachImage;
  final List<({Uint8List bytes, String mimeType})> attachedImages;
  final void Function([int? index])? onClearImage;
  final DiffSelection? attachedDiffSelection;
  final VoidCallback? onClearDiffSelection;
  final VoidCallback? onTapDiffPreview;
  final String? hintText;

  /// Callback to paste an image from clipboard (desktop only).
  /// When set, Cmd/Ctrl+V will attempt image paste before text paste.
  /// Returns true if an image was found and pasted.
  final Future<bool> Function()? onPasteImage;

  const ChatInputBar({
    super.key,
    required this.inputController,
    required this.status,
    required this.hasInputText,
    this.isInputEmpty = true,
    required this.isVoiceAvailable,
    required this.isRecording,
    required this.onSend,
    required this.onStop,
    required this.onInterrupt,
    required this.onToggleVoice,
    required this.onIndent,
    required this.onDedent,
    this.canDedent = true,
    required this.onSlashCommand,
    required this.onMention,
    this.isInMentionContext = false,
    this.onShowPromptHistory,
    this.onAttachImage,
    this.attachedImages = const [],
    this.onClearImage,
    this.attachedDiffSelection,
    this.onClearDiffSelection,
    this.onTapDiffPreview,
    this.hintText,
    this.onPasteImage,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (attachedDiffSelection != null)
            _DiffPreview(
              selection: attachedDiffSelection!,
              onTap: onTapDiffPreview,
              onClear: onClearDiffSelection,
            ),
          if (attachedImages.isNotEmpty)
            _ImagePreview(images: attachedImages, onClearImage: onClearImage),
          _InputTextField(
            controller: inputController,
            status: status,
            hintText: hintText,
            onSend: onSend,
            hasInputText: hasInputText,
            onPasteImage: onPasteImage,
            onIndent: onIndent,
            onDedent: onDedent,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isInputEmpty
                    ? _SlashCommandButton(
                        key: const ValueKey('slash_command_button'),
                        onTap: onSlashCommand,
                      )
                    : _DedentButton(
                        key: const ValueKey('dedent_button'),
                        onTap: onDedent,
                        enabled: canDedent,
                      ),
              ),
              const SizedBox(width: 8),
              _IndentButton(onTap: onIndent),
              const SizedBox(width: 8),
              _MentionButton(onTap: onMention, enabled: !isInMentionContext),
              const SizedBox(width: 8),
              _AttachButton(
                hasAttachment: attachedImages.isNotEmpty,
                imageCount: attachedImages.length,
                onTap: onAttachImage,
              ),
              if (onShowPromptHistory != null) ...[
                const SizedBox(width: 8),
                _HistoryButton(onTap: onShowPromptHistory!),
              ],
              const Spacer(),
              if (isVoiceAvailable) ...[
                _VoiceButton(isRecording: isRecording, onTap: onToggleVoice),
                const SizedBox(width: 8),
              ],
              _ActionButton(
                status: status,
                hasInputText: hasInputText,
                onSend: onSend,
                onStop: onStop,
                onInterrupt: onInterrupt,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IndentButton extends StatelessWidget {
  const _IndentButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return Tooltip(
      message: l.tooltipIndent,
      child: Material(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          key: const ValueKey('indent_button'),
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            child: Icon(
              Icons.format_indent_increase,
              size: 18,
              color: cs.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _DedentButton extends StatelessWidget {
  const _DedentButton({super.key, required this.onTap, required this.enabled});
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return Tooltip(
      message: l.tooltipDedent,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Material(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: enabled ? onTap : null,
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              child: Icon(
                Icons.format_indent_decrease,
                size: 18,
                color: cs.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SlashCommandButton extends StatelessWidget {
  const _SlashCommandButton({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return Tooltip(
      message: l.tooltipSlashCommand,
      child: Material(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            child: Text(
              '/',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MentionButton extends StatelessWidget {
  const _MentionButton({required this.onTap, required this.enabled});
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return Tooltip(
      message: l.tooltipMention,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Material(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            key: const ValueKey('mention_button'),
            borderRadius: BorderRadius.circular(20),
            onTap: enabled ? onTap : null,
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              child: Text(
                '@',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AttachButton extends StatelessWidget {
  const _AttachButton({
    required this.hasAttachment,
    required this.imageCount,
    required this.onTap,
  });
  final bool hasAttachment;
  final int imageCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return Tooltip(
      message: l.tooltipAttachImage,
      child: Material(
        color: hasAttachment ? cs.primaryContainer : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          key: const ValueKey('attach_image_button'),
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            child: hasAttachment
                ? Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(Icons.image, size: 18, color: cs.onPrimaryContainer),
                      if (imageCount > 1)
                        Positioned(
                          top: -6,
                          right: -8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$imageCount',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: cs.onPrimary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  )
                : Icon(Icons.image_outlined, size: 18, color: cs.primary),
          ),
        ),
      ),
    );
  }
}

class _HistoryButton extends StatelessWidget {
  const _HistoryButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return Tooltip(
      message: l.tooltipPromptHistory,
      child: Material(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          key: const ValueKey('prompt_history_button'),
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            child: Icon(Icons.history, size: 18, color: cs.primary),
          ),
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.images, required this.onClearImage});
  final List<({Uint8List bytes, String mimeType})> images;
  final void Function([int? index])? onClearImage;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        height: 80,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: images.length,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (context, index) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          FullScreenImageViewer(bytes: images[index].bytes),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      images[index].bytes,
                      height: 80,
                      width: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Tooltip(
                    message: l.tooltipRemoveImage,
                    child: GestureDetector(
                      onTap: () => onClearImage?.call(index),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DiffPreview extends StatelessWidget {
  const _DiffPreview({
    required this.selection,
    required this.onTap,
    required this.onClear,
  });
  final DiffSelection selection;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final previewSummary = summarizeDiffSelection(selection.diffText);
    final summaryParts = <String>[];
    if (previewSummary.changedLineCount > 0) {
      summaryParts.add(l.changedLines(previewSummary.changedLineCount));
    }
    if (previewSummary.hunkCount > 0) {
      summaryParts.add(l.hunkCount(previewSummary.hunkCount));
    } else if (previewSummary.fileCount > 0) {
      summaryParts.add(l.fileCount(previewSummary.fileCount));
    }

    final summary = summaryParts.isNotEmpty
        ? summaryParts.join(' · ')
        : l.fileCount(
            previewSummary.fileCount > 0 ? previewSummary.fileCount : 1,
          );

    final previewLines = <String>[];
    final filePath = previewSummary.primaryFilePath;
    if (filePath != null && filePath.isNotEmpty) {
      previewLines.add(filePath);
    }
    final hunkHeader = previewSummary.primaryHunkHeader;
    if (hunkHeader != null && hunkHeader.isNotEmpty) {
      previewLines.add(hunkHeader);
    }
    if (previewLines.isEmpty) {
      previewLines.add(summary);
    }
    final preview = previewLines.join('\n');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.difference, size: 20, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: l.tooltipClearDiff,
              child: GestureDetector(
                onTap: onClear,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputTextField extends StatelessWidget {
  const _InputTextField({
    required this.controller,
    required this.status,
    this.hintText,
    required this.onSend,
    required this.hasInputText,
    this.onPasteImage,
    this.onIndent,
    this.onDedent,
  });
  final TextEditingController controller;
  final ProcessStatus status;
  final String? hintText;
  final VoidCallback onSend;
  final bool hasInputText;

  /// Callback to paste an image from clipboard.
  /// Called on Cmd/Ctrl+V; should check clipboard for images and fall back
  /// to text paste if no image is found. Returns true if an image was pasted.
  final Future<bool> Function()? onPasteImage;

  /// Callback for Tab key (indent).
  final VoidCallback? onIndent;

  /// Callback for Shift+Tab key (dedent).
  final VoidCallback? onDedent;

  /// On desktop: Enter sends, Shift+Enter inserts newline,
  /// Tab indents, Shift+Tab dedents.
  /// Cmd/Ctrl+V: attempt image paste, fall back to text paste.
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!isDesktopPlatform) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    // Cmd+V (macOS) or Ctrl+V (Windows/Linux): try image paste first
    final isModifier =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    if (onPasteImage != null &&
        event.logicalKey == LogicalKeyboardKey.keyV &&
        isModifier &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _handlePaste();
      return KeyEventResult.handled;
    }

    // Tab / Shift+Tab: indent / dedent (IDE-like)
    if (event.logicalKey == LogicalKeyboardKey.tab && !isModifier) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        onDedent?.call();
      } else {
        onIndent?.call();
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey != LogicalKeyboardKey.enter) {
      return KeyEventResult.ignored;
    }
    // IME変換中はEnterを無視（変換確定に使われるため）
    if (controller.value.composing.isValid) {
      return KeyEventResult.ignored;
    }
    final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
    if (isShiftPressed) {
      // Shift+Enter: let TextField handle newline insertion
      return KeyEventResult.ignored;
    }
    // Enter without Shift: send message
    if (hasInputText) {
      onSend();
    }
    return KeyEventResult.handled;
  }

  Future<void> _handlePaste() async {
    // Try image paste first
    final pasted = await onPasteImage!();
    if (pasted) return;

    // Fall back to text paste from system clipboard
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      final text = controller.text;
      final selection = controller.selection;
      final start = selection.start < 0 ? text.length : selection.start;
      final end = selection.end < 0 ? text.length : selection.end;
      final newText =
          text.substring(0, start) + data.text! + text.substring(end);
      final newCursor = start + data.text!.length;
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursor),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return Focus(
      onKeyEvent: _handleKeyEvent,
      child: TextField(
        key: const ValueKey('message_input'),
        controller: controller,
        decoration: InputDecoration(
          hintText: hintText ?? l.messagePlaceholder,
          filled: true,
          fillColor: cs.surfaceContainerLow,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: cs.outlineVariant, width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(
              color: cs.primary.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
        ),
        enabled: status != ProcessStatus.starting,
        autofillHints: null,
        maxLines: 6,
        minLines: 1,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.status,
    required this.hasInputText,
    required this.onSend,
    required this.onStop,
    required this.onInterrupt,
  });
  final ProcessStatus status;
  final bool hasInputText;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onInterrupt;

  @override
  Widget build(BuildContext context) {
    if (status == ProcessStatus.starting) {
      return _SendButton(onSend: onSend, enabled: false);
    }
    if (status != ProcessStatus.idle && !hasInputText) {
      return _StopButton(onInterrupt: onInterrupt, onStop: onStop);
    }
    return _SendButton(onSend: onSend, enabled: hasInputText);
  }
}

class _StopButton extends StatelessWidget {
  const _StopButton({required this.onInterrupt, required this.onStop});
  final VoidCallback onInterrupt;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return Tooltip(
      message: l.tapInterruptHoldStop,
      child: Material(
        color: cs.error,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          key: const ValueKey('stop_button'),
          onTap: onInterrupt,
          onLongPress: onStop,
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(Icons.stop_rounded, color: cs.onError, size: 20),
          ),
        ),
      ),
    );
  }
}

class _VoiceButton extends StatelessWidget {
  const _VoiceButton({required this.isRecording, required this.onTap});
  final bool isRecording;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return Tooltip(
      message: isRecording ? l.tooltipStopRecording : l.tooltipVoiceInput,
      child: Material(
        color: isRecording ? cs.error : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          key: const ValueKey('voice_button'),
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            child: Icon(
              isRecording ? Icons.stop : Icons.mic,
              size: 18,
              color: isRecording ? cs.onError : cs.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.onSend, this.enabled = true});
  final VoidCallback onSend;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final opacity = enabled ? 1.0 : 0.4;
    return Opacity(
      opacity: opacity,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [cs.primary, cs.primary.withValues(alpha: 0.8)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: IconButton(
          key: const ValueKey('send_button'),
          tooltip: l.tooltipSendMessage,
          onPressed: enabled ? onSend : null,
          icon: Icon(Icons.arrow_upward, color: cs.onPrimary, size: 20),
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
