import 'package:drift/drift.dart';

import '../enums.dart';
import 'capture_sources_table.dart';
import 'words_table.dart';

/// A sentence showing a word in use.
///
/// A word may have several. The one the learner actually met carries
/// [ExampleOrigin.userCapture] and is what the cloze drill prefers: a sentence
/// from your own life is a far better retrieval cue than a generated one.
///
/// Belongs to a [Words] row and, when captured, to a [CaptureSources] row.
@DataClassName('ExampleRow')
class Examples extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get wordId => integer()();

  TextColumn get sentence => text()();
  TextColumn get translation => text().nullable()();

  TextColumn get origin => textEnum<ExampleOrigin>()();

  /// Null for generated sentences, which came from nowhere in particular.
  IntColumn get sourceId => integer().nullable()();

  IntColumn get createdAtUs => integer()();

  // On the string form, see the foreign-key note in app_database.dart.
  //
  // The source is detached rather than cascaded: forgetting where a sentence
  // came from is no reason to lose the sentence, which is still the one the
  // learner met the word in.
  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE',
    'FOREIGN KEY (source_id) REFERENCES capture_sources(id) ON DELETE SET NULL',
  ];
}
