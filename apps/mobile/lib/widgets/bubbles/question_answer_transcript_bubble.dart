import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../models/messages.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import 'ask_question_option_button.dart';

class QuestionAnswerTranscriptBubble extends StatelessWidget {
  final QuestionAnswerTranscript transcript;

  const QuestionAnswerTranscriptBubble({super.key, required this.transcript});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final l = AppLocalizations.of(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: const ValueKey('question_answer_transcript_bubble'),
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.bubbleMarginH,
          vertical: 4,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              appColors.askBubble,
              appColors.askBubble.withValues(alpha: 0.78),
            ],
          ),
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(color: appColors.askBubbleBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    size: 17,
                    color: appColors.askIcon,
                  ),
                ),
                const SizedBox(width: 9),
                Text(
                  l.questionLabel,
                  style: TextStyle(
                    color: appColors.askIcon,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  l.answered,
                  style: TextStyle(
                    color: appColors.subtleText,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
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
              if (index > 0) ...[
                Divider(
                  height: 20,
                  color: appColors.askBubbleBorder.withValues(alpha: 0.55),
                ),
              ],
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
    final appColors = Theme.of(context).extension<AppColors>()!;
    final l = AppLocalizations.of(context);
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (question.header != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: appColors.askIcon.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              question.header!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: appColors.askIcon,
              ),
            ),
          ),
          const SizedBox(height: 5),
        ],
        SelectableText(
          question.question,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (question.multiSelect) ...[
          const SizedBox(height: 2),
          Text(
            l.selectAllThatApply,
            style: TextStyle(fontSize: 11, color: appColors.subtleText),
          ),
        ],
        if (question.options.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final option in question.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
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
    final appColors = Theme.of(context).extension<AppColors>()!;
    final surface = Theme.of(context).colorScheme.surface;

    return Container(
      key: const ValueKey('question_answer_free_text'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: appColors.askBubbleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: appColors.askIcon,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          SelectableText(answer, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
