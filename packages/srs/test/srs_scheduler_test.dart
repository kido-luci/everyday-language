// These tests are about the adapter, not the algorithm. `package:fsrs` owns
// the maths and tests it; what can break here is the boundary — a phase mapped
// to the wrong state, a UTC conversion dropped, reps and lapses miscounted.
//
// Fuzzing is off throughout: it exists to stop cards learned together coming
// back together, and it would make every interval assertion flaky.

import 'package:srs/srs.dart';
import 'package:test/test.dart';

void main() {
  late SrsScheduler scheduler;

  // A fixed instant so every assertion reads against a known clock.
  final t0 = DateTime.utc(2026, 6, 1, 9);

  setUp(() => scheduler = SrsScheduler(fuzz: false));

  group('newCard', () {
    test('is due immediately and unreviewed', () {
      final card = scheduler.newCard(now: t0);

      expect(card.dueAt, t0);
      expect(card.phase, SchedulePhase.learning);
      expect(card.stability, isNull);
      expect(card.difficulty, isNull);
      expect(card.lastReviewedAt, isNull);
      expect(card.reps, 0);
      expect(card.lapses, 0);
      expect(card.isDue(at: t0), isTrue);
    });

    test('normalises a local clock to UTC', () {
      final local = DateTime(2026, 6, 1, 9);

      final card = scheduler.newCard(now: local);

      expect(card.dueAt.isUtc, isTrue);
      expect(card.dueAt, local.toUtc());
    });
  });

  group('grade', () {
    test('a first review starts the memory model and schedules ahead', () {
      final card = scheduler.newCard(now: t0);

      final outcome = scheduler.grade(card, ReviewGrade.good, at: t0);

      expect(outcome.schedule.stability, isNotNull);
      expect(outcome.schedule.difficulty, inInclusiveRange(1, 10));
      expect(outcome.schedule.dueAt.isAfter(t0), isTrue);
      expect(outcome.schedule.lastReviewedAt, t0);
      expect(outcome.reviewedAt, t0);
      expect(outcome.previousPhase, SchedulePhase.learning);
      expect(outcome.elapsed, isNull, reason: 'no previous review to measure');
    });

    test('better grades never schedule sooner than worse ones', () {
      // The ordering is the contract the review UI depends on; the exact
      // intervals belong to FSRS and are deliberately not asserted.
      final card = scheduler.newCard(now: t0);

      final due = [
        for (final g in ReviewGrade.values)
          scheduler.grade(card, g, at: t0).schedule.dueAt,
      ];

      for (var i = 1; i < due.length; i++) {
        expect(
          due[i].isBefore(due[i - 1]),
          isFalse,
          reason:
              '${ReviewGrade.values[i]} came sooner than '
              '${ReviewGrade.values[i - 1]}',
        );
      }
    });

    test('counts every review, and only real lapses', () {
      var card = scheduler.newCard(now: t0);

      // Failing while still learning is not a lapse — the card was never
      // learned in the first place.
      card = scheduler.grade(card, ReviewGrade.again, at: t0).schedule;
      expect(card.reps, 1);
      expect(card.lapses, 0);

      // Drive it into review, then fail it.
      var at = t0;
      while (card.phase != SchedulePhase.review) {
        at = card.dueAt;
        card = scheduler.grade(card, ReviewGrade.easy, at: at).schedule;
      }
      final repsBefore = card.reps;

      card = scheduler.grade(card, ReviewGrade.again, at: card.dueAt).schedule;

      expect(card.reps, repsBefore + 1);
      expect(card.lapses, 1, reason: 'forgetting a learned card is a lapse');
      expect(card.phase, SchedulePhase.relearning);
    });

    test('reports the phase the card came from, not the one it lands in', () {
      var card = scheduler.newCard(now: t0);
      var at = t0;
      while (card.phase != SchedulePhase.review) {
        at = card.dueAt;
        card = scheduler.grade(card, ReviewGrade.easy, at: at).schedule;
      }

      final outcome = scheduler.grade(card, ReviewGrade.again, at: card.dueAt);

      expect(outcome.previousPhase, SchedulePhase.review);
      expect(outcome.schedule.phase, SchedulePhase.relearning);
    });

    test('measures elapsed time from the previous review', () {
      final card = scheduler.newCard(now: t0);
      final first = scheduler.grade(card, ReviewGrade.good, at: t0).schedule;
      final later = t0.add(const Duration(days: 3));

      final outcome = scheduler.grade(first, ReviewGrade.good, at: later);

      expect(outcome.elapsed, const Duration(days: 3));
    });

    test('accepts a local clock and keeps everything UTC', () {
      final card = scheduler.newCard(now: t0);

      final outcome = scheduler.grade(
        card,
        ReviewGrade.good,
        at: DateTime(2026, 6, 1, 12),
      );

      expect(outcome.reviewedAt.isUtc, isTrue);
      expect(outcome.schedule.dueAt.isUtc, isTrue);
      expect(outcome.schedule.lastReviewedAt!.isUtc, isTrue);
    });

    test('leaves the card it was given untouched', () {
      final card = scheduler.newCard(now: t0);

      scheduler.grade(card, ReviewGrade.easy, at: t0);

      expect(card.reps, 0);
      expect(card.stability, isNull);
      expect(card.dueAt, t0);
    });
  });

  group('retrievability', () {
    test('is 1 for a card that has never been reviewed', () {
      expect(scheduler.retrievability(scheduler.newCard(now: t0), at: t0), 1);
    });

    test('decays as time passes since the review', () {
      final card = scheduler.newCard(now: t0);
      final reviewed = scheduler.grade(card, ReviewGrade.good, at: t0).schedule;

      final sameDay = scheduler.retrievability(reviewed, at: t0);
      final aWeekOn = scheduler.retrievability(
        reviewed,
        at: t0.add(const Duration(days: 7)),
      );

      expect(sameDay, inInclusiveRange(0, 1));
      expect(aWeekOn, lessThan(sameDay));
    });
  });

  group('desiredRetention', () {
    test('aiming higher brings the card back sooner', () {
      // The knob most likely to be turned once there is real review data, so
      // its direction is worth pinning down.
      final card = SrsScheduler(fuzz: false).newCard(now: t0);

      final relaxed = SrsScheduler(
        desiredRetention: 0.8,
        fuzz: false,
      ).grade(card, ReviewGrade.good, at: t0).schedule.dueAt;
      final strict = SrsScheduler(
        desiredRetention: 0.95,
        fuzz: false,
      ).grade(card, ReviewGrade.good, at: t0).schedule.dueAt;

      expect(strict.isAfter(relaxed), isFalse);
    });
  });

  group('isDue', () {
    test('a card is due at its due instant, not only after it', () {
      final card = CardSchedule(dueAt: t0);

      expect(card.isDue(at: t0.subtract(const Duration(seconds: 1))), isFalse);
      expect(card.isDue(at: t0), isTrue);
      expect(card.isDue(at: t0.add(const Duration(seconds: 1))), isTrue);
    });
  });
}
