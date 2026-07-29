import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kDailyGoalKey = 'study.daily_goal';

/// How many reviews the learner is aiming for each day.
///
/// A preference, not a fact about the database — which is why it lives here
/// and not alongside the study statistics. The streak is deliberately
/// independent of it: changing this number must not rewrite what the learner
/// has already done.
@lazySingleton
class DailyGoalStore {
  DailyGoalStore(this._prefs);

  final SharedPreferences _prefs;

  /// Where a learner with no opinion starts.
  ///
  /// Twenty reviews is a few minutes — small enough to do on a bad day, which
  /// is the only property a daily goal really needs.
  static const int defaultGoal = 20;

  /// The narrowest and widest a goal may be.
  ///
  /// The floor keeps a goal meaningful; the ceiling keeps a mis-tap from
  /// setting something no one could ever meet, which would quietly turn the
  /// progress ring into a permanent reproach.
  static const int minGoal = 5;
  static const int maxGoal = 200;

  int read() => _prefs.getInt(_kDailyGoalKey) ?? defaultGoal;

  /// Stores [goal], clamped into the supported range.
  Future<void> write(int goal) =>
      _prefs.setInt(_kDailyGoalKey, goal.clamp(minGoal, maxGoal));
}
