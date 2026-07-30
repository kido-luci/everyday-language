// Against a real database: the queue's ordering, the "learner's own sentence
// wins" rule, and that a graded review moves the card and logs it together.

import 'package:database/database.dart';
import 'package:drift/native.dart';
import 'package:feature_vocabulary/src/data/local/review_local_data_source.dart';
import 'package:feature_vocabulary/src/data/local/vocabulary_local_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:srs/srs.dart';

void main() {
  late AppDatabase db;
  late VocabularyLocalDataSource vocabulary;
  late ReviewLocalDataSource review;
  late SrsScheduler scheduler;

  final now = DateTime.utc(2026, 6, 1, 9);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    scheduler = SrsScheduler(fuzz: false);
    vocabulary = VocabularyLocalDataSource(db, scheduler);
    review = ReviewLocalDataSource(db);
  });
  tearDown(() => db.close());

  test('a word just added is due immediately', () async {
    await vocabulary.addWord(display: 'decision', now: now);

    expect(await review.dueCount(now: now), CardKind.values.length);
  });

  test('cards not yet due stay out of the queue', () async {
    await vocabulary.addWord(display: 'decision', now: now);

    final earlier = now.subtract(const Duration(minutes: 1));
    expect(await review.dueCount(now: earlier), 0);
  });

  test(
    'a batch stops at its limit while the count keeps the whole truth',
    () async {
      // The pair the finished screen relies on: the queue hands over one
      // sitting's worth, the count says how much is really waiting. They used
      // to disagree silently, at a hard-coded hundred.
      await vocabulary.addWord(display: 'decision', now: now);
      await vocabulary.addWord(display: 'errand', now: now);

      final all = CardKind.values.length * 2;
      expect(await review.dueCount(now: now), all);
      expect(await review.dueCards(now: now, limit: 2), hasLength(2));
      expect(await review.dueCards(now: now, limit: all + 5), hasLength(all));
    },
  );

  test('the most overdue card comes first', () async {
    // Waiting longer means decayed further, so it is the one worth the
    // session's attention.
    await vocabulary.addWord(display: 'older', now: now);
    await vocabulary.addWord(
      display: 'newer',
      now: now.add(const Duration(hours: 1)),
    );

    final due = await review.dueCards(
      now: now.add(const Duration(days: 1)),
      limit: 10,
    );

    expect(due.first.word.display, 'older');
  });

  test('the queue carries the sentence the learner met the word in', () async {
    await vocabulary.addWord(
      display: 'decision',
      now: now,
      sentence: 'It was a hard decision.',
    );

    final due = await review.dueCards(now: now, limit: 20);

    expect(due.first.example?.sentence, 'It was a hard decision.');
    expect(due.first.example?.origin, ExampleOrigin.userCapture);
  });

  test('a captured sentence beats a generated one as the cue', () async {
    final word = await vocabulary.addWord(display: 'decision', now: now);
    await db
        .into(db.examples)
        .insert(
          ExamplesCompanion.insert(
            wordId: word.id,
            sentence: 'A generated sentence about decision.',
            origin: ExampleOrigin.llm,
            createdAtUs: now.microsecondsSinceEpoch,
          ),
        );
    await db
        .into(db.examples)
        .insert(
          ExamplesCompanion.insert(
            wordId: word.id,
            sentence: 'It was a hard decision.',
            origin: ExampleOrigin.userCapture,
            createdAtUs: now
                .add(const Duration(minutes: 1))
                .microsecondsSinceEpoch,
          ),
        );

    final due = await review.dueCards(now: now, limit: 20);

    expect(due.first.example?.origin, ExampleOrigin.userCapture);
  });

  test('grading moves the card and logs it in one go', () async {
    await vocabulary.addWord(display: 'decision', now: now);
    final card = (await review.dueCards(now: now, limit: 20)).first.card;
    final schedule = CardSchedule(
      dueAt: DateTime.fromMicrosecondsSinceEpoch(card.dueAtUs, isUtc: true),
    );

    final outcome = scheduler.grade(schedule, ReviewGrade.good, at: now);
    await review.applyReview(cardId: card.id, outcome: outcome);

    final updated = await (db.select(
      db.cards,
    )..where((c) => c.id.equals(card.id))).getSingle();
    expect(updated.dueAtUs, greaterThan(card.dueAtUs));
    expect(updated.reps, 1);
    expect(updated.stability, isNotNull);

    final log = await db.select(db.reviewLogs).getSingle();
    expect(log.cardId, card.id);
    expect(log.grade, ReviewGrade.good);
    expect(log.previousPhase, SchedulePhase.learning);
  });

  test(
    'review history survives nothing — it cannot be reconstructed',
    () async {
      await vocabulary.addWord(display: 'decision', now: now);
      final card = (await review.dueCards(now: now, limit: 20)).first.card;

      for (final grade in [ReviewGrade.good, ReviewGrade.again]) {
        final current = await (db.select(
          db.cards,
        )..where((c) => c.id.equals(card.id))).getSingle();
        await review.applyReview(
          cardId: card.id,
          outcome: scheduler.grade(
            CardSchedule(
              phase: current.phase,
              step: current.step,
              stability: current.stability,
              difficulty: current.difficulty,
              dueAt: DateTime.fromMicrosecondsSinceEpoch(
                current.dueAtUs,
                isUtc: true,
              ),
              reps: current.reps,
              lapses: current.lapses,
            ),
            grade,
            at: now,
          ),
        );
      }

      // Append-only: the first review is still there after the second.
      expect(await db.select(db.reviewLogs).get(), hasLength(2));
    },
  );
}
