import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:localization/localization.dart';

import '../../locator.dart';
import '../bloc/review_session/review_session_cubit.dart';
import '../bloc/review_session/review_session_state.dart';
import '../widgets/review_card_view.dart';

/// One sitting of the review queue.
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ReviewSessionCubit>()..start(),
      child: ReviewView(onFinished: onFinished),
    );
  }
}

@visibleForTesting
class ReviewView extends StatelessWidget {
  const ReviewView({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReviewSessionCubit, ReviewSessionState>(
      builder: (context, state) {
        final cubit = context.read<ReviewSessionCubit>();
        return AppScaffold(
          title: context.l10n.reviewTitle,
          // The shell's floating nav pill overlays the bottom of the body,
          // and the grade buttons sit right there.
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg + kFloatingNavBarInset,
          ),
          actions: [
            if (state.status == ReviewSessionStatus.reviewing)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.lg),
                child: Center(
                  child: Text(context.l10n.reviewRemaining(state.remaining)),
                ),
              ),
          ],
          isLoading: state.status == ReviewSessionStatus.loading,
          body: switch (state.status) {
            ReviewSessionStatus.loading => const SizedBox.shrink(),
            ReviewSessionStatus.failure => AppErrorView(
              message: state.failureMessage ?? context.l10n.commonErrorGeneric,
              onRetry: cubit.start,
            ),
            ReviewSessionStatus.finished => AppEmptyView(
              icon: FontAwesomeIcons.circleCheck,
              title: state.reviewed == 0
                  ? context.l10n.reviewDoneTitle
                  : context.l10n.reviewFinishedTitle,
              // Whatever is left has to be said out loud. A sitting serves the
              // daily goal, so finishing one is not the same as clearing the
              // queue — and a learner who is told "done" while cards wait has
              // been misled.
              message: state.hasMoreDue
                  ? context.l10n.reviewMoreDueMessage(state.dueAfter)
                  : context.l10n.reviewDoneMessage,
              action: state.hasMoreDue
                  ? _MoreDueActions(
                      nextSize: state.nextSessionSize,
                      onContinue: cubit.start,
                      onFinished: onFinished,
                    )
                  : AppButton(
                      label: context.l10n.commonDone,
                      onPressed: onFinished,
                    ),
            ),
            ReviewSessionStatus.reviewing => ReviewCardView(
              // Keyed by card so the answer field is rebuilt — not reused with
              // the previous card's text still in it — when the queue moves on.
              key: ValueKey(state.current!.id),
              card: state.current!,
              isRevealed: state.isRevealed,
              typed: state.typed,
              wasCorrect: state.wasCorrect,
              canSubmitAnswer: state.canSubmitAnswer,
              onReveal: cubit.reveal,
              onAnswerChanged: cubit.answerChanged,
              onSubmitAnswer: cubit.submitAnswer,
              onGrade: cubit.grade,
            ),
          },
        );
      },
    );
  }
}

/// Carry on, or stop here — offered when the sitting ended with cards still
/// due. Carrying on is the primary action, but stopping is a real choice and
/// keeps its own button.
class _MoreDueActions extends StatelessWidget {
  const _MoreDueActions({
    required this.nextSize,
    required this.onContinue,
    required this.onFinished,
  });

  final int nextSize;
  final VoidCallback onContinue;
  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppButton(
          label: context.l10n.reviewContinueCta(nextSize),
          onPressed: onContinue,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: context.l10n.commonDone,
          variant: AppButtonVariant.text,
          onPressed: onFinished,
        ),
      ],
    );
  }
}
