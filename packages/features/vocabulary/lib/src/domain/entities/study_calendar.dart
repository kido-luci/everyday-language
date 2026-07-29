import 'package:meta/meta.dart';
import 'package:shared_contracts/shared_contracts.dart';

/// Buckets review instants into the learner's own calendar days.
///
/// Reviews are stored as UTC instants, but a streak is counted in local days —
/// studying at 11pm and again at 1am is two days, and studying at 8am and 11pm
/// is one. So the bucketing happens here, in Dart, rather than in SQL: the
/// offset from UTC is not a constant a query can add, because it changes at
/// every daylight-saving transition.
///
/// Day arithmetic is done on calendar fields (`DateTime(y, m, d - 1)`), never
/// by subtracting a `Duration` of 24 hours. On the day the clocks move, a day
/// is 23 or 25 hours long, and duration arithmetic lands on the wrong date.
@immutable
class StudyCalendar {
  const StudyCalendar._(this._reviewsByDay, this._today);

  /// Buckets [reviewedAt] — instants, in any zone — by the local day they
  /// fall on, relative to [now].
  factory StudyCalendar.from({
    required DateTime now,
    required Iterable<DateTime> reviewedAt,
  }) {
    final byDay = <DateTime, int>{};
    for (final instant in reviewedAt) {
      final day = _dayOf(instant.toLocal());
      byDay[day] = (byDay[day] ?? 0) + 1;
    }
    return StudyCalendar._(byDay, _dayOf(now.toLocal()));
  }

  final Map<DateTime, int> _reviewsByDay;
  final DateTime _today;

  /// Reviews done today.
  int get reviewsToday => _reviewsByDay[_today] ?? 0;

  /// Consecutive days studied, counting back from today.
  ///
  /// A streak that ran up to yesterday still counts today, before the learner
  /// has opened the app: not having studied *yet* is not the same as having
  /// stopped, and a number that resets itself at midnight punishes them for
  /// the hours in between. Missing a whole day does end it.
  int get streakDays {
    var day = _studiedOn(_today) ? _today : _previous(_today);
    if (!_studiedOn(day)) return 0;

    var streak = 0;
    while (_studiedOn(day)) {
      streak++;
      day = _previous(day);
    }
    return streak;
  }

  /// The last [count] days, oldest first, including today.
  List<DayActivity> lastDays(int count) {
    final days = <DayActivity>[];
    for (var back = count - 1; back >= 0; back--) {
      final day = DateTime(_today.year, _today.month, _today.day - back);
      days.add(DayActivity(day: day, reviews: _reviewsByDay[day] ?? 0));
    }
    return days;
  }

  bool _studiedOn(DateTime day) => (_reviewsByDay[day] ?? 0) > 0;

  static DateTime _previous(DateTime day) =>
      DateTime(day.year, day.month, day.day - 1);

  /// Midnight on the day [local] falls in.
  ///
  /// Where a daylight-saving jump means local midnight never happened, Dart
  /// normalises this to the first instant that did. That is still one stable
  /// key per day, which is all the bucketing needs.
  static DateTime _dayOf(DateTime local) =>
      DateTime(local.year, local.month, local.day);
}
