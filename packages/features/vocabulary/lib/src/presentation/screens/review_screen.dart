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
              message: context.l10n.reviewDoneMessage,
              action: AppButton(
                label: context.l10n.commonDone,
                onPressed: onFinished,
              ),
            ),
            ReviewSessionStatus.reviewing => ReviewCardView(
              card: state.current!,
              isRevealed: state.isRevealed,
              onReveal: cubit.reveal,
              onGrade: cubit.grade,
            ),
          },
        );
      },
    );
  }
}
