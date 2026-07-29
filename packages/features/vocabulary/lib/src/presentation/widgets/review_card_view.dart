import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:localization/localization.dart';
import 'package:srs/srs.dart';

import '../../domain/entities/review_card.dart';

/// The prompt, the answer once it is showing, and whatever comes next.
///
/// Two shapes, decided by the card:
///
/// - **Recognition** — read the word, decide for yourself whether you knew it,
///   then pick one of four grades.
/// - **Production** (recall and cloze) — type the word before anything is
///   revealed. There is deliberately no "show answer" button here: it would be
///   a way to skip the retrieval the card exists for.
///
/// Either way, grades appear only once the answer does. After a wrong answer
/// the only grade offered is "again", and after a correct one "again" is not
/// offered at all — the question left is how hard it felt, not whether it came
/// back.
class ReviewCardView extends StatelessWidget {
  const ReviewCardView({
    super.key,
    required this.card,
    required this.isRevealed,
    required this.typed,
    required this.wasCorrect,
    required this.canSubmitAnswer,
    required this.onReveal,
    required this.onAnswerChanged,
    required this.onSubmitAnswer,
    required this.onGrade,
  });

  final ReviewCard card;
  final bool isRevealed;
  final String typed;

  /// Null on a recognition card, or before an answer is submitted.
  final bool? wasCorrect;

  final bool canSubmitAnswer;
  final VoidCallback onReveal;
  final ValueChanged<String> onAnswerChanged;
  final VoidCallback onSubmitAnswer;
  final void Function(ReviewGrade grade) onGrade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTypingDrill = card.asksForProduction;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    card.prompt(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  if (isTypingDrill && !isRevealed) ...[
                    const SizedBox(height: AppSpacing.xl),
                    AppTextField(
                      key: const Key('reviewAnswerField'),
                      hint: context.l10n.reviewTypeHint,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      onChanged: onAnswerChanged,
                      onSubmitted: (_) => onSubmitAnswer(),
                    ),
                  ],
                  if (isRevealed) ...[
                    if (wasCorrect != null)
                      _AnswerVerdict(wasCorrect: wasCorrect!, typed: typed),
                    const Divider(height: AppSpacing.xxl),
                    Text(
                      card.display,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (card.phonetic != null)
                      Text(
                        card.phonetic!,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    for (final line in [card.meaning, card.collocation])
                      if (line != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          line,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ],
                    if (card.sentence != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        card.sentence!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
        if (!isRevealed && isTypingDrill)
          AppButton(
            label: context.l10n.reviewCheck,
            expand: true,
            onPressed: canSubmitAnswer ? onSubmitAnswer : null,
          )
        else if (!isRevealed)
          AppButton(
            label: context.l10n.reviewShowAnswer,
            expand: true,
            onPressed: onReveal,
          )
        else if (wasCorrect == false)
          // The word is on screen now; the only honest grade is that it was
          // not recalled, so this is one button rather than a false choice.
          AppButton(
            label: context.l10n.reviewContinue,
            expand: true,
            onPressed: () => onGrade(ReviewGrade.again),
          )
        else
          _GradeButtons(
            grades: wasCorrect == true
                ? const [ReviewGrade.hard, ReviewGrade.good, ReviewGrade.easy]
                : ReviewGrade.values,
            onGrade: onGrade,
          ),
      ],
    );
  }
}

class _AnswerVerdict extends StatelessWidget {
  const _AnswerVerdict({required this.wasCorrect, required this.typed});

  final bool wasCorrect;
  final String typed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = wasCorrect
        ? theme.colorScheme.primary
        : theme.colorScheme.error;

    return Column(
      children: [
        const SizedBox(height: AppSpacing.lg),
        Text(
          wasCorrect
              ? context.l10n.reviewCorrect
              : context.l10n.reviewIncorrect,
          style: theme.textTheme.titleMedium?.copyWith(color: colour),
        ),
        // Showing what they typed next to the right answer is where the
        // learning is — a bare "wrong" leaves them guessing what they missed.
        if (!wasCorrect && typed.trim().isNotEmpty)
          Text(
            context.l10n.reviewYouTyped(typed.trim()),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _GradeButtons extends StatelessWidget {
  const _GradeButtons({required this.grades, required this.onGrade});

  final List<ReviewGrade> grades;
  final void Function(ReviewGrade grade) onGrade;

  @override
  Widget build(BuildContext context) {
    String label(ReviewGrade grade) => switch (grade) {
      ReviewGrade.again => context.l10n.reviewAgain,
      ReviewGrade.hard => context.l10n.reviewHard,
      ReviewGrade.good => context.l10n.reviewGood,
      ReviewGrade.easy => context.l10n.reviewEasy,
    };

    return Row(
      children: [
        for (final grade in grades)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: AppButton(
                label: label(grade),
                size: AppButtonSize.small,
                variant: grade == ReviewGrade.again
                    ? AppButtonVariant.tonal
                    : AppButtonVariant.primary,
                onPressed: () => onGrade(grade),
              ),
            ),
          ),
      ],
    );
  }
}
