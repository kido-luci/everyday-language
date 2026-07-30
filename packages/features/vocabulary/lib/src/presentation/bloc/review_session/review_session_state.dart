import 'package:meta/meta.dart';

import '../../../domain/entities/review_card.dart';

enum ReviewSessionStatus { loading, reviewing, finished, failure }

@immutable
class ReviewSessionState {
  const ReviewSessionState({
    this.status = ReviewSessionStatus.loading,
    this.queue = const [],
    this.isRevealed = false,
    this.reviewed = 0,
    this.typed = '',
    this.sessionSize = 0,
    this.dueAfter = 0,
    this.wasCorrect,
    this.failureMessage,
  });

  final ReviewSessionStatus status;

  /// Cards still to answer. The head is the one on screen.
  final List<ReviewCard> queue;

  /// Whether the answer is showing. Grading is only possible after it is:
  /// choosing "easy" before seeing the answer is not a judgement about recall.
  final bool isRevealed;

  /// How many gradings this session, counting repeats of the same card.
  final int reviewed;

  /// What the learner has typed for a production card, before submitting.
  final String typed;

  /// How many cards this sitting was handed — the daily goal, or everything
  /// that was due if that was less.
  final int sessionSize;

  /// Cards still due once this sitting ended, counted from storage rather than
  /// inferred: repeats of a relearning card make [reviewed] a poor proxy.
  ///
  /// Only meaningful on [ReviewSessionStatus.finished].
  final int dueAfter;

  /// Whether the submitted answer matched, or null for a card that was not
  /// typed — a recognition card, or one not yet answered.
  ///
  /// Drives which grades are offered: getting it wrong is not a judgement
  /// call, so `ReviewGrade.again` is the only honest option.
  final bool? wasCorrect;

  final String? failureMessage;

  ReviewCard? get current => queue.isEmpty ? null : queue.first;

  /// Whether the card on screen wants the word typed rather than self-graded.
  bool get isTypingDrill => current?.asksForProduction ?? false;

  /// Whether the typed answer is worth submitting.
  bool get canSubmitAnswer => typed.trim().isNotEmpty && !isRevealed;

  /// Cards left including the one on screen.
  int get remaining => queue.length;

  /// Whether finishing this sitting left cards still due today.
  bool get hasMoreDue => dueAfter > 0;

  /// How many the next sitting would serve.
  int get nextSessionSize => dueAfter < sessionSize ? dueAfter : sessionSize;

  ReviewSessionState copyWith({
    ReviewSessionStatus? status,
    List<ReviewCard>? queue,
    bool? isRevealed,
    int? reviewed,
    String? typed,
    int? sessionSize,
    int? dueAfter,
    bool? wasCorrect,
    String? failureMessage,
  }) => ReviewSessionState(
    status: status ?? this.status,
    queue: queue ?? this.queue,
    isRevealed: isRevealed ?? this.isRevealed,
    reviewed: reviewed ?? this.reviewed,
    typed: typed ?? this.typed,
    sessionSize: sessionSize ?? this.sessionSize,
    dueAfter: dueAfter ?? this.dueAfter,
    wasCorrect: wasCorrect,
    failureMessage: failureMessage,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReviewSessionState &&
          other.status == status &&
          other.isRevealed == isRevealed &&
          other.reviewed == reviewed &&
          other.typed == typed &&
          other.sessionSize == sessionSize &&
          other.dueAfter == dueAfter &&
          other.wasCorrect == wasCorrect &&
          other.failureMessage == failureMessage &&
          other.queue.length == queue.length &&
          other.current?.id == current?.id;

  @override
  int get hashCode => Object.hash(
    status,
    isRevealed,
    reviewed,
    typed,
    sessionSize,
    dueAfter,
    wasCorrect,
    failureMessage,
    queue.length,
    current?.id,
  );
}
