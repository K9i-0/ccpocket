import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
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
  bool _showCustomInput = false;

  // Per-question answer tracking
  // key: question text, value: selected label(s)
  final Map<String, String> _answers = {};
  final Map<String, Set<String>> _multiAnswers = {};

  List<dynamic> get _questions =>
      widget.input['questions'] as List<dynamic>? ?? [];

  bool get _isSingleQuestion => _questions.length <= 1;

  bool get _singleQuestionIsMultiSelect {
    if (!_isSingleQuestion || _questions.isEmpty) return false;
    final q = _questions.first as Map<String, dynamic>;
    return q['multiSelect'] as bool? ?? false;
  }

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

  void _sendAllAnswers() {
    if (_answered) return;
    final answers = <String, String>{};
    for (final q in _questions) {
      final question = (q as Map<String, dynamic>)['question'] as String? ?? '';
      final multiSelect = q['multiSelect'] as bool? ?? false;
      if (multiSelect) {
        final selected = _multiAnswers[question] ?? {};
        answers[question] = selected.toList().join(', ');
      } else {
        answers[question] = _answers[question] ?? '';
      }
    }
    _sendAnswer(jsonEncode({'questions': _questions, 'answers': answers}));
  }

  bool get _allQuestionsAnswered {
    for (final q in _questions) {
      final question = (q as Map<String, dynamic>)['question'] as String? ?? '';
      final multiSelect = q['multiSelect'] as bool? ?? false;
      if (multiSelect) {
        if ((_multiAnswers[question] ?? {}).isEmpty) return false;
      } else {
        if (!_answers.containsKey(question)) return false;
      }
    }
    return true;
  }

  void _selectOption(String question, String label, {required bool multi}) {
    HapticFeedback.selectionClick();
    setState(() {
      if (multi) {
        final set = _multiAnswers.putIfAbsent(question, () => {});
        if (set.contains(label)) {
          set.remove(label);
          if (set.isEmpty) _multiAnswers.remove(question);
        } else {
          set.add(label);
        }
      } else {
        if (_isSingleQuestion) {
          // Single question → send immediately
          _sendAnswer(label);
          return;
        }
        _answers[question] = label;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;

    final l = AppLocalizations.of(context);

    if (_answered) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              l.answered,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                padding: const EdgeInsets.all(3),
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
                l.claudeIsAsking,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: appColors.askIcon,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Questions (scrollable if many options)
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.35,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final q in _questions) ...[
                    _buildQuestion(q as Map<String, dynamic>, appColors),
                    const SizedBox(height: 6),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Submit button for multi-question mode or single multiSelect question
          if (!_isSingleQuestion) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _allQuestionsAnswered ? _sendAllAnswers : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text(
                  _allQuestionsAnswered
                      ? l.submitAllAnswers
                      : l.answerAllQuestionsToSubmit,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ] else if (_singleQuestionIsMultiSelect) ...[
            // Single question with multiSelect needs an explicit submit button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _allQuestionsAnswered ? _sendAllAnswers : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text(
                  _allQuestionsAnswered
                      ? l.submitWithCount(
                          _multiAnswers.values.firstOrNull?.length ?? 0,
                        )
                      : l.selectOptionsToSubmit,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
          // Free text input
          if (_isSingleQuestion && !_singleQuestionIsMultiSelect) ...[
            // Single question (single-select): always show text input
            _buildTextInputRow(),
          ] else ...[
            // Multi-question or single multiSelect: collapsible text input
            if (!_showCustomInput)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => _showCustomInput = true),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: appColors.subtleText,
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                  child: Text(l.otherAnswer),
                ),
              )
            else
              _buildTextInputRow(),
          ],
        ],
      ),
    );
  }

  Widget _buildTextInputRow() {
    final l = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _textController,
            decoration: InputDecoration(
              hintText: _isSingleQuestion
                  ? l.typeYourAnswer
                  : l.orTypeCustomAnswer,
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
        FilledButton(
          onPressed: () {
            final text = _textController.text.trim();
            if (text.isNotEmpty) {
              _sendAnswer(text);
            }
          },
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            minimumSize: Size.zero,
          ),
          child: Text(l.send, style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildQuestion(Map<String, dynamic> q, AppColors appColors) {
    final l = AppLocalizations.of(context);
    final header = q['header'] as String?;
    final question = q['question'] as String? ?? '';
    final options = q['options'] as List<dynamic>? ?? [];
    final multiSelect = q['multiSelect'] as bool? ?? false;

    final isAnswered = multiSelect
        ? (_multiAnswers[question] ?? {}).isNotEmpty
        : _answers.containsKey(question);
    final answerLabel = multiSelect
        ? (_multiAnswers[question] ?? {}).join(', ')
        : _answers[question];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header chip + answered indicator
        Row(
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
            ],
            if (!_isSingleQuestion && isAnswered) ...[
              const SizedBox(width: 6),
              Icon(Icons.check_circle, size: 14, color: Colors.green[400]),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  answerLabel ?? '',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.green[400],
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        if (header != null && header.isNotEmpty) const SizedBox(height: 4),
        Text(
          question,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        if (multiSelect) ...[
          const SizedBox(height: 2),
          Text(
            l.selectAllThatApply,
            style: TextStyle(fontSize: 11, color: appColors.subtleText),
          ),
        ],
        if (options.isNotEmpty) ...[
          const SizedBox(height: 6),
          for (final opt in options)
            _buildOptionTile(
              opt as Map<String, dynamic>,
              appColors,
              question: question,
              multiSelect: multiSelect,
            ),
        ],
      ],
    );
  }

  Widget _buildOptionTile(
    Map<String, dynamic> opt,
    AppColors appColors, {
    required String question,
    required bool multiSelect,
  }) {
    final label = opt['label'] as String? ?? '';
    final description = opt['description'] as String? ?? '';
    final isSelected = multiSelect
        ? (_multiAnswers[question] ?? {}).contains(label)
        : _answers[question] == label;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isSelected
            ? appColors.askIcon.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _selectOption(question, label, multi: multiSelect),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    size: 18,
                    color: isSelected
                        ? appColors.askIcon
                        : appColors.subtleText,
                  ),
                  const SizedBox(width: 8),
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
                if (!multiSelect && !isSelected)
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: appColors.subtleText,
                  ),
                if (!multiSelect && isSelected)
                  Icon(Icons.check_circle, size: 18, color: appColors.askIcon),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
