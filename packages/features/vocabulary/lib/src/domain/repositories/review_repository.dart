import 'package:architecture/architecture.dart';
import 'package:srs/srs.dart';

import '../entities/review_card.dart';

/// The review queue.
abstract interface class ReviewRepository {
  /// Cards due now, most overdue first.
  Future<Result<List<ReviewCard>>> dueCards({int limit});

  /// How many cards are waiting.
  Future<Result<int>> dueCount();

  /// Applies [grade] to [card] and persists both the new schedule and the log
  /// entry. Returns the card's updated schedule.
  Future<Result<CardSchedule>> grade(ReviewCard card, ReviewGrade grade);
}
