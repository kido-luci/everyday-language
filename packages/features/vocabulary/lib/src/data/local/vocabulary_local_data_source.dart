import 'package:database/database.dart';
import 'package:injectable/injectable.dart';
import 'package:srs/srs.dart';

/// Drift-backed storage for the learner's vocabulary.
///
/// Owns the writes that must not half-happen: adding a word inserts the word,
/// its first example and one card per [CardKind] in a single transaction, so a
/// crash can never leave a word with two of its three cards.
@lazySingleton
class VocabularyLocalDataSource {
  VocabularyLocalDataSource(this._db, this._scheduler);

  final AppDatabase _db;

  /// Consulted for what an unreviewed card looks like, rather than hard-coding
  /// it here — that shape belongs to the scheduler.
  final SrsScheduler _scheduler;

  Future<List<WordRow>> listWords() => (_db.select(
    _db.words,
  )..orderBy([(w) => OrderingTerm.desc(w.createdAtUs)])).get();

  Future<WordRow?> findWord(int id) =>
      (_db.select(_db.words)..where((w) => w.id.equals(id))).getSingleOrNull();

  Future<WordRow?> findByLemma(String lemma) => (_db.select(
    _db.words,
  )..where((w) => w.lemma.equals(lemma))).getSingleOrNull();

  /// Words still waiting for a meaning, oldest first.
  ///
  /// Oldest first so a backlog drains in the order it built up, and the word
  /// captured last week is not stuck behind everything captured since.
  Future<List<WordRow>> pendingEnrichment({required int limit}) =>
      (_db.select(_db.words)
            ..where(
              (w) => w.enrichmentStatus.equalsValue(
                EnrichmentStatus.pending,
              ),
            )
            ..orderBy([(w) => OrderingTerm.asc(w.createdAtUs)])
            ..limit(limit))
          .get();

  /// Stores a looked-up meaning and marks the word done.
  ///
  /// Leaves a meaning that is already there alone: the learner's own words are
  /// never overwritten by a dictionary, and re-running the sweep is harmless.
  Future<void> applyGloss(
    int wordId, {
    required String meaningVi,
    String? phonetic,
    String? partOfSpeech,
    required DateTime now,
  }) async {
    final existing = await findWord(wordId);
    if (existing == null) return;

    await (_db.update(_db.words)..where((w) => w.id.equals(wordId))).write(
      WordsCompanion(
        meaningVi: Value(existing.meaningVi ?? meaningVi),
        phonetic: Value(existing.phonetic ?? phonetic),
        partOfSpeech: Value(existing.partOfSpeech ?? partOfSpeech),
        enrichmentStatus: const Value(EnrichmentStatus.ready),
        updatedAtUs: Value(now.toUtc().microsecondsSinceEpoch),
      ),
    );
  }

  /// Marks a word the dictionary does not have, so the sweep stops asking.
  Future<void> markEnrichmentFailed(int wordId, {required DateTime now}) =>
      (_db.update(_db.words)..where((w) => w.id.equals(wordId))).write(
        WordsCompanion(
          enrichmentStatus: const Value(EnrichmentStatus.failed),
          updatedAtUs: Value(now.toUtc().microsecondsSinceEpoch),
        ),
      );

  Future<List<ExampleRow>> examplesFor(Iterable<int> wordIds) {
    if (wordIds.isEmpty) return Future.value(const []);
    return (_db.select(_db.examples)
          ..where((e) => e.wordId.isIn(wordIds))
          ..orderBy([(e) => OrderingTerm.asc(e.createdAtUs)]))
        .get();
  }

  /// Stores [display] as a word, or enriches the one already there.
  ///
  /// Re-adding a word the learner already has is the common case, not an
  /// error: meeting "decision" a second time in a different sentence should
  /// add that sentence, not a second word. Only the first encounter creates
  /// cards.
  Future<WordRow> addWord({
    required String display,
    required DateTime now,
    String? sentence,
    String? meaningVi,
  }) {
    final lemma = display.toLowerCase();
    final nowUs = now.toUtc().microsecondsSinceEpoch;

    return _db.transaction(() async {
      final existing = await findByLemma(lemma);

      final wordId = existing != null
          ? existing.id
          : await _db
                .into(_db.words)
                .insert(
                  WordsCompanion.insert(
                    lemma: lemma,
                    display: display,
                    meaningVi: Value(meaningVi),
                    createdAtUs: nowUs,
                    updatedAtUs: nowUs,
                  ),
                );

      if (existing == null) {
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
      } else if (meaningVi != null) {
        await (_db.update(_db.words)..where((w) => w.id.equals(wordId))).write(
          WordsCompanion(
            meaningVi: Value(meaningVi),
            updatedAtUs: Value(nowUs),
          ),
        );
      }

      if (sentence != null) {
        await _db
            .into(_db.examples)
            .insert(
              ExamplesCompanion.insert(
                wordId: wordId,
                sentence: sentence,
                origin: ExampleOrigin.userCapture,
                createdAtUs: nowUs,
              ),
            );
      }

      return (await findWord(wordId))!;
    });
  }

  /// Removes a word. Its examples and cards go with it, by cascade.
  Future<void> deleteWord(int id) =>
      (_db.delete(_db.words)..where((w) => w.id.equals(id))).go();
}
