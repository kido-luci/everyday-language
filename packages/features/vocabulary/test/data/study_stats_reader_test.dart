// Against a real in-memory database, end to end from graded reviews to the
// figures the dashboard shows — the queries and the day bucketing together,
// which is where a stats bug would actually live.

import 'package:architecture/architecture.dart';
import 'package:database/database.dart';
import 'package:drift/native.dart';
import 'package:feature_vocabulary/src/data/local/review_local_data_source.dart';
import 'package:feature_vocabulary/src/data/local/study_stats_local_data_source.dart';
import 'package:feature_vocabulary/src/data/local/vocabulary_local_data_source.dart';
import 'package:feature_vocabulary/src/data/readers/study_stats_reader_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_contracts/shared_contracts.dart';
import 'package:srs/srs.dart';

void main() {
  late AppDatabase db;
  late VocabularyLocalDataSource vocabulary;
  late StudyStatsReaderImpl reader;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    final scheduler = SrsScheduler(fuzz: false);
    vocabulary = VocabularyLocalDataSource(db, scheduler);
    reader = StudyStatsReaderImpl(
      StudyStatsLocalDataSource(db, ReviewLocalDataSource(db)),
    );
  });
  tearDown(() => db.close());

  /// Writes a review log directly: what the figures are computed from, without
  /// dragging the scheduler into a test about counting.
  Future<void> logReview(int cardId, DateTime at) => db
      .into(db.reviewLogs)
      .insert(
        ReviewLogsCompanion.insert(
          cardId: cardId,
          grade: ReviewGrade.good,
          previousPhase: SchedulePhase.learning,
          reviewedAtUs: at.toUtc().microsecondsSinceEpoch,
        ),
      );

  Future<int> addWordAndCard(String display, {required DateTime now}) async {
    await vocabulary.addWord(display: display, now: now);
    final cards = await db.select(db.cards).get();
    return cards.last.id;
  }

  test('a fresh install reports nothing rather than failing', () async {
    final result = await reader();

    expect(result, isA<Ok<StudyStats>>());
    final stats = (result as Ok<StudyStats>).value;
    expect(stats.streakDays, 0);
    expect(stats.reviewsToday, 0);
    expect(stats.dueNow, 0);
    expect(stats.totalWords, 0);
    expect(stats.recentActivity, hasLength(StudyStatsReaderImpl.activityDays));
  });

  test('counts words and the cards waiting for them', () async {
    final now = DateTime.now();
    await vocabulary.addWord(display: 'deadline', now: now);
    await vocabulary.addWord(display: 'agenda', now: now);

    final stats = ((await reader()) as Ok<StudyStats>).value;

    expect(stats.totalWords, 2);
    expect(
      stats.dueNow,
      2 * CardKind.values.length,
      reason: 'a new word is three cards, all due immediately',
    );
  });

  test("counts today's reviews and starts the streak", () async {
    final now = DateTime.now();
    final cardId = await addWordAndCard('deadline', now: now);

    await logReview(cardId, now);
    await logReview(cardId, now);

    final stats = ((await reader()) as Ok<StudyStats>).value;

    expect(stats.reviewsToday, 2);
    expect(stats.streakDays, 1);
    expect(stats.recentActivity.last.reviews, 2, reason: 'today is last');
  });

  test('a run of days becomes a streak', () async {
    final now = DateTime.now();
    final cardId = await addWordAndCard('deadline', now: now);

    for (var back = 0; back < 5; back++) {
      await logReview(cardId, DateTime(now.year, now.month, now.day - back, 9));
    }

    final stats = ((await reader()) as Ok<StudyStats>).value;

    expect(stats.streakDays, 5);
  });

  test('reviews older than the window do not extend a streak', () async {
    final now = DateTime.now();
    final cardId = await addWordAndCard('deadline', now: now);

    await logReview(cardId, now);
    await logReview(
      cardId,
      DateTime(
        now.year,
        now.month,
        now.day - StudyStatsLocalDataSource.windowDays - 30,
      ),
    );

    final stats = ((await reader()) as Ok<StudyStats>).value;

    expect(
      stats.streakDays,
      1,
      reason: 'the old review is outside the window and also not adjacent',
    );
  });
}
