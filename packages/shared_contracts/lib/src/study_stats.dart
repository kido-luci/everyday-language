import 'package:architecture/architecture.dart';

/// How many reviews were done on one calendar day.
///
/// [day] is a local date at midnight — the app's unit of "a day's studying" is
/// the learner's own day, not a UTC one.
class DayActivity {
  const DayActivity({required this.day, required this.reviews});

  final DateTime day;
  final int reviews;

  bool get studied => reviews > 0;
}

/// What the learner has done, for a dashboard that does not own the data.
///
/// [streakDays] counts consecutive days on which at least one review happened
/// — deliberately not days on which a goal was met. A goal-based streak
/// rewrites its own history the moment the learner changes the goal, so a
/// number they were proud of yesterday can be gone today with nothing having
/// happened. The goal drives [reviewsToday]'s progress instead.
///
/// A streak that ended yesterday still counts: not having studied *yet* today
/// is not the same as having broken it, and resetting the number at midnight
/// would punish the learner for the hours before they open the app.
class StudyStats {
  const StudyStats({
    this.streakDays = 0,
    this.reviewsToday = 0,
    this.dueNow = 0,
    this.totalWords = 0,
    this.recentActivity = const [],
  });

  final int streakDays;
  final int reviewsToday;

  /// Cards waiting right now.
  final int dueNow;

  final int totalWords;

  /// One entry per day for the recent past, oldest first.
  final List<DayActivity> recentActivity;

  /// Whether today has been kept up, given a goal of [dailyGoal] reviews.
  bool goalMet(int dailyGoal) => reviewsToday >= dailyGoal;
}

/// Reads study statistics. Implemented by the vocabulary feature, which owns
/// the review history, and consumed by dashboards that do not.
abstract class StudyStatsReader extends NoParamUseCase<StudyStats> {
  const StudyStatsReader();
}
