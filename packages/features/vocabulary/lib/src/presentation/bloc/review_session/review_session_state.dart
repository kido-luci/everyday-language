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

  final String? failureMessage;

  ReviewCard? get current => queue.isEmpty ? null : queue.first;

  /// Cards left including the one on screen.
  int get remaining => queue.length;

  ReviewSessionState copyWith({
    ReviewSessionStatus? status,
    List<ReviewCard>? queue,
    bool? isRevealed,
    int? reviewed,
    String? failureMessage,
  }) => ReviewSessionState(
    status: status ?? this.status,
    queue: queue ?? this.queue,
    isRevealed: isRevealed ?? this.isRevealed,
    reviewed: reviewed ?? this.reviewed,
    failureMessage: failureMessage,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReviewSessionState &&
          other.status == status &&
          other.isRevealed == isRevealed &&
          other.reviewed == reviewed &&
          other.failureMessage == failureMessage &&
          other.queue.length == queue.length &&
          other.current?.id == current?.id;

  @override
  int get hashCode => Object.hash(
    status,
    isRevealed,
    reviewed,
    failureMessage,
    queue.length,
    current?.id,
  );
}
