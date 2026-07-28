import 'package:drift/drift.dart';

/// A named group of words.
///
/// [isSeed] marks the packs that ship with the app, so "my words" can be told
/// apart from "the starter set" without matching on a name.
@DataClassName('DeckRow')
class Decks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  BoolColumn get isSeed => boolean().withDefault(const Constant(false))();
  IntColumn get createdAtUs => integer()();
}
