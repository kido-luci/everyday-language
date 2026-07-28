import 'package:fsrs/fsrs.dart' as fsrs;

import 'card_schedule.dart';

/// Decides when a card comes back.
///
/// A thin adapter over the FSRS algorithm, kept deliberately thin: the maths
/// belongs to `package:fsrs` (published by the team that owns the algorithm),
/// and reimplementing nineteen tuned parameters from a paper is how you get
/// scheduling that is subtly wrong for years without any test noticing —
/// wrong intervals still look like plausible numbers.
///
/// What this class owns instead is the boundary: this project's vocabulary,
/// its persisted shape, and a clock it can be told about. Swapping the engine
/// means rewriting this file and nothing else.
class SrsScheduler {
  /// Creates a scheduler.
  ///
  /// [desiredRetention] is the probability of recall to aim for at review
  /// time. Higher means shorter intervals and more reviews per day; 0.9 is
  /// the FSRS default and a reasonable place to stay until there is real
  /// review data to tune against.
  ///
  /// [fuzz] spreads intervals by a few percent so cards learned together stop
  /// coming back together. Leave it on in the app; turn it off in tests, which
  /// is the only reason it is exposed.
  SrsScheduler({
    double desiredRetention = 0.9,
    Duration maximumInterval = const Duration(days: 36500),
    bool fuzz = true,
  }) : _scheduler = fsrs.Scheduler(
         desiredRetention: desiredRetention,
         maximumInterval: maximumInterval.inDays,
         enableFuzzing: fuzz,
       );

  final fsrs.Scheduler _scheduler;

  /// FSRS identifies cards to keep its own review logs straight. This adapter
  /// is stateless — each call gets the card handed to it — so the id carries
  /// no meaning here and a constant keeps it out of our domain model.
  static const _unusedCardId = 0;

  /// A card that has never been reviewed, due immediately.
  CardSchedule newCard({DateTime? now}) =>
      CardSchedule(dueAt: (now ?? DateTime.now()).toUtc());

  /// Applies [grade] to [schedule] and returns the card's new state.
  ///
  /// [at] defaults to now; pass it to schedule against a known instant. It is
  /// normalised to UTC, so callers may hand over a local time.
  ReviewOutcome grade(
    CardSchedule schedule,
    ReviewGrade grade, {
    DateTime? at,
  }) {
    final reviewedAt = (at ?? DateTime.now()).toUtc();
    final result = _scheduler.reviewCard(
      _toFsrs(schedule),
      _toFsrsRating(grade),
      reviewDateTime: reviewedAt,
    );

    // FSRS tracks neither of these, so they are counted here. A lapse is a
    // failure of a card that had already been learned — failing while still
    // in the learning phase is just not having learned it yet.
    final isLapse = grade.isLapse && schedule.phase == SchedulePhase.review;

    return ReviewOutcome(
      schedule: _fromFsrs(
        result.card,
        reps: schedule.reps + 1,
        lapses: schedule.lapses + (isLapse ? 1 : 0),
      ),
      grade: grade,
      reviewedAt: reviewedAt,
      previousPhase: schedule.phase,
      elapsed: schedule.lastReviewedAt == null
          ? null
          : reviewedAt.difference(schedule.lastReviewedAt!),
    );
  }

  /// The probability of recalling [schedule] at [at], between 0 and 1.
  ///
  /// Returns 1 for a card that has never been reviewed: there is no decay
  /// curve to sample yet.
  double retrievability(CardSchedule schedule, {DateTime? at}) {
    if (schedule.stability == null) return 1;
    return _scheduler.getCardRetrievability(
      _toFsrs(schedule),
      currentDateTime: (at ?? DateTime.now()).toUtc(),
    );
  }

  fsrs.Card _toFsrs(CardSchedule s) => fsrs.Card(
    cardId: _unusedCardId,
    state: switch (s.phase) {
      SchedulePhase.learning => fsrs.State.learning,
      SchedulePhase.review => fsrs.State.review,
      SchedulePhase.relearning => fsrs.State.relearning,
    },
    step: s.step,
    stability: s.stability,
    difficulty: s.difficulty,
    due: s.dueAt,
    lastReview: s.lastReviewedAt,
  );

  CardSchedule _fromFsrs(
    fsrs.Card card, {
    required int reps,
    required int lapses,
  }) => CardSchedule(
    phase: switch (card.state) {
      fsrs.State.learning => SchedulePhase.learning,
      fsrs.State.review => SchedulePhase.review,
      fsrs.State.relearning => SchedulePhase.relearning,
    },
    step: card.step,
    stability: card.stability,
    difficulty: card.difficulty,
    dueAt: card.due.toUtc(),
    lastReviewedAt: card.lastReview?.toUtc(),
    reps: reps,
    lapses: lapses,
  );

  fsrs.Rating _toFsrsRating(ReviewGrade grade) => switch (grade) {
    ReviewGrade.again => fsrs.Rating.again,
    ReviewGrade.hard => fsrs.Rating.hard,
    ReviewGrade.good => fsrs.Rating.good,
    ReviewGrade.easy => fsrs.Rating.easy,
  };
}
