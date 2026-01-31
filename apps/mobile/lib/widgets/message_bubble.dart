import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/messages.dart';

class ChatEntryWidget extends StatelessWidget {
  final ChatEntry entry;
  const ChatEntryWidget({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    return switch (entry) {
      ServerChatEntry(:final message) => ServerMessageWidget(message: message),
      UserChatEntry(:final text) => _UserBubble(text: text),
    };
  }
}

class ServerMessageWidget extends StatelessWidget {
  final ServerMessage message;
  const ServerMessageWidget({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return switch (message) {
      SystemMessage() => _SystemChip(message: message as SystemMessage),
      AssistantServerMessage() =>
        _AssistantBubble(message: message as AssistantServerMessage),
      ToolResultMessage() =>
        _ToolResultBubble(message: message as ToolResultMessage),
      ResultMessage() => _ResultChip(message: message as ResultMessage),
      ErrorMessage() => _ErrorBubble(message: message as ErrorMessage),
      StatusMessage() => _StatusChip(message: message as StatusMessage),
      HistoryMessage() => const SizedBox.shrink(),
    };
  }
}

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  final AssistantServerMessage message;
  const _AssistantBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final content in message.message.content)
          switch (content) {
            TextContent(:final text) => Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  margin:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SelectableText(text),
                ),
              ),
            ToolUseContent(:final name, :final input) => _ToolUseTile(
                name: name,
                input: input,
              ),
          },
      ],
    );
  }
}

class _ToolUseTile extends StatelessWidget {
  final String name;
  final Map<String, dynamic> input;
  const _ToolUseTile({required this.name, required this.input});

  @override
  Widget build(BuildContext context) {
    final inputStr = const JsonEncoder.withIndent('  ').convert(input);
    final preview =
        inputStr.length > 200 ? '${inputStr.substring(0, 200)}...' : inputStr;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.build, size: 16, color: Colors.orange),
              const SizedBox(width: 6),
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            preview,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolResultBubble extends StatefulWidget {
  final ToolResultMessage message;
  const _ToolResultBubble({required this.message});

  @override
  State<_ToolResultBubble> createState() => _ToolResultBubbleState();
}

class _ToolResultBubbleState extends State<_ToolResultBubble> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final content = widget.message.content;
    final preview = content.length > 100
        ? '${content.substring(0, 100)}...'
        : content;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Tool Result',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              if (_expanded)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: SelectableText(
                    content,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Colors.grey.shade800,
                    ),
                  ),
                )
              else
                Text(
                  preview,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SystemChip extends StatelessWidget {
  final SystemMessage message;
  const _SystemChip({required this.message});

  @override
  Widget build(BuildContext context) {
    final label = message.model != null
        ? 'Session started (${message.model})'
        : 'System: ${message.subtype}';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Chip(
          label: Text(label, style: const TextStyle(fontSize: 12)),
          backgroundColor: Colors.blue.shade50,
          side: BorderSide.none,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

class _ResultChip extends StatelessWidget {
  final ResultMessage message;
  const _ResultChip({required this.message});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (message.cost != null) {
      parts.add('\$${message.cost!.toStringAsFixed(4)}');
    }
    if (message.duration != null) {
      parts.add('${(message.duration! / 1000).toStringAsFixed(1)}s');
    }
    final label = message.subtype == 'success'
        ? 'Done${parts.isNotEmpty ? ' (${parts.join(", ")})' : ''}'
        : 'Error: ${message.error ?? 'unknown'}';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Chip(
          label: Text(label, style: const TextStyle(fontSize: 12)),
          backgroundColor: message.subtype == 'success'
              ? Colors.green.shade50
              : Colors.red.shade50,
          side: BorderSide.none,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

class _ErrorBubble extends StatelessWidget {
  final ErrorMessage message;
  const _ErrorBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message.message,
              style: TextStyle(color: Colors.red.shade800, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final StatusMessage message;
  const _StatusChip({required this.message});

  @override
  Widget build(BuildContext context) {
    // Don't render individual status messages as they're shown in the AppBar
    return const SizedBox.shrink();
  }
}
