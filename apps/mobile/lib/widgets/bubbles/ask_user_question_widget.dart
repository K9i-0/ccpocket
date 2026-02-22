import 'dart:convert';

import 'package:expandable_page_view/expandable_page_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

const _buttonHeight = 44.0;

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
  final Map<int, String> _singleAnswers = {};
  final Map<int, Set<String>> _multiAnswers = {};
  final Map<int, TextEditingController> _customControllers = {};
  final Set<int> _customInputs = {};

  late final PageController _pageController;
  int _currentPage = 0;
  bool _answered = false;

  List<dynamic> get _questions =>
      widget.input['questions'] as List<dynamic>? ?? const [];

  bool get _isSingleQuestion => _questions.length <= 1;

  bool get _isMultiQuestion => _questions.length > 1;

  bool get _singleQuestionIsMultiSelect {
    if (!_isSingleQuestion || _questions.isEmpty) return false;
    final q = _questions.first as Map<String, dynamic>;
    return q['multiSelect'] as bool? ?? false;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    for (final c in _customControllers.values) {
      c.dispose();
    }
    _pageController.dispose();
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
    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i] as Map<String, dynamic>;
      final question = q['question'] as String? ?? '';
      final multiSelect = q['multiSelect'] as bool? ?? false;
      if (multiSelect) {
        final selected = _multiAnswers[i] ?? <String>{};
        final custom = _customControllers[i]?.text.trim() ?? '';
        final merged = <String>[...selected];
        if (custom.isNotEmpty) merged.add(custom);
        answers[question] = merged.join(', ');
      } else {
        answers[question] = _singleAnswers[i] ?? '';
      }
    }
    _sendAnswer(jsonEncode({'questions': _questions, 'answers': answers}));
  }

  bool get _allQuestionsAnswered {
    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i] as Map<String, dynamic>;
      final multiSelect = q['multiSelect'] as bool? ?? false;
      if (multiSelect) {
        final selected = _multiAnswers[i] ?? <String>{};
        final custom = _customControllers[i]?.text.trim() ?? '';
        if (selected.isEmpty && custom.isEmpty) return false;
      } else {
        final value = _singleAnswers[i]?.trim() ?? '';
        if (value.isEmpty) return false;
      }
    }
    return true;
  }

  TextEditingController _getOrCreateController(int questionIndex) {
    return _customControllers.putIfAbsent(
      questionIndex,
      () => TextEditingController(),
    );
  }

  void _onAnswerSingle(int questionIndex, String label) {
    HapticFeedback.selectionClick();
    final q = _questions[questionIndex] as Map<String, dynamic>;
    final isMulti = q['multiSelect'] as bool? ?? false;

    setState(() {
      _singleAnswers[questionIndex] = label;
      if (!isMulti) {
        _customControllers[questionIndex]?.clear();
      }
    });

    if (_isSingleQuestion && !isMulti) {
      _sendAnswer(label);
      return;
    }

    if (_isMultiQuestion && !isMulti) {
      final next = questionIndex + 1;
      if (next <= _questions.length) {
        _goToPage(next);
      }
    }
  }

  void _toggleMultiSelectLabel(int questionIndex, String label) {
    HapticFeedback.selectionClick();
    setState(() {
      final selected = _multiAnswers.putIfAbsent(questionIndex, () => {});
      if (selected.contains(label)) {
        selected.remove(label);
      } else {
        selected.add(label);
      }
      final customText = _customControllers[questionIndex]?.text.trim() ?? '';
      final parts = <String>[...selected];
      if (customText.isNotEmpty) {
        parts.add(customText);
      }
      _singleAnswers[questionIndex] = parts.join(', ');
    });
  }

  void _confirmMultiSelect(int questionIndex) {
    final selected = _multiAnswers[questionIndex] ?? <String>{};
    final customText = _customControllers[questionIndex]?.text.trim() ?? '';
    final parts = <String>[...selected];
    if (customText.isNotEmpty) {
      parts.add(customText);
    }
    final answer = parts.join(', ');
    if (answer.isEmpty) return;

    setState(() {
      _singleAnswers[questionIndex] = answer;
    });

    if (_isSingleQuestion) {
      _sendAllAnswers();
      return;
    }

    if (_currentPage < _questions.length) {
      _goToPage(_currentPage + 1);
    }
  }

  void _submitCustomText(int questionIndex) {
    final q = _questions[questionIndex] as Map<String, dynamic>;
    final isMulti = q['multiSelect'] as bool? ?? false;
    final customText = _customControllers[questionIndex]?.text.trim() ?? '';

    if (isMulti) {
      final selected = _multiAnswers[questionIndex] ?? <String>{};
      final parts = <String>[...selected];
      if (customText.isNotEmpty) {
        parts.add(customText);
      }
      if (parts.isEmpty) return;
      setState(() {
        _singleAnswers[questionIndex] = parts.join(', ');
      });
      if (_isSingleQuestion) {
        _sendAllAnswers();
      }
      return;
    }

    final answer = customText.isNotEmpty
        ? customText
        : (_singleAnswers[questionIndex]?.trim() ?? '');
    if (answer.isEmpty) return;

    setState(() {
      _singleAnswers[questionIndex] = answer;
    });

    if (_isSingleQuestion) {
      _sendAnswer(answer);
    }
  }

  void _onCustomTextChanged(int questionIndex, String text) {
    setState(() {
      final q = _questions[questionIndex] as Map<String, dynamic>;
      final isMulti = q['multiSelect'] as bool? ?? false;
      if (isMulti) {
        final selected = _multiAnswers[questionIndex] ?? <String>{};
        final parts = <String>[...selected];
        if (text.trim().isNotEmpty) {
          parts.add(text.trim());
        }
        _singleAnswers[questionIndex] = parts.join(', ');
      } else {
        _singleAnswers[questionIndex] = text.trim();
      }
    });
  }

  void _showCustomInput(int questionIndex) {
    setState(() {
      _customInputs.add(questionIndex);
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _resetAll() {
    setState(() {
      _singleAnswers.clear();
      _multiAnswers.clear();
      _customInputs.clear();
      for (final controller in _customControllers.values) {
        controller.clear();
      }
      _currentPage = 0;
    });
    _goToPage(0);
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
        child: SafeArea(
          top: false,
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
        ),
      );
    }

    final questions = _questions;
    if (questions.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalPages = _isMultiQuestion ? questions.length + 1 : 1;

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
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
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
                const Spacer(),
                if (_isMultiQuestion)
                  Text(
                    '${_currentPage + 1}/$totalPages',
                    style: TextStyle(fontSize: 11, color: appColors.subtleText),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isMultiQuestion) ...[
              LinearProgressIndicator(
                value: (_currentPage + 1) / totalPages,
                minHeight: 2,
                backgroundColor: appColors.askIcon.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(appColors.askIcon),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.42,
                ),
                child: ExpandablePageView.builder(
                  controller: _pageController,
                  itemCount: totalPages,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) {
                    if (index == questions.length) {
                      return _AskSummaryPage(
                        questions: questions,
                        singleAnswers: _singleAnswers,
                        onResetAll: _resetAll,
                        onSubmitAll: _sendAllAnswers,
                        onGoToPage: _goToPage,
                      );
                    }
                    return _AskQuestionLayout(
                      question: questions[index] as Map<String, dynamic>,
                      questionIndex: index,
                      isMultiQuestion: true,
                      singleAnswers: _singleAnswers,
                      multiAnswers: _multiAnswers,
                      customInputs: _customInputs,
                      getOrCreateController: _getOrCreateController,
                      onAnswerSingle: _onAnswerSingle,
                      onToggleMultiSelectLabel: _toggleMultiSelectLabel,
                      onConfirmMultiSelect: _confirmMultiSelect,
                      onSubmitCustomText: _submitCustomText,
                      onCustomTextChanged: _onCustomTextChanged,
                      onShowCustomInput: _showCustomInput,
                    );
                  },
                ),
              ),
            ] else ...[
              _AskQuestionLayout(
                question: questions.first as Map<String, dynamic>,
                questionIndex: 0,
                isMultiQuestion: false,
                singleAnswers: _singleAnswers,
                multiAnswers: _multiAnswers,
                customInputs: _customInputs,
                getOrCreateController: _getOrCreateController,
                onAnswerSingle: _onAnswerSingle,
                onToggleMultiSelectLabel: _toggleMultiSelectLabel,
                onConfirmMultiSelect: _confirmMultiSelect,
                onSubmitCustomText: _submitCustomText,
                onCustomTextChanged: _onCustomTextChanged,
                onShowCustomInput: _showCustomInput,
                alwaysShowTextInput: !_singleQuestionIsMultiSelect,
              ),
            ],
            if (_singleQuestionIsMultiSelect) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('ask_submit_multi_single_button'),
                  onPressed: _allQuestionsAnswered ? _sendAllAnswers : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text(
                    _allQuestionsAnswered
                        ? l.submitWithCount(_multiAnswers[0]?.length ?? 0)
                        : l.selectOptionsToSubmit,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AskQuestionLayout extends StatelessWidget {
  final Map<String, dynamic> question;
  final int questionIndex;
  final bool isMultiQuestion;
  final bool alwaysShowTextInput;
  final Map<int, String> singleAnswers;
  final Map<int, Set<String>> multiAnswers;
  final Set<int> customInputs;
  final TextEditingController Function(int) getOrCreateController;
  final void Function(int questionIndex, String label) onAnswerSingle;
  final void Function(int questionIndex, String label) onToggleMultiSelectLabel;
  final void Function(int questionIndex) onConfirmMultiSelect;
  final void Function(int questionIndex) onSubmitCustomText;
  final void Function(int questionIndex, String text) onCustomTextChanged;
  final void Function(int questionIndex) onShowCustomInput;

  const _AskQuestionLayout({
    required this.question,
    required this.questionIndex,
    required this.isMultiQuestion,
    required this.singleAnswers,
    required this.multiAnswers,
    required this.customInputs,
    required this.getOrCreateController,
    required this.onAnswerSingle,
    required this.onToggleMultiSelectLabel,
    required this.onConfirmMultiSelect,
    required this.onSubmitCustomText,
    required this.onCustomTextChanged,
    required this.onShowCustomInput,
    this.alwaysShowTextInput = false,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final l = AppLocalizations.of(context);

    final header = question['header'] as String?;
    final text = question['question'] as String? ?? '';
    final options = question['options'] as List<dynamic>? ?? const [];
    final isMulti = question['multiSelect'] as bool? ?? false;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (header != null && header.isNotEmpty)
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
          if (header != null && header.isNotEmpty) const SizedBox(height: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          if (isMulti) ...[
            const SizedBox(height: 2),
            Text(
              l.selectAllThatApply,
              style: TextStyle(fontSize: 11, color: appColors.subtleText),
            ),
          ],
          if (options.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final opt in options)
              if (opt is Map<String, dynamic>)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _AskOptionButton(
                    optionKey: ValueKey(
                      'ask_option_${questionIndex}_${opt['label'] as String? ?? ''}',
                    ),
                    label: opt['label'] as String? ?? '',
                    description: opt['description'] as String? ?? '',
                    isSelected: isMulti
                        ? (multiAnswers[questionIndex] ?? {}).contains(
                            opt['label'] as String? ?? '',
                          )
                        : singleAnswers[questionIndex] ==
                              (opt['label'] as String? ?? ''),
                    isMulti: isMulti,
                    onTap: () {
                      final label = opt['label'] as String? ?? '';
                      if (isMulti) {
                        onToggleMultiSelectLabel(questionIndex, label);
                      } else {
                        onAnswerSingle(questionIndex, label);
                      }
                    },
                  ),
                ),
          ],
          if (alwaysShowTextInput) ...[
            const SizedBox(height: 6),
            _AskTextInputRow(
              controller: getOrCreateController(questionIndex),
              hintText: l.typeYourAnswer,
              onChanged: (text) => onCustomTextChanged(questionIndex, text),
              onSubmitted: () => onSubmitCustomText(questionIndex),
              showSendButton: true,
            ),
          ] else ...[
            const SizedBox(height: 4),
            _AskOtherAnswerSection(
              questionIndex: questionIndex,
              isCustomInputShown: customInputs.contains(questionIndex),
              isMultiQuestion: isMultiQuestion,
              controller: getOrCreateController(questionIndex),
              onCustomTextChanged: onCustomTextChanged,
              onSubmitCustomText: onSubmitCustomText,
              onShowCustomInput: onShowCustomInput,
            ),
          ],
          if (isMulti && !isMultiQuestion) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: _buttonHeight,
              child: FilledButton.icon(
                onPressed:
                    (multiAnswers[questionIndex] ?? {}).isNotEmpty ||
                        (getOrCreateController(
                          questionIndex,
                        ).text.trim().isNotEmpty)
                    ? () => onConfirmMultiSelect(questionIndex)
                    : null,
                icon: const Icon(Icons.check, size: 16),
                label: Text(
                  l.submitWithCount((multiAnswers[questionIndex] ?? {}).length),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AskOptionButton extends StatelessWidget {
  final Key? optionKey;
  final String label;
  final String description;
  final bool isSelected;
  final bool isMulti;
  final VoidCallback onTap;

  const _AskOptionButton({
    this.optionKey,
    required this.label,
    required this.description,
    required this.isSelected,
    required this.isMulti,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;

    return Material(
      color: isSelected
          ? appColors.askIcon.withValues(alpha: 0.1)
          : Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: optionKey,
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: _buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? appColors.askIcon.withValues(alpha: 0.45)
                  : Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              if (isMulti) ...[
                Icon(
                  isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 18,
                  color: isSelected
                      ? appColors.askIcon
                      : appColors.subtleText.withValues(alpha: 0.8),
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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!isMulti) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: appColors.subtleText.withValues(alpha: 0.8),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AskOtherAnswerSection extends StatelessWidget {
  final int questionIndex;
  final bool isCustomInputShown;
  final bool isMultiQuestion;
  final TextEditingController controller;
  final void Function(int questionIndex, String text) onCustomTextChanged;
  final void Function(int questionIndex) onSubmitCustomText;
  final void Function(int questionIndex) onShowCustomInput;

  const _AskOtherAnswerSection({
    required this.questionIndex,
    required this.isCustomInputShown,
    required this.isMultiQuestion,
    required this.controller,
    required this.onCustomTextChanged,
    required this.onSubmitCustomText,
    required this.onShowCustomInput,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (isCustomInputShown) {
      return _AskTextInputRow(
        controller: controller,
        hintText: isMultiQuestion ? l.orTypeCustomAnswer : l.typeYourAnswer,
        onChanged: (text) => onCustomTextChanged(questionIndex, text),
        onSubmitted: () => onSubmitCustomText(questionIndex),
        showSendButton: !isMultiQuestion,
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () => onShowCustomInput(questionIndex),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(fontSize: 11),
        ),
        child: Text(l.otherAnswer),
      ),
    );
  }
}

class _AskTextInputRow extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback onSubmitted;
  final bool showSendButton;

  const _AskTextInputRow({
    required this.controller,
    required this.hintText,
    required this.onSubmitted,
    this.onChanged,
    this.showSendButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hintText,
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
            onSubmitted: (_) => onSubmitted(),
          ),
        ),
        if (showSendButton) ...[
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onSubmitted,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: Size.zero,
            ),
            child: Text(l.send, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ],
    );
  }
}

class _AskSummaryPage extends StatelessWidget {
  final List<dynamic> questions;
  final Map<int, String> singleAnswers;
  final ValueChanged<int> onGoToPage;
  final VoidCallback onResetAll;
  final VoidCallback onSubmitAll;

  const _AskSummaryPage({
    required this.questions,
    required this.singleAnswers,
    required this.onGoToPage,
    required this.onResetAll,
    required this.onSubmitAll,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.submitAllAnswers,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < questions.length; i++) ...[
            _AskSummaryRow(
              index: i,
              question: questions[i] as Map<String, dynamic>,
              answer: singleAnswers[i],
              onEdit: () => onGoToPage(i),
            ),
            if (i < questions.length - 1) const SizedBox(height: 6),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('ask_reset_button'),
                  onPressed: onResetAll,
                  child: Text(l.cancel),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('ask_submit_summary_button'),
                  onPressed: onSubmitAll,
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                  ),
                  child: Text(l.submitAllAnswers),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AskSummaryRow extends StatelessWidget {
  final int index;
  final Map<String, dynamic> question;
  final String? answer;
  final VoidCallback onEdit;

  const _AskSummaryRow({
    required this.index,
    required this.question,
    required this.answer,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final header = question['header'] as String? ?? 'Q${index + 1}';
    final displayAnswer = (answer != null && answer!.trim().isNotEmpty)
        ? answer!
        : '-';

    return Material(
      color: cs.surface.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      header,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(displayAnswer, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.edit_outlined, size: 16, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
