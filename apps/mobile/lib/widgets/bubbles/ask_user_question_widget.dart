import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';

class AskUserQuestionWidget extends StatefulWidget {
  final String toolUseId;
  final Map<String, dynamic> input;
  final void Function(String toolUseId, String result) onAnswer;

  const AskUserQuestionWidget({
    super.key,
    required this.toolUseId,
    required this.input,
    required this.onAnswer,
  });

  @override
  State<AskUserQuestionWidget> createState() => _AskUserQuestionWidgetState();
}

class _AskUserQuestionWidgetState extends State<AskUserQuestionWidget> {
  final TextEditingController _textController = TextEditingController();
  bool _answered = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _sendAnswer(String answer) {
    if (_answered) return;
    setState(() => _answered = true);
    widget.onAnswer(widget.toolUseId, answer);
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final questions = widget.input['questions'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: AppSpacing.bubbleMarginV,
        horizontal: AppSpacing.bubbleMarginH,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appColors.askBubble,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: appColors.askBubbleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline, size: 16, color: appColors.askIcon),
              const SizedBox(width: 6),
              Text(
                'Claude is asking',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: appColors.askIcon,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final q in questions) ...[
            _buildQuestion(q as Map<String, dynamic>),
            const SizedBox(height: 8),
          ],
          if (!_answered) ...[
            const Divider(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'Type your answer...',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    style: const TextStyle(fontSize: 13),
                    onSubmitted: (text) {
                      if (text.trim().isNotEmpty) {
                        _sendAnswer(text.trim());
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, size: 20),
                  onPressed: () {
                    final text = _textController.text.trim();
                    if (text.isNotEmpty) {
                      _sendAnswer(text);
                    }
                  },
                ),
              ],
            ),
          ] else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'Answered',
                  style: TextStyle(
                    color: appColors.subtleText,
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuestion(Map<String, dynamic> q) {
    final question = q['question'] as String? ?? '';
    final options = q['options'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        if (options.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final opt in options)
                _buildOptionButton(opt as Map<String, dynamic>),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildOptionButton(Map<String, dynamic> opt) {
    final label = opt['label'] as String? ?? '';
    final description = opt['description'] as String? ?? '';

    return Tooltip(
      message: description,
      child: OutlinedButton(
        onPressed: _answered ? null : () => _sendAnswer(label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          textStyle: const TextStyle(fontSize: 12),
          visualDensity: VisualDensity.compact,
        ),
        child: Text(label),
      ),
    );
  }
}
