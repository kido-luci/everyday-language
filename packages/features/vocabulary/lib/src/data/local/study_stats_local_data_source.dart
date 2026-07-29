import 'package:database/database.dart';
import 'package:injectable/injectable.dart';

import 'review_local_data_source.dart';

/// The figures behind the dashboard: what has been reviewed, and how much is
/// waiting.
///
/// Review times are handed back as instants rather than pre-grouped, because
/// grouping them into days is a local-calendar question that SQL cannot answer
/// — see `StudyCalendar`.
@lazySingleton
class StudyStatsLocalDataSource {
  StudyStatsLocalDataSource(this._db, this._reviews);

  final AppDatabase _db;

  /// Reused rather than re-queried so "due" means one thing in the app.
  final ReviewLocalDataSource _reviews;

  /// How far back a streak is measured.
  ///
  /// A year of review instants is a few thousand rows at most, and reading
  /// them all on every dashboard load would grow without limit. A streak
  /// longer than this is a good problem to have and can be revisited then;
  /// what matters is that the bound is stated rather than silently applied.
  static const int windowDays = 365;

  /// Every review instant inside the window, UTC.
  Future<List<DateTime>> reviewTimes({required DateTime now}) async {
    // A day of slack: the window is trimmed against UTC while the days are
    // counted locally, and a review near the far edge should not fall out
    // just because the learner is west of Greenwich.
    final cutoff = now.toUtc().subtract(const Duration(days: windowDays + 1));
    final column = _db.reviewLogs.reviewedAtUs;

    final rows =
        await (_db.selectOnly(_db.reviewLogs)
              ..addColumns([column])
              ..where(
                column.isBiggerOrEqualValue(cutoff.microsecondsSinceEpoch),
              ))
            .get();

    return [
      for (final row in rows)
        DateTime.fromMicrosecondsSinceEpoch(row.read(column)!, isUtc: true),
    ];
  }

  /// How many words the learner has collected.
  Future<int> wordCount() async {
    final count = _db.words.id.count();
    final row = await (_db.selectOnly(
      _db.words,
    )..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }

  /// How many cards are waiting at [now].
  Future<int> dueCount({required DateTime now}) => _reviews.dueCount(now: now);
}
