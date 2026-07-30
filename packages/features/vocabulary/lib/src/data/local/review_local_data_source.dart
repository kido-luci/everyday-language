import 'package:database/database.dart';
import 'package:injectable/injectable.dart';
import 'package:srs/srs.dart';

/// One due card with everything needed to render its prompt.
class DueCardRow {
  const DueCardRow({
    required this.card,
    required this.word,
    this.example,
  });

  final CardRow card;
  final WordRow word;

  /// The sentence to blank out, when there is one. Null cards can still be
  /// reviewed for recognition.
  final ExampleRow? example;
}

/// Reads the review queue and writes what a review did to it.
@lazySingleton
class ReviewLocalDataSource {
  ReviewLocalDataSource(this._db);

  final AppDatabase _db;

  /// Cards due at [now], most overdue first, at most [limit] of them.
  ///
  /// [limit] is required rather than defaulted: a session that quietly serves
  /// some of what is due, with nothing in the UI saying so, is how cards go
  /// missing. Whoever asks has to decide how many they can account for.
  ///
  /// Ordered by due time rather than shuffled: a card that has been waiting
  /// three days has decayed further than one due this morning, so it is the
  /// one worth spending the session's attention on.
  Future<List<DueCardRow>> dueCards({
    required DateTime now,
    required int limit,
  }) async {
    final nowUs = now.toUtc().microsecondsSinceEpoch;

    final query =
        _db.select(_db.cards).join([
            innerJoin(_db.words, _db.words.id.equalsExp(_db.cards.wordId)),
          ])
          ..where(_db.cards.dueAtUs.isSmallerOrEqualValue(nowUs))
          ..orderBy([OrderingTerm.asc(_db.cards.dueAtUs)])
          ..limit(limit);

    final rows = await query.get();
    if (rows.isEmpty) return const [];

    final wordIds = rows.map((r) => r.readTable(_db.words).id).toSet();
    final examples =
        await (_db.select(_db.examples)
              ..where((e) => e.wordId.isIn(wordIds))
              ..orderBy([(e) => OrderingTerm.asc(e.createdAtUs)]))
            .get();

    // The learner's own sentence wins: a cue from your own reading beats a
    // generated one. Falls back to whatever exists.
    final best = <int, ExampleRow>{};
    for (final e in examples) {
      final current = best[e.wordId];
      if (current == null ||
          (current.origin != ExampleOrigin.userCapture &&
              e.origin == ExampleOrigin.userCapture)) {
        best[e.wordId] = e;
      }
    }

    return [
      for (final row in rows)
        DueCardRow(
          card: row.readTable(_db.cards),
          word: row.readTable(_db.words),
          example: best[row.readTable(_db.words).id],
        ),
    ];
  }

  /// How many cards are waiting at [now].
  Future<int> dueCount({required DateTime now}) async {
    final nowUs = now.toUtc().microsecondsSinceEpoch;
    final count = _db.cards.id.count();
    final row =
        await (_db.selectOnly(_db.cards)
              ..addColumns([count])
              ..where(_db.cards.dueAtUs.isSmallerOrEqualValue(nowUs)))
            .getSingle();
    return row.read(count) ?? 0;
  }

  /// Writes a graded review: the card's new schedule and the log entry.
  ///
  /// One transaction, because a schedule that moved without a log would leave
  /// the history unable to explain it — and that history is the only thing
  /// FSRS could ever be re-fitted against.
  Future<void> applyReview({
    required int cardId,
    required ReviewOutcome outcome,
  }) {
    final schedule = outcome.schedule;
    return _db.transaction(() async {
      await (_db.update(_db.cards)..where((c) => c.id.equals(cardId))).write(
        CardsCompanion(
          phase: Value(schedule.phase),
          step: Value(schedule.step),
          stability: Value(schedule.stability),
          difficulty: Value(schedule.difficulty),
          dueAtUs: Value(schedule.dueAt.microsecondsSinceEpoch),
          lastReviewedAtUs: Value(
            schedule.lastReviewedAt?.microsecondsSinceEpoch,
          ),
          reps: Value(schedule.reps),
          lapses: Value(schedule.lapses),
        ),
      );

      await _db
          .into(_db.reviewLogs)
          .insert(
            ReviewLogsCompanion.insert(
              cardId: cardId,
              grade: outcome.grade,
              previousPhase: outcome.previousPhase,
              elapsedMs: Value(outcome.elapsed?.inMilliseconds),
              reviewedAtUs: outcome.reviewedAt.microsecondsSinceEpoch,
            ),
          );
    });
  }
}
