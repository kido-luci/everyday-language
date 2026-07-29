import 'package:architecture/architecture.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_contracts/shared_contracts.dart';

import '../../domain/entities/study_calendar.dart';
import '../local/study_stats_local_data_source.dart';

/// Supplies the dashboard's figures.
///
/// This feature owns the review history, so it answers the question; the
/// dashboard consumes [StudyStatsReader] from `shared_contracts` and never
/// learns that a `review_logs` table exists.
@LazySingleton(as: StudyStatsReader)
class StudyStatsReaderImpl extends StudyStatsReader {
  const StudyStatsReaderImpl(this._local);

  final StudyStatsLocalDataSource _local;

  /// Days of history the dashboard shows at a glance.
  static const int activityDays = 7;

  @override
  Future<Result<StudyStats>> call([NoParams param = noParams]) async {
    // One clock for the whole read: taking `now` twice could put the streak
    // and the due count on opposite sides of midnight.
    final now = DateTime.now();

    final calendar = StudyCalendar.from(
      now: now,
      reviewedAt: await _local.reviewTimes(now: now),
    );

    return Ok(
      StudyStats(
        streakDays: calendar.streakDays,
        reviewsToday: calendar.reviewsToday,
        dueNow: await _local.dueCount(now: now),
        totalWords: await _local.wordCount(),
        recentActivity: calendar.lastDays(activityDays),
      ),
    );
  }
}
