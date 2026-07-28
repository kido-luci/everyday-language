import 'package:drift/drift.dart';
import 'decks_table.dart';
import 'words_table.dart';

/// Which words belong to which decks.
///
/// Many-to-many on purpose: a word met in the wild can also appear in a seed
/// pack, and removing it from one deck must not remove it from the other.
///
/// Deleting a [Decks] row or a [Words] row removes only the membership.
@DataClassName('DeckWordRow')
class DeckWords extends Table {
  IntColumn get deckId => integer()();
  IntColumn get wordId => integer()();

  @override
  Set<Column<Object>> get primaryKey => {deckId, wordId};

  // On the string form, see the foreign-key note in app_database.dart.
  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (deck_id) REFERENCES decks(id) ON DELETE CASCADE',
    'FOREIGN KEY (word_id) REFERENCES words(id) ON DELETE CASCADE',
  ];
}
