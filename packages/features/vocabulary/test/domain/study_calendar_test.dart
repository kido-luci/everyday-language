// Streaks are the easiest thing here to get quietly wrong: they depend on
// what "a day" means, and reviews are stored as UTC instants while a day is
// the learner's own.
//
// One thing these tests cannot exercise: a daylight-saving transition. Dart
// resolves `toLocal()` against the process timezone, which a test cannot
// choose, and the machines this runs on sit in zones without DST. What the
// boundary tests below do pin is the property DST safety rests on — that day
// arithmetic goes through calendar fields, so "the day before" is always the
// previous date and never "24 hours earlier", which on a 23-hour day is a
// different thing.

import 'package:feature_vocabulary/src/domain/entities/study_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Local wall-clock time, which is what a learner experiences.
  DateTime at(int year, int month, int day, [int hour = 12]) =>
      DateTime(year, month, day, hour);

  StudyCalendar calendarOn(DateTime now, List<DateTime> reviews) =>
      StudyCalendar.from(now: now, reviewedAt: reviews);

  group('streak', () {
    test('is zero for a learner who has never reviewed', () {
      expect(calendarOn(at(2026, 7, 29), []).streakDays, 0);
    });

    test('is one after reviewing for the first time today', () {
      final today = at(2026, 7, 29);
      expect(calendarOn(today, [today]).streakDays, 1);
    });

    test('counts consecutive days', () {
      final today = at(2026, 7, 29);
      final reviews = [
        at(2026, 7, 29),
        at(2026, 7, 28),
        at(2026, 7, 27),
        at(2026, 7, 26),
      ];
      expect(calendarOn(today, reviews).streakDays, 4);
    });

    test('several reviews in one day are still one day', () {
      final today = at(2026, 7, 29);
      final reviews = [
        at(2026, 7, 29, 8),
        at(2026, 7, 29, 13),
        at(2026, 7, 29, 22),
      ];
      expect(calendarOn(today, reviews).streakDays, 1);
    });

    test('survives the morning before today has been studied', () {
      // A streak that ran up to yesterday is not broken at midnight — it is
      // broken by a whole day passing. Resetting it here would show a learner
      // "no streak" every morning for work they had already done.
      final today = at(2026, 7, 29, 7);
      final reviews = [at(2026, 7, 28), at(2026, 7, 27)];
      expect(calendarOn(today, reviews).streakDays, 2);
    });

    test('ends when a whole day was missed', () {
      final today = at(2026, 7, 29);
      final reviews = [
        at(2026, 7, 29),
        at(2026, 7, 28),
        // 27th missed.
        at(2026, 7, 26),
        at(2026, 7, 25),
      ];
      expect(calendarOn(today, reviews).streakDays, 2);
    });

    test('is zero once two days have passed', () {
      final today = at(2026, 7, 29);
      expect(calendarOn(today, [at(2026, 7, 27)]).streakDays, 0);
    });

    test('treats either side of local midnight as two days', () {
      // 11pm and an hour later is two days of studying, and a learner who does
      // that has earned both.
      final now = at(2026, 7, 29, 2);
      final reviews = [at(2026, 7, 28, 23), at(2026, 7, 29, 1)];
      expect(calendarOn(now, reviews).streakDays, 2);
    });
  });

  group('day arithmetic', () {
    test('walks back across a month boundary', () {
      final today = at(2026, 8, 2);
      final reviews = [
        at(2026, 8, 2),
        at(2026, 8, 1),
        at(2026, 7, 31),
        at(2026, 7, 30),
      ];
      expect(calendarOn(today, reviews).streakDays, 4);
    });

    test('walks back across a year boundary', () {
      final today = at(2027, 1, 2);
      final reviews = [
        at(2027, 1, 2),
        at(2027, 1, 1),
        at(2026, 12, 31),
        at(2026, 12, 30),
      ];
      expect(calendarOn(today, reviews).streakDays, 4);
    });

    test('walks back across a leap day', () {
      final today = at(2028, 3, 1);
      final reviews = [at(2028, 3, 1), at(2028, 2, 29), at(2028, 2, 28)];
      expect(calendarOn(today, reviews).streakDays, 3);
    });
  });

  group('today', () {
    test('counts only reviews done today', () {
      final today = at(2026, 7, 29);
      final reviews = [
        at(2026, 7, 29, 9),
        at(2026, 7, 29, 10),
        at(2026, 7, 28, 23),
      ];
      expect(calendarOn(today, reviews).reviewsToday, 2);
    });

    test('is zero before the first review of the day', () {
      final today = at(2026, 7, 29, 6);
      expect(calendarOn(today, [at(2026, 7, 28)]).reviewsToday, 0);
    });
  });

  group('recent activity', () {
    test('returns the requested span, oldest first, ending today', () {
      final today = at(2026, 7, 29);
      final days = calendarOn(today, [at(2026, 7, 29)]).lastDays(7);

      expect(days, hasLength(7));
      expect(days.first.day, DateTime(2026, 7, 23));
      expect(days.last.day, DateTime(2026, 7, 29));
    });

    test('reports quiet days as zero rather than dropping them', () {
      final today = at(2026, 7, 29);
      final days = calendarOn(today, [
        at(2026, 7, 29),
        at(2026, 7, 29),
        at(2026, 7, 26),
      ]).lastDays(7);

      expect(days.map((d) => d.reviews).toList(), [0, 0, 0, 1, 0, 0, 2]);
      expect(days.where((d) => d.studied), hasLength(2));
    });
  });

  test('buckets UTC instants by the local day they land on', () {
    // The data source hands back UTC; everything above is expressed in local
    // time. This is the seam, so it gets its own check.
    final today = at(2026, 7, 29);
    final utcInstants = [
      at(2026, 7, 29, 9).toUtc(),
      at(2026, 7, 28, 9).toUtc(),
    ];

    expect(calendarOn(today, utcInstants).streakDays, 2);
    expect(calendarOn(today, utcInstants).reviewsToday, 1);
  });
}
