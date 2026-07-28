import 'package:meta/meta.dart';

/// How well the learner recalled a card.
///
/// The four grades FSRS expects. [again] means the card was not recalled and
/// is the only grade that counts as a lapse.
enum ReviewGrade {
  again,
  hard,
  good,
  easy;

  /// Whether this grade means the card was not recalled.
  bool get isLapse => this == ReviewGrade.again;
}

/// Where a card sits in its learning cycle.
///
/// A card starts in [learning], graduates to [review], and drops to
/// [relearning] when it is forgotten. The phase decides which step schedule
/// applies, not how long the next interval is.
enum SchedulePhase { learning, review, relearning }

/// A card's scheduling state — everything the scheduler needs to decide when
/// the card comes back, and nothing about what is on it.
///
/// This is the shape that gets persisted, so it is deliberately plain data.
/// [dueAt] and [lastReviewedAt] are always UTC: the scheduler refuses local
/// times, and a database holding mixed zones is a bug that only shows up when
/// the learner travels.
@immutable
class CardSchedule {
  const CardSchedule({
    required this.dueAt,
    this.phase = SchedulePhase.learning,
    this.step = 0,
    this.stability,
    this.difficulty,
    this.lastReviewedAt,
    this.reps = 0,
    this.lapses = 0,
  }) : assert(reps >= 0, 'reps cannot be negative'),
       assert(lapses >= 0, 'lapses cannot be negative');

  final SchedulePhase phase;

  /// Position within the current phase's step list, or null once the card is
  /// in plain review.
  final int? step;

  /// How long the memory is expected to last, in days. Null until first
  /// reviewed.
  final double? stability;

  /// How hard this card is for this learner, 1–10. Null until first reviewed.
  final double? difficulty;

  /// When the card should next be shown. UTC.
  final DateTime dueAt;

  /// When the card was last graded, or null if never. UTC.
  final DateTime? lastReviewedAt;

  /// Total number of times this card has been graded.
  ///
  /// FSRS itself does not need this — it is kept for the learner's own stats
  /// and for reasoning about a card's history after the fact.
  final int reps;

  /// How many times this card was forgotten after having been learned.
  final int lapses;

  /// Whether the card is due at [at] (defaults to now).
  bool isDue({DateTime? at}) => !dueAt.isAfter((at ?? DateTime.now()).toUtc());

  CardSchedule copyWith({
    SchedulePhase? phase,
    int? Function()? step,
    double? stability,
    double? difficulty,
    DateTime? dueAt,
    DateTime? lastReviewedAt,
    int? reps,
    int? lapses,
  }) {
    return CardSchedule(
      phase: phase ?? this.phase,
      step: step == null ? this.step : step(),
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      dueAt: dueAt ?? this.dueAt,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      reps: reps ?? this.reps,
      lapses: lapses ?? this.lapses,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CardSchedule &&
          other.phase == phase &&
          other.step == step &&
          other.stability == stability &&
          other.difficulty == difficulty &&
          other.dueAt == dueAt &&
          other.lastReviewedAt == lastReviewedAt &&
          other.reps == reps &&
          other.lapses == lapses;

  @override
  int get hashCode => Object.hash(
    phase,
    step,
    stability,
    difficulty,
    dueAt,
    lastReviewedAt,
    reps,
    lapses,
  );

  @override
  String toString() =>
      'CardSchedule(phase: $phase, due: $dueAt, stability: $stability, '
      'difficulty: $difficulty, reps: $reps, lapses: $lapses)';
}

/// What one grading produced: the card's new state, and the facts about the
/// review worth writing to an append-only log.
@immutable
class ReviewOutcome {
  const ReviewOutcome({
    required this.schedule,
    required this.grade,
    required this.reviewedAt,
    required this.previousPhase,
    this.elapsed,
  });

  /// The card's state after grading.
  final CardSchedule schedule;

  final ReviewGrade grade;

  /// When the review happened. UTC.
  final DateTime reviewedAt;

  /// The phase the card was in *before* this review.
  ///
  /// Logged rather than derived: the same grade means different things from
  /// review and from relearning, and the post-review phase no longer says
  /// which it was.
  final SchedulePhase previousPhase;

  /// Time since the previous review, or null if this was the first.
  final Duration? elapsed;

  @override
  String toString() =>
      'ReviewOutcome($grade from $previousPhase at $reviewedAt → '
      'due ${schedule.dueAt})';
}
