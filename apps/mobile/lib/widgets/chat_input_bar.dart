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
  final PermissionMode permissionMode;
  final SandboxMode? sandboxMode;
  final VoidCallback? onShowPromptHistory;
  final VoidCallback? onAttachImage;
  final Uint8List? attachedImageBytes;
  final VoidCallback? onClearAttachment;
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
    this.permissionMode = PermissionMode.defaultMode,
    this.sandboxMode,
    this.onShowPromptHistory,
    this.onAttachImage,
    this.attachedImageBytes,
    this.onClearAttachment,
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
          if (attachedDiffSelection != null) _buildDiffPreview(context, cs),
          if (attachedImageBytes != null) _buildImagePreview(cs),
          _buildTextField(context, cs),
          const SizedBox(height: 4),
          Row(
            children: [
              _buildSlashButton(cs),
              const SizedBox(width: 8),
              _buildModeButton(cs),
              const SizedBox(width: 8),
              _buildAttachButton(cs),
              if (onShowPromptHistory != null) ...[
                const SizedBox(width: 8),
                _buildHistoryButton(cs),
              ],
              if (isVoiceAvailable) ...[
                const SizedBox(width: 8),
                _buildVoiceButton(cs),
              ],
              const Spacer(),
              _buildActionButton(context, cs),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlashButton(ColorScheme cs) {
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: const ValueKey('slash_command_button'),
        borderRadius: BorderRadius.circular(20),
        onTap: onShowSlashCommands,
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
    );
  }

  Widget _buildModeButton(ColorScheme cs) {
    // Codex: show sandbox mode badge
    if (sandboxMode != null) {
      return _buildSandboxModeButton(cs);
    }

    // Claude: show permission mode badge
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

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: const ValueKey('mode_button'),
        borderRadius: BorderRadius.circular(20),
        onTap: onShowModeMenu,
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
    );
  }

  Widget _buildSandboxModeButton(ColorScheme cs) {
    final mode = sandboxMode!;
    final isDefault = mode == SandboxMode.workspaceWrite;

    final (IconData icon, String? label, Color bg, Color fg) = switch (mode) {
      SandboxMode.workspaceWrite => (
        Icons.tune,
        null,
        cs.surfaceContainerHigh,
        cs.primary,
      ),
      SandboxMode.readOnly => (
        Icons.visibility,
        'Read',
        cs.tertiaryContainer,
        cs.onTertiaryContainer,
      ),
      SandboxMode.dangerFullAccess => (
        Icons.warning_amber,
        'Full',
        cs.errorContainer,
        cs.onErrorContainer,
      ),
    };

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: const ValueKey('mode_button'),
        borderRadius: BorderRadius.circular(20),
        onTap: onShowModeMenu,
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
    );
  }

  Widget _buildAttachButton(ColorScheme cs) {
    final hasAttachment = attachedImageBytes != null;
    return Material(
      color: hasAttachment ? cs.primaryContainer : cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: const ValueKey('attach_image_button'),
        borderRadius: BorderRadius.circular(20),
        onTap: onAttachImage,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Icon(
            hasAttachment ? Icons.image : Icons.attach_file,
            size: 18,
            color: hasAttachment ? cs.onPrimaryContainer : cs.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryButton(ColorScheme cs) {
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: const ValueKey('prompt_history_button'),
        borderRadius: BorderRadius.circular(20),
        onTap: onShowPromptHistory,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Icon(Icons.history, size: 18, color: cs.primary),
        ),
      ),
    );
  }

  Widget _buildImagePreview(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              attachedImageBytes!,
              height: 80,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onClearAttachment,
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
    );
  }

  Widget _buildDiffPreview(BuildContext context, ColorScheme cs) {
    final l = AppLocalizations.of(context);
    final sel = attachedDiffSelection!;
    final parts = <String>[];

    // Build summary
    final summaryParts = <String>[];
    if (sel.mentions.isNotEmpty) {
      summaryParts.add(l.filesMentioned(sel.mentions.length));
    }
    if (sel.diffText.isNotEmpty) {
      final lineCount = sel.diffText.split('\n').length;
      summaryParts.add(l.diffLines(lineCount));
    }
    final summary = summaryParts.join(', ');

    // Build preview text
    if (sel.mentions.isNotEmpty) {
      parts.addAll(sel.mentions.map((f) => '@$f'));
    }
    if (sel.diffText.isNotEmpty) {
      parts.add(sel.diffText.split('\n').take(2).join('\n'));
    }
    final preview = parts.join('\n');

    return GestureDetector(
      onTap: onTapDiffPreview,
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
            GestureDetector(
              onTap: onClearDiffSelection,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(BuildContext context, ColorScheme cs) {
    final l = AppLocalizations.of(context);
    return TextField(
      key: const ValueKey('message_input'),
      controller: inputController,
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

  Widget _buildActionButton(BuildContext context, ColorScheme cs) {
    if (status == ProcessStatus.starting) {
      return _buildSendButton(cs, enabled: false);
    }
    if (status != ProcessStatus.idle && !hasInputText) {
      return _buildStopButton(context, cs);
    }
    return _buildSendButton(cs, enabled: hasInputText);
  }

  Widget _buildStopButton(BuildContext context, ColorScheme cs) {
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

  Widget _buildVoiceButton(ColorScheme cs) {
    return Material(
      color: isRecording ? cs.error : cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: const ValueKey('voice_button'),
        borderRadius: BorderRadius.circular(20),
        onTap: onToggleVoice,
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
    );
  }

  Widget _buildSendButton(ColorScheme cs, {bool enabled = true}) {
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
          onPressed: enabled ? onSend : null,
          icon: Icon(Icons.arrow_upward, color: cs.onPrimary, size: 20),
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
