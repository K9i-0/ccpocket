import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final Set<String> _selectedLabels = {};

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _sendAnswer(String answer) {
    if (_answered) return;
    HapticFeedback.mediumImpact();
    setState(() => _answered = true);
    widget.onAnswer(widget.toolUseId, answer);
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final questions = widget.input['questions'] as List<dynamic>? ?? [];

    if (_answered) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: appColors.askBubble.withValues(alpha: 0.5),
          border: Border(
            top: BorderSide(
              color: appColors.askBubbleBorder.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 16,
              color: appColors.subtleText,
            ),
            const SizedBox(width: 6),
            Text(
              'Answered',
              style: TextStyle(
                color: appColors.subtleText,
                fontStyle: FontStyle.italic,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            appColors.askBubble,
            appColors.askBubble.withValues(alpha: 0.7),
          ],
        ),
        border: Border(
          top: BorderSide(color: appColors.askBubbleBorder, width: 1.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: appColors.askIcon.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.help_outline,
                  size: 18,
                  color: appColors.askIcon,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Claude is asking',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: appColors.askIcon,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Questions (scrollable if many options)
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final q in questions) ...[
                    _buildQuestion(q as Map<String, dynamic>, appColors),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Free text input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    hintText: 'Type your answer...',
                    filled: true,
                    fillColor: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
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
              FilledButton(
                onPressed: () {
                  final text = _textController.text.trim();
                  if (text.isNotEmpty) {
                    _sendAnswer(text);
                  }
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  minimumSize: Size.zero,
                ),
                child: const Text('Send', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion(Map<String, dynamic> q, AppColors appColors) {
    final header = q['header'] as String?;
    final question = q['question'] as String? ?? '';
    final options = q['options'] as List<dynamic>? ?? [];
    final multiSelect = q['multiSelect'] as bool? ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null && header.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: appColors.askIcon.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              header,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: appColors.askIcon,
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          question,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        if (options.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final opt in options)
            _buildOptionTile(
              opt as Map<String, dynamic>,
              appColors,
              multiSelect: multiSelect,
            ),
          if (multiSelect && _selectedLabels.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () =>
                    _sendAnswer(_selectedLabels.toList().join(', ')),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  'Submit (${_selectedLabels.length} selected)',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildOptionTile(
    Map<String, dynamic> opt,
    AppColors appColors, {
    required bool multiSelect,
  }) {
    final label = opt['label'] as String? ?? '';
    final description = opt['description'] as String? ?? '';
    final isSelected = _selectedLabels.contains(label);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: isSelected
            ? appColors.askIcon.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            if (multiSelect) {
              HapticFeedback.selectionClick();
              setState(() {
                if (isSelected) {
                  _selectedLabels.remove(label);
                } else {
                  _selectedLabels.add(label);
                }
              });
            } else {
              _sendAnswer(label);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? appColors.askIcon.withValues(alpha: 0.4)
                    : Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                if (multiSelect) ...[
                  Icon(
                    isSelected
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    size: 20,
                    color: isSelected
                        ? appColors.askIcon
                        : appColors.subtleText,
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? appColors.askIcon : null,
                        ),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 11,
                            color: appColors.subtleText,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (!multiSelect)
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: appColors.subtleText,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
