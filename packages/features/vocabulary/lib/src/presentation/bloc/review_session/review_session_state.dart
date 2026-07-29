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

  ReviewSessionState copyWith({
    ReviewSessionStatus? status,
    List<ReviewCard>? queue,
    bool? isRevealed,
    int? reviewed,
    String? typed,
    bool? wasCorrect,
    String? failureMessage,
  }) => ReviewSessionState(
    status: status ?? this.status,
    queue: queue ?? this.queue,
    isRevealed: isRevealed ?? this.isRevealed,
    reviewed: reviewed ?? this.reviewed,
    typed: typed ?? this.typed,
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
    wasCorrect,
    failureMessage,
    queue.length,
    current?.id,
  );
}
