import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:srs/srs.dart';

// The generated part file below resolves the enum types the tables use, and a
// part sees only what its own library imports — Dart imports are not
// transitive, so importing the table files is not enough.
import 'enums.dart';
import 'tables/capture_sources_table.dart';
import 'tables/cards_table.dart';
import 'tables/deck_words_table.dart';
import 'tables/decks_table.dart';
import 'tables/examples_table.dart';
import 'tables/review_logs_table.dart';
import 'tables/words_table.dart';

part 'app_database.g.dart';

/// Single Drift database for the app. Feature data layers receive this via DI
/// and access their respective table accessors.
///
/// **Foreign keys are declared as raw `customConstraints` strings, not with
/// `.references()`.** drift_dev 2.31.0 cannot resolve a reference under the
/// analyzer this SDK ships: it reports "This parameter should be a simple
/// class name" and then emits no constraint at all — the generated
/// `CREATE TABLE` silently contains no `REFERENCES` clause, so nothing
/// cascades and orphan rows accumulate unnoticed. Reproduced with two tables
/// in a single file, so it is not a cross-file resolution problem.
///
/// The strings cost compile-time checking of column names. The schema tests
/// buy it back by asserting the cascades actually fire, which is exactly what
/// a rename would break. Revisit once drift_dev handles this analyzer.
@DriftDatabase(
  tables: [
    Words,
    CaptureSources,
    Examples,
    Decks,
    DeckWords,
    Cards,
    ReviewLogs,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Opens the database in the platform-specific documents directory.
  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'app'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // Still at version 1, so nothing has to migrate yet.
      //
      // To evolve the schema: change the table, bump [schemaVersion], dump
      // the new version (see `drift_schemas/README.md`), then add a branch
      // here — guarded by the version it was introduced in, never by `to`,
      // so an install that skipped releases replays every step in order:
      //
      //     if (from < 2) await m.addColumn(bookmarks, bookmarks.archivedAt);
      //     if (from < 3) await m.createTable(tags);
      //
      // `test/migration_test.dart` then verifies each upgrade path lands on
      // exactly the schema a fresh install would have created.
    },
    beforeOpen: (details) async {
      // SQLite disables foreign-key enforcement by default, and the setting
      // is per-connection — so it has to be re-applied on every open, not
      // just at creation.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
