import 'package:drift/drift.dart';
import 'package:srs/srs.dart';

import '../enums.dart';
import 'words_table.dart';

/// One studiable direction of a word, with its scheduling state.
///
/// Three per word (see [CardKind]), each scheduled independently: recognising
/// a word and being able to produce it are different memories and decay at
/// different rates. Unique on (word, kind) so a word cannot end up with two
/// competing schedules for the same direction — whichever the review query
/// happened to pick would silently win.
///
/// The scheduling columns mirror `CardSchedule` in `package:srs`; this table
/// is where that value object is persisted, so the names deliberately match.
/// [stability] and [difficulty] are null until the first review — there is no
/// memory model to speak of before then.
///
/// Times are microseconds since epoch, UTC. Deleting the owning [Words]
/// row takes its cards with it.
@DataClassName('CardRow')
class Cards extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get wordId => integer()();

  TextColumn get kind => textEnum<CardKind>()();

  TextColumn get phase =>
      textEnum<SchedulePhase>().withDefault(const Constant('learning'))();

  /// Position within the current phase's step list; null in plain review.
  IntColumn get step => integer().nullable()();

  RealColumn get stability => real().nullable()();
  RealColumn get difficulty => real().nullable()();

  IntColumn get dueAtUs => integer()();
  IntColumn get lastReviewedAtUs => integer().nullable()();

  IntColumn get reps => integer().withDefault(const Constant(0))();
  IntColumn get lapses => integer().withDefault(const Constant(0))();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {wordId, kind},
  ];

  // On the string form, see the foreign-key note in app_database.dart.
  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE',
  ];
}
