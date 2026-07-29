import 'package:database/database.dart';
import 'package:injectable/injectable.dart';
import 'package:srs/srs.dart';

import '../seed/seed_pack.dart';

/// Writes a content pack into the learner's vocabulary, once.
///
/// Two rules shape everything here:
///
/// - **Import at most once per pack.** A seed deck row named after the pack id
///   is both the deck and the marker that it has been imported, and it is
///   written inside the same transaction as the words — so a crash halfway
///   leaves nothing behind and the next launch retries cleanly.
/// - **The learner's own data wins.** A word they already captured keeps its
///   cards, its schedule and every field they filled in; the pack only fills
///   what is still null. Recreating cards for a word they have been studying
///   would silently reset its schedule.
@lazySingleton
class SeedLocalDataSource {
  SeedLocalDataSource(this._db, this._scheduler);

  final AppDatabase _db;
  final SrsScheduler _scheduler;

  /// Whether [packId] has been imported already.
  Future<bool> hasImported(String packId) async =>
      await _findSeedDeck(packId) != null;

  /// Imports [pack], returning how many words it added.
  ///
  /// Returns zero when the pack was already imported — the common case on
  /// every launch after the first.
  Future<int> importPack(SeedPack pack, {required DateTime now}) {
    final nowUs = now.toUtc().microsecondsSinceEpoch;

    return _db.transaction(() async {
      if (await _findSeedDeck(pack.id) != null) return 0;

      final deckId = await _db
          .into(_db.decks)
          .insert(
            DecksCompanion.insert(
              name: pack.id,
              isSeed: const Value(true),
              createdAtUs: nowUs,
            ),
          );

      var added = 0;
      for (final entry in pack.entries) {
        final existing = await (_db.select(
          _db.words,
        )..where((w) => w.lemma.equals(entry.lemma))).getSingleOrNull();

        final wordId = existing == null
            ? await _insertWord(entry, nowUs: nowUs)
            : await _fillBlanks(existing, entry, nowUs: nowUs);

        if (existing == null) {
          added++;
          for (final kind in CardKind.values) {
            final fresh = _scheduler.newCard(now: now);
            await _db
                .into(_db.cards)
                .insert(
                  CardsCompanion.insert(
                    wordId: wordId,
                    kind: kind,
                    dueAtUs: fresh.dueAt.microsecondsSinceEpoch,
                  ),
                );
          }
        }

        await _addSentence(entry, wordId: wordId, nowUs: nowUs);

        await _db
            .into(_db.deckWords)
            .insert(DeckWordsCompanion.insert(deckId: deckId, wordId: wordId));
      }
      return added;
    });
  }

  Future<DeckRow?> _findSeedDeck(String packId) =>
      (_db.select(_db.decks)
            ..where((d) => d.name.equals(packId) & d.isSeed.equals(true)))
          .getSingleOrNull();

  Future<int> _insertWord(SeedEntry entry, {required int nowUs}) => _db
      .into(_db.words)
      .insert(
        WordsCompanion.insert(
          lemma: entry.lemma,
          display: entry.display,
          phonetic: Value(entry.phonetic),
          partOfSpeech: Value(entry.partOfSpeech),
          meaningEn: Value(entry.meaningEn),
          meaningVi: Value(entry.meaningVi),
          collocation: Value(entry.collocation),
          // A pack entry arrives complete — meaning, collocation and a
          // sentence — so there is nothing left to fetch for it.
          enrichmentStatus: const Value(EnrichmentStatus.ready),
          createdAtUs: nowUs,
          updatedAtUs: nowUs,
        ),
      );

  /// Fills the fields the learner left empty, and touches nothing else.
  Future<int> _fillBlanks(
    WordRow existing,
    SeedEntry entry, {
    required int nowUs,
  }) async {
    final patch = WordsCompanion(
      phonetic: _ifBlank(existing.phonetic, entry.phonetic),
      partOfSpeech: _ifBlank(existing.partOfSpeech, entry.partOfSpeech),
      meaningEn: _ifBlank(existing.meaningEn, entry.meaningEn),
      meaningVi: _ifBlank(existing.meaningVi, entry.meaningVi),
      collocation: _ifBlank(existing.collocation, entry.collocation),
    );

    if (patch == const WordsCompanion()) return existing.id;

    await (_db.update(_db.words)..where((w) => w.id.equals(existing.id))).write(
      patch.copyWith(
        enrichmentStatus: const Value(EnrichmentStatus.ready),
        updatedAtUs: Value(nowUs),
      ),
    );
    return existing.id;
  }

  /// Adds the pack's sentence unless the learner already has that exact one.
  ///
  /// Their own capture is kept alongside it rather than replaced: the drills
  /// prefer the sentence they actually met the word in.
  Future<void> _addSentence(
    SeedEntry entry, {
    required int wordId,
    required int nowUs,
  }) async {
    final duplicate =
        await (_db.select(_db.examples)..where(
              (e) =>
                  e.wordId.equals(wordId) & e.sentence.equals(entry.sentence),
            ))
            .getSingleOrNull();
    if (duplicate != null) return;

    await _db
        .into(_db.examples)
        .insert(
          ExamplesCompanion.insert(
            wordId: wordId,
            sentence: entry.sentence,
            origin: ExampleOrigin.seed,
            createdAtUs: nowUs,
          ),
        );
  }

  static Value<String?> _ifBlank(String? current, String? incoming) =>
      (current == null && incoming != null)
      ? Value(incoming)
      : const Value.absent();
}
