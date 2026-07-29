import 'package:architecture/architecture.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_contracts/shared_contracts.dart';
import 'package:srs/srs.dart';

import '../../domain/entities/review_card.dart';
import '../../domain/repositories/review_repository.dart';
import '../local/review_local_data_source.dart';

@LazySingleton(as: ReviewRepository)
class ReviewRepositoryImpl implements ReviewRepository {
  const ReviewRepositoryImpl(this._local, this._scheduler, this._activity);

  final ReviewLocalDataSource _local;
  final SrsScheduler _scheduler;

  /// Announces that the review history moved, so screens showing figures
  /// derived from it — the dashboard's streak and today's count — can catch
  /// up. Without it they would only refresh when rebuilt, and the shell keeps
  /// every tab alive.
  final ActivityNotifier _activity;

  @override
  Future<Result<List<ReviewCard>>> dueCards({int limit = 100}) async {
    final rows = await _local.dueCards(now: DateTime.now(), limit: limit);
    return Ok([for (final row in rows) _toCard(row)]);
  }

  @override
  Future<Result<int>> dueCount() async =>
      Ok(await _local.dueCount(now: DateTime.now()));

  @override
  Future<Result<CardSchedule>> grade(
    ReviewCard card,
    ReviewGrade grade,
  ) async {
    final outcome = _scheduler.grade(card.schedule, grade);
    await _local.applyReview(cardId: card.id, outcome: outcome);
    _activity.notifyActivityOccurred();
    return Ok(outcome.schedule);
  }

  ReviewCard _toCard(DueCardRow row) => ReviewCard(
    id: row.card.id,
    kind: row.card.kind,
    schedule: CardSchedule(
      phase: row.card.phase,
      step: row.card.step,
      stability: row.card.stability,
      difficulty: row.card.difficulty,
      dueAt: DateTime.fromMicrosecondsSinceEpoch(
        row.card.dueAtUs,
        isUtc: true,
      ),
      lastReviewedAt: row.card.lastReviewedAtUs == null
          ? null
          : DateTime.fromMicrosecondsSinceEpoch(
              row.card.lastReviewedAtUs!,
              isUtc: true,
            ),
      reps: row.card.reps,
      lapses: row.card.lapses,
    ),
    display: row.word.display,
    phonetic: row.word.phonetic,
    meaning: row.word.meaningVi ?? row.word.meaningEn,
    collocation: row.word.collocation,
    sentence: row.example?.sentence,
  );
}
