import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../models/messages.dart';
import '../../theme/app_spacing.dart';
import 'ask_question_option_button.dart';

class QuestionAnswerTranscriptBubble extends StatelessWidget {
  final QuestionAnswerTranscript transcript;

  const QuestionAnswerTranscriptBubble({super.key, required this.transcript});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l = AppLocalizations.of(context);
    final borderColor = cs.outlineVariant.withValues(
      alpha: isDark ? 0.65 : 0.8,
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: const ValueKey('question_answer_transcript_bubble'),
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.bubbleMarginH,
          vertical: AppSpacing.bubbleMarginV,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.help_outline, size: 15, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  l.questionLabel,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.86),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: isDark ? 0.08 : 0.06),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: cs.onSurfaceVariant.withValues(
                        alpha: isDark ? 0.22 : 0.18,
                      ),
                      width: 0.75,
                    ),
                  ),
                  child: Text(
                    l.answered,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (
              var index = 0;
              index < transcript.questions.length;
              index++
            ) ...[
              if (index > 0) ...[Divider(height: 20, color: borderColor)],
              _AnsweredQuestionContent(question: transcript.questions[index]),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnsweredQuestionContent extends StatelessWidget {
  final AnsweredQuestion question;

  const _AnsweredQuestionContent({required this.question});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (question.header != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: isDark ? 0.08 : 0.05),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.65),
                width: 0.75,
              ),
            ),
            child: Text(
              question.header!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        SelectableText(
          question.question,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 14,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (question.multiSelect) ...[
          const SizedBox(height: 3),
          Text(
            l.selectAllThatApply,
            style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
          ),
        ],
        if (question.options.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final option in question.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: AskQuestionOptionButton(
                optionKey: ValueKey('question_answer_option_${option.label}'),
                label: option.label,
                description: option.description ?? '',
                isSelected: option.selected,
                isMulti: question.multiSelect,
                onTap: null,
              ),
            ),
        ],
        if (question.answerHidden) ...[
          const SizedBox(height: 4),
          _AnsweredFreeText(label: l.answerHidden, answer: '••••'),
        ] else if (question.freeTextAnswer != null) ...[
          const SizedBox(height: 4),
          _AnsweredFreeText(
            label: question.options.isEmpty ? l.answered : l.otherAnswer,
            answer: question.freeTextAnswer!,
          ),
        ],
      ],
    );
  }
}

class _AnsweredFreeText extends StatelessWidget {
  final String label;
  final String answer;

  const _AnsweredFreeText({required this.label, required this.answer});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      key: const ValueKey('question_answer_free_text'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isDark
            ? cs.onSurface.withValues(alpha: 0.045)
            : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: isDark ? 0.7 : 0.8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          SelectableText(
            answer,
            style: TextStyle(fontSize: 13, color: cs.onSurface),
          ),
        ],
      ),
    );
  }
}
