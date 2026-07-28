import 'package:drift/drift.dart';
import 'package:srs/srs.dart';
import 'cards_table.dart';

/// One row per grading. Append-only: never updated, never deleted.
///
/// Two reasons it earns its size. FSRS's parameters can be re-fitted against a
/// learner's own history, and only if that history was kept from the start —
/// it cannot be reconstructed later. And "how much did I study this week" is a
/// question about reviews, not about cards.
///
/// [previousPhase] is recorded rather than derived because the same grade
/// means different things from review and from relearning, and the card's
/// phase after the review no longer says which it was.
///
/// Deleting a [Cards] row discards its history along with it.
@DataClassName('ReviewLogRow')
class ReviewLogs extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get cardId => integer()();

  TextColumn get grade => textEnum<ReviewGrade>()();
  TextColumn get previousPhase => textEnum<SchedulePhase>()();

  /// Time since the card's previous review; null when it was the first.
  IntColumn get elapsedMs => integer().nullable()();

  IntColumn get reviewedAtUs => integer()();

  // On the string form, see the foreign-key note in app_database.dart.
  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (card_id) REFERENCES cards(id) ON DELETE CASCADE',
  ];
}
