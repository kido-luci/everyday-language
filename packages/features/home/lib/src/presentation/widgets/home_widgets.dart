import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:localization/localization.dart';
import 'package:shared_contracts/shared_contracts.dart';
import 'package:storage/storage.dart';

import '../../locator.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_state.dart';

/// The dashboard: what the learner has kept up, and the one thing to do next.
class HomeBody extends StatefulWidget {
  const HomeBody({super.key, required this.onReview, required this.onAddWord});

  /// Opens the review session. Awaited so the figures refresh on the way back.
  final Future<void> Function() onReview;

  final Future<void> Function() onAddWord;

  @override
  State<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<HomeBody> {
  StreamSubscription<void>? _activity;

  @override
  void initState() {
    super.initState();
    // The shell keeps every tab alive, so a word added on the Words tab would
    // otherwise leave this screen showing stale totals until it happened to be
    // rebuilt. The notifier is the documented way for one feature to say
    // "something changed" without either importing the other.
    _activity = getIt<ActivityNotifier>().onActivityOccurred.listen((_) {
      if (mounted) context.read<HomeBloc>().add(const HomeLoadRequested());
    });
  }

  @override
  void dispose() {
    unawaited(_activity?.cancel());
    super.dispose();
  }

  Future<void> _openThenRefresh(Future<void> Function() open) async {
    await open();
    if (mounted) context.read<HomeBloc>().add(const HomeLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        return AppScaffold(
          title: context.l10n.homeAppBarTitle,
          body: _body(context, state),
        );
      },
    );
  }

  Widget _body(BuildContext context, HomeState state) {
    final failure = state.failure;
    if (failure != null) {
      return AppErrorView(
        message: failure.message,
        onRetry: () => context.read<HomeBloc>().add(const HomeLoadRequested()),
      );
    }
    if (state.isLoading && state.stats.totalWords == 0) {
      return const AppLoading();
    }
    if (state.hasNothingToStudy) {
      return AppEmptyView(
        icon: FontAwesomeIcons.seedling,
        title: context.l10n.homeEmptyTitle,
        message: context.l10n.homeEmptyMessage,
        action: AppButton(
          label: context.l10n.homeAddWord,
          onPressed: () => _openThenRefresh(widget.onAddWord),
        ),
      );
    }
    return _Dashboard(
      state: state,
      onReview: () => _openThenRefresh(widget.onReview),
    );
  }
}

@visibleForTesting
class HomeDashboardKeys {
  const HomeDashboardKeys._();

  static const Key streak = Key('homeStreak');
  static const Key today = Key('homeToday');
  static const Key reviewCta = Key('homeReviewCta');
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.state, required this.onReview});

  final HomeState state;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final stats = state.stats;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        // Clears the shell's floating nav pill, which otherwise sits over the
        // last card and swallows its taps.
        kFloatingNavBarInset + AppSpacing.lg,
      ),
      children: [
        _StreakCard(streakDays: stats.streakDays),
        const SizedBox(height: AppSpacing.md),
        _TodayCard(state: state),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: FontAwesomeIcons.bookOpen,
                label: context.l10n.homeStatWords,
                value: '${stats.totalWords}',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _StatCard(
                icon: FontAwesomeIcons.clockRotateLeft,
                label: context.l10n.homeStatDue,
                value: '${stats.dueNow}',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _ActivityCard(activity: stats.recentActivity, goal: state.dailyGoal),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          key: HomeDashboardKeys.reviewCta,
          // The session serves the daily goal, not the whole queue, so the
          // button counts what a tap actually starts. The true backlog is
          // right above it in the "due" tile.
          label: context.l10n.homeReviewCta(
            stats.dueNow < state.dailyGoal ? stats.dueNow : state.dailyGoal,
          ),
          expand: true,
          // Nothing due is a finished state, not a broken one: the label says
          // so, and the button simply stops inviting a tap.
          onPressed: stats.dueNow == 0 ? null : onReview,
        ),
      ],
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streakDays});

  final int streakDays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alive = streakDays > 0;

    return AppCard(
      key: HomeDashboardKeys.streak,
      child: Row(
        children: [
          FaIcon(
            FontAwesomeIcons.fire,
            size: AppIconSize.xl,
            color: alive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alive
                      ? context.l10n.homeStreakDays(streakDays)
                      : context.l10n.homeStreakNone,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  alive
                      ? context.l10n.homeStreakKeep
                      : context.l10n.homeStreakStart,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final met = state.stats.goalMet(state.dailyGoal);

    return AppCard(
      key: HomeDashboardKeys.today,
      onTap: () => _editGoal(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.l10n.homeGreeting,
                style: theme.textTheme.titleMedium,
              ),
              const Spacer(),
              if (met)
                Text(
                  context.l10n.homeGoalMet,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                )
              else
                FaIcon(
                  FontAwesomeIcons.penToSquare,
                  size: AppIconSize.sm,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.l10n.homeTodayProgress(
              state.stats.reviewsToday,
              state.dailyGoal,
            ),
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: LinearProgressIndicator(
              value: state.goalProgress,
              minHeight: AppSpacing.sm,
              // The default empty track is `secondaryContainer` — a warm fill
              // that reads as progress at a glance, so a bar at zero looks
              // finished. Neutral, and the same grey the untouched days in the
              // activity strip use, so "empty" means one thing on this screen.
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editGoal(BuildContext context) async {
    final bloc = context.read<HomeBloc>();
    final chosen = await showDialog<int>(
      context: context,
      builder: (_) => _GoalDialog(current: state.dailyGoal),
    );
    if (chosen != null) bloc.add(HomeGoalChanged(chosen));
  }
}

/// Picks a daily goal, in steps of five between the store's own bounds.
class _GoalDialog extends StatefulWidget {
  const _GoalDialog({required this.current});

  final int current;

  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  static const int _step = 5;

  late int _goal = widget.current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(context.l10n.homeDailyGoalTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.homeDailyGoalHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            context.l10n.homeGoalValue(_goal),
            style: theme.textTheme.titleLarge,
          ),
          Slider(
            value: _goal.toDouble(),
            min: DailyGoalStore.minGoal.toDouble(),
            max: DailyGoalStore.maxGoal.toDouble(),
            divisions:
                (DailyGoalStore.maxGoal - DailyGoalStore.minGoal) ~/ _step,
            label: '$_goal',
            onChanged: (value) => setState(() => _goal = value.round()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_goal),
          child: Text(context.l10n.commonSave),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final FaIconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FaIcon(
            icon,
            size: AppIconSize.md,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(value, style: theme.textTheme.headlineSmall),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity, required this.goal});

  final List<DayActivity> activity;
  final int goal;

  static const double _maxBarHeight = 56;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekdays = MaterialLocalizations.of(context).narrowWeekdays;

    // Scaled against the busiest day, floored at the goal, so a good week does
    // not flatten into seven identical full bars and a quiet one still reads
    // against what was being aimed for.
    final busiest = activity.fold<int>(
      goal,
      (most, day) => day.reviews > most ? day.reviews : most,
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.homeActivityTitle,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final day in activity)
                _ActivityBar(
                  reviews: day.reviews,
                  // `DateTime.weekday` is 1..7 with Monday first; the narrow
                  // list is indexed from Sunday, so Sunday's 7 wraps to 0.
                  initial: weekdays[day.day.weekday % DateTime.daysPerWeek],
                  heightFraction: busiest == 0 ? 0 : day.reviews / busiest,
                  maxHeight: _maxBarHeight,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityBar extends StatelessWidget {
  const _ActivityBar({
    required this.reviews,
    required this.initial,
    required this.heightFraction,
    required this.maxHeight,
  });

  final int reviews;
  final String initial;
  final double heightFraction;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: '$initial: $reviews',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppSpacing.lg,
            // A day with nothing still gets a sliver, so the row reads as a
            // week rather than as a gap with bars in it.
            height: (maxHeight * heightFraction).clamp(
              AppSpacing.xs,
              maxHeight,
            ),
            decoration: BoxDecoration(
              color: reviews > 0
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            initial,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
