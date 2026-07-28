import 'package:drift/drift.dart';

import '../enums.dart';

/// A word the learner is studying.
///
/// One row per [lemma]: meeting "running" after "run" enriches the existing
/// word with another example rather than creating a second entry. Homographs
/// (bank the river, bank the institution) share a row and carry both senses in
/// [meaningEn]; splitting them is not worth a join until the app can actually
/// tell them apart.
///
/// `DateTime` is stored as microseconds since epoch, UTC. Drift's native
/// `dateTime()` reads back a *local* `DateTime`, which is a silent trap for a
/// schema whose whole point is scheduling across time.
@DataClassName('WordRow')
class Words extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Lookup key: lowercased, trimmed. Unique so a re-capture merges.
  TextColumn get lemma => text().unique()();

  /// The word as the learner met it, capitalisation intact.
  TextColumn get display => text()();

  TextColumn get phonetic => text().nullable()();
  TextColumn get partOfSpeech => text().nullable()();
  TextColumn get meaningEn => text().nullable()();
  TextColumn get meaningVi => text().nullable()();

  /// The word's most useful partner ("make a decision").
  ///
  /// Carried on the word itself rather than left to the examples because
  /// knowing what a word goes *with* is most of knowing how to use it.
  TextColumn get collocation => text().nullable()();

  TextColumn get enrichmentStatus =>
      textEnum<EnrichmentStatus>().withDefault(const Constant('pending'))();

  IntColumn get createdAtUs => integer()();
  IntColumn get updatedAtUs => integer()();
}
