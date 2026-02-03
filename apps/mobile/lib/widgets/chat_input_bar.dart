import 'package:flutter/material.dart';

import '../models/messages.dart';

/// Bottom input bar with slash-command button, text field, and action buttons.
///
/// Pure presentation — all actions are dispatched via callbacks.
class ChatInputBar extends StatelessWidget {
  final TextEditingController inputController;
  final LayerLink inputLayerLink;
  final ProcessStatus status;
  final bool hasInputText;
  final bool isVoiceAvailable;
  final bool isRecording;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onInterrupt;
  final VoidCallback onToggleVoice;
  final VoidCallback onShowSlashCommands;
  final VoidCallback onExpand;

  const ChatInputBar({
    super.key,
    required this.inputController,
    required this.inputLayerLink,
    required this.status,
    required this.hasInputText,
    required this.isVoiceAvailable,
    required this.isRecording,
    required this.onSend,
    required this.onStop,
    required this.onInterrupt,
    required this.onToggleVoice,
    required this.onShowSlashCommands,
    required this.onExpand,
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
          _buildTextField(cs),
          const SizedBox(height: 4),
          Row(
            children: [
              _buildSlashButton(cs),
              const SizedBox(width: 8),
              if (status != ProcessStatus.starting) _buildExpandButton(cs),
              const Spacer(),
              _buildActionButton(cs),
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

  Widget _buildTextField(ColorScheme cs) {
    return CompositedTransformTarget(
      link: inputLayerLink,
      child: TextField(
        key: const ValueKey('message_input'),
        controller: inputController,
        decoration: InputDecoration(
          hintText: 'Message Claude...',
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
        textInputAction: TextInputAction.send,
        onSubmitted: (_) => onSend(),
      ),
    );
  }

  Widget _buildExpandButton(ColorScheme cs) {
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: const ValueKey('expand_compose_button'),
        borderRadius: BorderRadius.circular(20),
        onTap: onExpand,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(Icons.open_in_full, size: 16, color: cs.outline),
        ),
      ),
    );
  }

  Widget _buildActionButton(ColorScheme cs) {
    if (status == ProcessStatus.starting) {
      return _buildSendButton(cs, enabled: false);
    }
    if (status != ProcessStatus.idle && !hasInputText) {
      return _buildStopButton(cs);
    }
    if (!hasInputText && isVoiceAvailable) {
      return _buildVoiceButton(cs);
    }
    return _buildSendButton(cs);
  }

  Widget _buildStopButton(ColorScheme cs) {
    return Tooltip(
      message: 'Tap: interrupt, Hold: stop',
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
    return Container(
      decoration: BoxDecoration(
        color: isRecording ? cs.error : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: IconButton(
        key: const ValueKey('voice_button'),
        onPressed: onToggleVoice,
        icon: Icon(
          isRecording ? Icons.stop : Icons.mic,
          color: isRecording ? cs.onError : cs.primary,
          size: 20,
        ),
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        padding: EdgeInsets.zero,
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
