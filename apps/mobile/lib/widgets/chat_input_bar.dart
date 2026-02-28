import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/messages.dart';
import '../utils/diff_parser.dart';

/// Bottom input bar with slash-command button, text field, and action buttons.
///
/// Pure presentation — all actions are dispatched via callbacks.
class ChatInputBar extends StatelessWidget {
  final TextEditingController inputController;
  final ProcessStatus status;
  final bool hasInputText;
  final bool isVoiceAvailable;
  final bool isRecording;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onInterrupt;
  final VoidCallback onToggleVoice;
  final VoidCallback onShowSlashCommands;
  final VoidCallback onShowModeMenu;
  final bool showModeButton;
  final PermissionMode permissionMode;
  final SandboxMode? sandboxMode;
  final VoidCallback? onShowPromptHistory;
  final VoidCallback? onAttachImage;
  final List<({Uint8List bytes, String mimeType})> attachedImages;
  final void Function([int? index])? onClearImage;
  final DiffSelection? attachedDiffSelection;
  final VoidCallback? onClearDiffSelection;
  final VoidCallback? onTapDiffPreview;
  final String? hintText;

  const ChatInputBar({
    super.key,
    required this.inputController,
    required this.status,
    required this.hasInputText,
    required this.isVoiceAvailable,
    required this.isRecording,
    required this.onSend,
    required this.onStop,
    required this.onInterrupt,
    required this.onToggleVoice,
    required this.onShowSlashCommands,
    required this.onShowModeMenu,
    this.showModeButton = true,
    this.permissionMode = PermissionMode.defaultMode,
    this.sandboxMode,
    this.onShowPromptHistory,
    this.onAttachImage,
    this.attachedImages = const [],
    this.onClearImage,
    this.attachedDiffSelection,
    this.onClearDiffSelection,
    this.onTapDiffPreview,
    this.hintText,
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
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _SlashButton(onTap: onShowSlashCommands),
              if (showModeButton) ...[
                const SizedBox(width: 8),
                _ModeButton(
                  permissionMode: permissionMode,
                  onTap: onShowModeMenu,
                ),
              ],
              if (sandboxMode != null) ...[
                const SizedBox(width: 6),
                _SandboxModeBadge(mode: sandboxMode!),
              ],
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
              if (isVoiceAvailable) ...[
                const SizedBox(width: 8),
                _VoiceButton(isRecording: isRecording, onTap: onToggleVoice),
              ],
              const Spacer(),
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

class _SlashButton extends StatelessWidget {
  const _SlashButton({required this.onTap});
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
          key: const ValueKey('slash_command_button'),
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

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.permissionMode, required this.onTap});
  final PermissionMode permissionMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    final isDefault = permissionMode == PermissionMode.defaultMode;

    final (
      IconData icon,
      String? label,
      Color bg,
      Color fg,
    ) = switch (permissionMode) {
      PermissionMode.defaultMode => (
        Icons.tune,
        null,
        cs.surfaceContainerHigh,
        cs.primary,
      ),
      PermissionMode.plan => (
        Icons.assignment,
        'Plan',
        cs.tertiaryContainer,
        cs.onTertiaryContainer,
      ),
      PermissionMode.acceptEdits => (
        Icons.edit_note,
        'Edits',
        cs.primaryContainer,
        cs.onPrimaryContainer,
      ),
      PermissionMode.bypassPermissions => (
        Icons.flash_on,
        'Bypass',
        cs.errorContainer,
        cs.onErrorContainer,
      ),
    };

    return Tooltip(
      message: l.tooltipPermissionMode,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          key: const ValueKey('mode_button'),
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            height: 36,
            constraints: isDefault
                ? const BoxConstraints(minWidth: 36, maxWidth: 36)
                : const BoxConstraints(minWidth: 36),
            padding: isDefault
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            child: isDefault
                ? Icon(icon, size: 18, color: fg)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: fg),
                      const SizedBox(width: 4),
                      Text(
                        label!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: fg,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// _SandboxModeButton removed — sandbox is now a simple On/Off badge

/// Read-only sandbox mode badge displayed alongside the permission mode button
/// for Codex sessions.
class _SandboxModeBadge extends StatelessWidget {
  const _SandboxModeBadge({required this.mode});
  final SandboxMode mode;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final (IconData icon, String label, Color bg, Color fg) = switch (mode) {
      SandboxMode.on => (
        Icons.shield_outlined,
        'SB',
        cs.tertiaryContainer,
        cs.onTertiaryContainer,
      ),
      SandboxMode.off => (
        Icons.warning_amber,
        'No SB',
        cs.errorContainer,
        cs.onErrorContainer,
      ),
    };

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
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
                : Icon(Icons.attach_file, size: 18, color: cs.primary),
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    images[index].bytes,
                    height: 80,
                    width: images.length == 1 ? null : 80,
                    fit: BoxFit.cover,
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
    final parts = <String>[];

    // Build summary
    final summaryParts = <String>[];
    if (selection.mentions.isNotEmpty) {
      summaryParts.add(l.filesMentioned(selection.mentions.length));
    }
    if (selection.diffText.isNotEmpty) {
      final lineCount = selection.diffText.split('\n').length;
      summaryParts.add(l.diffLines(lineCount));
    }
    final summary = summaryParts.join(', ');

    // Build preview text
    if (selection.mentions.isNotEmpty) {
      parts.addAll(selection.mentions.map((f) => '@$f'));
    }
    if (selection.diffText.isNotEmpty) {
      parts.add(selection.diffText.split('\n').take(2).join('\n'));
    }
    final preview = parts.join('\n');

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
  });
  final TextEditingController controller;
  final ProcessStatus status;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return TextField(
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
      maxLines: 6,
      minLines: 1,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
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
