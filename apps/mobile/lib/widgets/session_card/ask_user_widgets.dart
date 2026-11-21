import 'package:expandable_page_view/expandable_page_view.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';

/// Shared layout constant for AskUserArea buttons.
const sessionCardButtonHeight = 44.0;

/// Displays the question text from a question map.
class SessionCardQuestionText extends StatelessWidget {
  final Map<String, dynamic> question;

  const SessionCardQuestionText({super.key, required this.question});

  @override
  Widget build(BuildContext context) {
    final text = question['question'] as String? ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Single-select option chips for a question.
class _SingleSelectChips extends StatelessWidget {
  final int questionIndex;
  final List<dynamic> options;
  final String? selectedLabel;
  final Color statusColor;
  final void Function(int questionIndex, String label) onAnswerSingle;

  const _SingleSelectChips({
    required this.questionIndex,
    required this.options,
    required this.selectedLabel,
    required this.statusColor,
    required this.onAnswerSingle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final opt in options)
          if (opt is Map<String, dynamic>)
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Builder(
                builder: (context) {
                  final label = opt['label'] as String? ?? '';
                  final value = opt['value'] as String? ?? label;
                  final isChosen = selectedLabel == value;
                  return OutlinedButton.icon(
                    onPressed: () => onAnswerSingle(questionIndex, value),
                    icon: isChosen
                        ? Icon(Icons.check_circle, size: 16, color: statusColor)
                        : const SizedBox.shrink(),
                    label: Text(label, style: const TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      minimumSize: const Size(0, sessionCardButtonHeight),
                      foregroundColor: statusColor,
                      backgroundColor: isChosen
                          ? statusColor.withValues(alpha: 0.15)
                          : Colors.transparent,
                      side: BorderSide(
                        color: statusColor.withValues(
                          alpha: isChosen ? 0.6 : 0.3,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                },
              ),
            ),
      ],
    );
  }
}

/// Multi-select option chips for a question.
class _MultiSelectChips extends StatelessWidget {
  final int questionIndex;
  final List<dynamic> options;
  final Set<String> selected;
  final Color statusColor;
  final void Function(int questionIndex, String label) onToggleLabel;

  const _MultiSelectChips({
    required this.questionIndex,
    required this.options,
    required this.selected,
    required this.statusColor,
    required this.onToggleLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final opt in options)
          if (opt is Map<String, dynamic>)
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Builder(
                builder: (context) {
                  final label = opt['label'] as String? ?? '';
                  final value = opt['value'] as String? ?? label;
                  final isSelected = selected.contains(value);
                  return OutlinedButton.icon(
                    onPressed: () => onToggleLabel(questionIndex, value),
                    icon: Icon(
                      isSelected
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 18,
                      color: isSelected
                          ? statusColor
                          : statusColor.withValues(alpha: 0.5),
                    ),
                    label: Text(label, style: const TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      minimumSize: const Size(0, sessionCardButtonHeight),
                      alignment: Alignment.centerLeft,
                      foregroundColor: statusColor,
                      backgroundColor: isSelected
                          ? statusColor.withValues(alpha: 0.15)
                          : Colors.transparent,
                      side: BorderSide(
                        color: statusColor.withValues(
                          alpha: isSelected ? 0.6 : 0.3,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                },
              ),
            ),
      ],
    );
  }
}

/// Confirm button for multi-select (used in single-question mode).
class _ConfirmButton extends StatelessWidget {
  final int questionIndex;
  final Set<String> selected;
  final Color statusColor;
  final void Function(int questionIndex) onConfirmMultiSelect;

  const _ConfirmButton({
    required this.questionIndex,
    required this.selected,
    required this.statusColor,
    required this.onConfirmMultiSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: SizedBox(
        width: double.infinity,
        height: sessionCardButtonHeight,
        child: FilledButton.icon(
          onPressed: selected.isNotEmpty
              ? () => onConfirmMultiSelect(questionIndex)
              : null,
          icon: const Icon(Icons.check, size: 16),
          label: Text('Confirm (${selected.length})'),
          style: FilledButton.styleFrom(
            textStyle: const TextStyle(fontSize: 13),
            backgroundColor: statusColor.withValues(alpha: 0.15),
            foregroundColor: statusColor,
            disabledBackgroundColor: statusColor.withValues(alpha: 0.05),
            disabledForegroundColor: statusColor.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Other answer..." toggle button + inline text field.
class _OtherAnswerSection extends StatelessWidget {
  final int questionIndex;
  final bool isCustomInputShown;
  final bool isMultiQuestion;
  final Color statusColor;
  final TextEditingController controller;
  final void Function(int questionIndex, String text) onCustomTextChanged;
  final void Function(int questionIndex) onSubmitCustomText;
  final void Function(int questionIndex) onShowCustomInput;

  const _OtherAnswerSection({
    required this.questionIndex,
    required this.isCustomInputShown,
    required this.isMultiQuestion,
    required this.statusColor,
    required this.controller,
    required this.onCustomTextChanged,
    required this.onSubmitCustomText,
    required this.onShowCustomInput,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final canSubmit = controller.text.trim().isNotEmpty;

    if (isCustomInputShown) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(fontSize: 13),
                minLines: 1,
                maxLines: 3,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Type your answer...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: statusColor.withValues(alpha: 0.4),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: statusColor.withValues(alpha: 0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: statusColor.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: statusColor),
                  ),
                  isDense: true,
                ),
                onChanged: (text) => onCustomTextChanged(questionIndex, text),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: sessionCardButtonHeight,
              child: FilledButton(
                onPressed: canSubmit
                    ? () {
                        FocusScope.of(context).unfocus();
                        onSubmitCustomText(questionIndex);
                      }
                    : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  foregroundColor: statusColor,
                  disabledBackgroundColor: statusColor.withValues(alpha: 0.08),
                  disabledForegroundColor: statusColor.withValues(alpha: 0.35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  isMultiQuestion ? l.next : l.send,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: TextButton(
          onPressed: () => onShowCustomInput(questionIndex),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: const Size(0, 36),
            textStyle: const TextStyle(fontSize: 12),
            foregroundColor: statusColor.withValues(alpha: 0.7),
          ),
          child: const Text('Other answer...'),
        ),
      ),
    );
  }
}

/// Common layout for a single question page.
/// Used by both inline (single-question) and PageView (multi-question) modes
/// to ensure consistent ordering: question -> options -> other answer -> confirm.
class SessionCardQuestionLayout extends StatelessWidget {
  final Map<String, dynamic> question;
  final int questionIndex;
  final Color statusColor;
  final bool isMultiQuestion;
  final bool allowsCustomInput;
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

  const SessionCardQuestionLayout({
    super.key,
    required this.question,
    required this.questionIndex,
    required this.statusColor,
    required this.isMultiQuestion,
    required this.allowsCustomInput,
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
  });

  @override
  Widget build(BuildContext context) {
    final opts = question['options'] as List<dynamic>? ?? [];
    final isMulti = question['multiSelect'] as bool? ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SessionCardQuestionText(question: question),
        const SizedBox(height: 6),
        if (isMulti && opts.isNotEmpty)
          _MultiSelectChips(
            questionIndex: questionIndex,
            options: opts,
            selected: multiAnswers.putIfAbsent(questionIndex, () => {}),
            statusColor: statusColor,
            onToggleLabel: onToggleMultiSelectLabel,
          )
        else if (opts.isNotEmpty)
          _SingleSelectChips(
            questionIndex: questionIndex,
            options: opts,
            selectedLabel: singleAnswers[questionIndex],
            statusColor: statusColor,
            onAnswerSingle: onAnswerSingle,
          ),
        if (allowsCustomInput)
          _OtherAnswerSection(
            questionIndex: questionIndex,
            isCustomInputShown: customInputs.contains(questionIndex),
            isMultiQuestion: isMultiQuestion,
            statusColor: statusColor,
            controller: getOrCreateController(questionIndex),
            onCustomTextChanged: onCustomTextChanged,
            onSubmitCustomText: onSubmitCustomText,
            onShowCustomInput: onShowCustomInput,
          ),
        if (isMulti && !isMultiQuestion)
          _ConfirmButton(
            questionIndex: questionIndex,
            selected: multiAnswers[questionIndex] ?? {},
            statusColor: statusColor,
            onConfirmMultiSelect: onConfirmMultiSelect,
          ),
      ],
    );
  }
}

/// PageView for multi-question flows with step indicators and summary page.
class SessionCardQuestionPageView extends StatelessWidget {
  final List<dynamic> questions;
  final int currentPage;
  final PageController pageController;
  final Color statusColor;
  final bool isMultiQuestion;
  final bool allowsCustomInput;
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
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onGoToPage;
  final VoidCallback onResetAll;
  final VoidCallback onSubmitAll;
  final bool canSubmitAll;

  const SessionCardQuestionPageView({
    super.key,
    required this.questions,
    required this.currentPage,
    required this.pageController,
    required this.statusColor,
    required this.isMultiQuestion,
    required this.allowsCustomInput,
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
    required this.onPageChanged,
    required this.onGoToPage,
    required this.onResetAll,
    required this.onSubmitAll,
    required this.canSubmitAll,
  });

  @override
  Widget build(BuildContext context) {
    final totalPages = isMultiQuestion
        ? questions.length + 1
        : questions.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Minimal step indicators: 1 of 3
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                currentPage < questions.length
                    ? ((questions[currentPage]
                                  as Map<String, dynamic>)['header']
                              as String? ??
                          'Q${currentPage + 1}')
                    : 'Review Summary',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor.withValues(alpha: 0.8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${currentPage + 1} of $totalPages',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Progress bar instead of bulky chips
        LinearProgressIndicator(
          value: (currentPage + 1) / totalPages,
          backgroundColor: statusColor.withValues(alpha: 0.1),
          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
          minHeight: 2,
        ),
        const SizedBox(height: 10),
        // Dynamic height container based on content, avoiding rigid PageView size
        ExpandablePageView.builder(
          controller: pageController,
          itemCount: totalPages,
          onPageChanged: onPageChanged,
          itemBuilder: (context, index) {
            if (index == questions.length) {
              return _SummaryPage(
                questions: questions,
                statusColor: statusColor,
                singleAnswers: singleAnswers,
                multiAnswers: multiAnswers,
                customControllers: getOrCreateController,
                onGoToPage: onGoToPage,
                onResetAll: onResetAll,
                onSubmitAll: canSubmitAll ? onSubmitAll : null,
              );
            }
            return SessionCardQuestionLayout(
              question: questions[index] as Map<String, dynamic>,
              questionIndex: index,
              statusColor: statusColor,
              isMultiQuestion: isMultiQuestion,
              allowsCustomInput: allowsCustomInput,
              singleAnswers: singleAnswers,
              multiAnswers: multiAnswers,
              customInputs: customInputs,
              getOrCreateController: getOrCreateController,
              onAnswerSingle: onAnswerSingle,
              onToggleMultiSelectLabel: onToggleMultiSelectLabel,
              onConfirmMultiSelect: onConfirmMultiSelect,
              onSubmitCustomText: onSubmitCustomText,
              onCustomTextChanged: onCustomTextChanged,
              onShowCustomInput: onShowCustomInput,
            );
          },
        ),
      ],
    );
  }
}

/// Summary page showing all answers with Submit/Cancel buttons.
class _SummaryPage extends StatelessWidget {
  final List<dynamic> questions;
  final Color statusColor;
  final Map<int, String> singleAnswers;
  final Map<int, Set<String>> multiAnswers;
  final TextEditingController Function(int) customControllers;
  final ValueChanged<int> onGoToPage;
  final VoidCallback onResetAll;
  final VoidCallback? onSubmitAll;

  const _SummaryPage({
    required this.questions,
    required this.statusColor,
    required this.singleAnswers,
    required this.multiAnswers,
    required this.customControllers,
    required this.onGoToPage,
    required this.onResetAll,
    required this.onSubmitAll,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Review your answers',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < questions.length; i++) ...[
            _SummaryRow(
              index: i,
              question: questions[i] as Map<String, dynamic>,
              statusColor: statusColor,
              singleAnswers: singleAnswers,
              multiAnswers: multiAnswers,
              customControllers: customControllers,
              onGoToPage: onGoToPage,
            ),
            if (i < questions.length - 1) const SizedBox(height: 6),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    onPressed: onResetAll,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      side: BorderSide(color: cs.outlineVariant),
                      foregroundColor: cs.onSurfaceVariant,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: FilledButton(
                    key: const ValueKey('ask_submit_summary_button'),
                    onPressed: onSubmitAll,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      backgroundColor: statusColor,
                      foregroundColor: statusColor.computeLuminance() > 0.5
                          ? Colors.black
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'Submit',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.send, size: 14),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A single row in the summary page showing the answer for one question.
class _SummaryRow extends StatelessWidget {
  final int index;
  final Map<String, dynamic> question;
  final Color statusColor;
  final Map<int, String> singleAnswers;
  final Map<int, Set<String>> multiAnswers;
  final TextEditingController Function(int) customControllers;
  final ValueChanged<int> onGoToPage;

  const _SummaryRow({
    required this.index,
    required this.question,
    required this.statusColor,
    required this.singleAnswers,
    required this.multiAnswers,
    required this.customControllers,
    required this.onGoToPage,
  });

  @override
  Widget build(BuildContext context) {
    final header = question['header'] as String? ?? 'Q${index + 1}';
    final isMulti = question['multiSelect'] as bool? ?? false;

    // Compute combined answer for summary
    String? answer;
    if (isMulti) {
      final selected = multiAnswers[index] ?? {};
      final parts = [...selected];
      final customText = customControllers(index).text.trim();
      if (customText.isNotEmpty) parts.add(customText);
      answer = parts.isNotEmpty ? parts.join(', ') : null;
    } else {
      answer = singleAnswers[index];
    }

    final hasAnswer = answer != null && answer.isNotEmpty;
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => onGoToPage(index),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: cs.surfaceContainerLowest,
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              hasAnswer ? Icons.check_circle : Icons.error_outline,
              size: 14,
              color: hasAnswer ? statusColor : cs.error,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    header,
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasAnswer ? answer : '(No answer selected)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: hasAnswer ? cs.onSurface : cs.error,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.edit,
              size: 14,
              color: statusColor.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}
