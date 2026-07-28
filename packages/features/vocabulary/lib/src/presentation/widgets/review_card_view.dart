import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:localization/localization.dart';
import 'package:srs/srs.dart';

import '../../domain/entities/review_card.dart';

/// The prompt, the answer once revealed, and the four grades.
///
/// Grades only appear after the answer does: picking "easy" before seeing the
/// answer is not a judgement about recall, and letting it happen would feed
/// the scheduler a number that means nothing.
class ReviewCardView extends StatelessWidget {
  const ReviewCardView({
    super.key,
    required this.card,
    required this.isRevealed,
    required this.onReveal,
    required this.onGrade,
  });

  final ReviewCard card;
  final bool isRevealed;
  final VoidCallback onReveal;
  final void Function(ReviewGrade grade) onGrade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  if (!isRevealed && card.asksForProduction) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      context.l10n.reviewProduceHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                  if (isRevealed) ...[
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
        if (isRevealed)
          Row(
            children: [
              for (final (grade, label) in [
                (ReviewGrade.again, context.l10n.reviewAgain),
                (ReviewGrade.hard, context.l10n.reviewHard),
                (ReviewGrade.good, context.l10n.reviewGood),
                (ReviewGrade.easy, context.l10n.reviewEasy),
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    child: AppButton(
                      label: label,
                      size: AppButtonSize.small,
                      variant: grade == ReviewGrade.again
                          ? AppButtonVariant.tonal
                          : AppButtonVariant.primary,
                      onPressed: () => onGrade(grade),
                    ),
                  ),
                ),
            ],
          )
        else
          AppButton(
            label: context.l10n.reviewShowAnswer,
            expand: true,
            onPressed: onReveal,
          ),
      ],
    );
  }
}
