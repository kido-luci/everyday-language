import 'package:architecture/architecture.dart';
import 'package:database/database.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_contracts/shared_contracts.dart';

import '../../domain/entities/word.dart';
import '../../domain/repositories/vocabulary_repository.dart';
import '../local/vocabulary_local_data_source.dart';

@LazySingleton(as: VocabularyRepository)
class VocabularyRepositoryImpl implements VocabularyRepository {
  const VocabularyRepositoryImpl(this._local, this._activity);

  final VocabularyLocalDataSource _local;

  /// Announces that the collection changed, so the dashboard's word count and
  /// due count can catch up without being rebuilt.
  final ActivityNotifier _activity;

  @override
  Future<Result<List<Word>>> listWords() async {
    final rows = await _local.listWords();
    final examples = await _local.examplesFor(rows.map((r) => r.id));
    final byWord = <int, List<ExampleRow>>{};
    for (final e in examples) {
      (byWord[e.wordId] ??= []).add(e);
    }
    return Ok([
      for (final row in rows) _toWord(row, byWord[row.id] ?? const []),
    ]);
  }

  @override
  Future<Result<Word>> getWord(int id) async {
    final row = await _local.findWord(id);
    if (row == null) return const Err(NotFoundFailure('Word not found'));
    return Ok(_toWord(row, await _local.examplesFor([id])));
  }

  @override
  Future<Result<Word>> addWord({
    required String display,
    String? sentence,
    String? meaningVi,
  }) async {
    final row = await _local.addWord(
      display: display,
      now: DateTime.now().toUtc(),
      sentence: sentence,
      meaningVi: meaningVi,
    );
    _activity.notifyActivityOccurred();
    return Ok(_toWord(row, await _local.examplesFor([row.id])));
  }

  @override
  Future<Result<void>> deleteWord(int id) async {
    await _local.deleteWord(id);
    _activity.notifyActivityOccurred();
    return const Ok(null);
  }

  @override
  Future<Result<List<Word>>> wordsAwaitingMeaning({
    required int limit,
  }) async {
    final rows = await _local.pendingEnrichment(limit: limit);
    return Ok([for (final row in rows) _toWord(row, const [])]);
  }

  @override
  Future<Result<void>> saveMeaning(
    int wordId, {
    required String meaningVi,
    String? phonetic,
    String? partOfSpeech,
  }) async {
    await _local.applyGloss(
      wordId,
      meaningVi: meaningVi,
      phonetic: phonetic,
      partOfSpeech: partOfSpeech,
      now: DateTime.now().toUtc(),
    );
    // The word list shows the meaning as a subtitle, and the dashboard counts
    // nothing that changed here — but the list is what the learner is looking
    // at while this lands.
    _activity.notifyActivityOccurred();
    return const Ok(null);
  }

  @override
  Future<Result<void>> giveUpOnMeaning(int wordId) async {
    await _local.markEnrichmentFailed(wordId, now: DateTime.now().toUtc());
    // Announced for the same reason a found meaning is. The word tile tells a
    // pending word that "details arrive when you are online"; once the lookup
    // has given up, that sentence is a promise the app will not keep, and it
    // stays on screen until something says otherwise.
    _activity.notifyActivityOccurred();
    return const Ok(null);
  }

  Word _toWord(WordRow row, List<ExampleRow> examples) => Word(
    id: row.id,
    lemma: row.lemma,
    display: row.display,
    phonetic: row.phonetic,
    partOfSpeech: row.partOfSpeech,
    meaningEn: row.meaningEn,
    meaningVi: row.meaningVi,
    collocation: row.collocation,
    enrichmentStatus: row.enrichmentStatus,
    createdAt: DateTime.fromMicrosecondsSinceEpoch(
      row.createdAtUs,
      isUtc: true,
    ),
    examples: [
      for (final e in examples)
        WordExample(
          id: e.id,
          sentence: e.sentence,
          translation: e.translation,
          origin: e.origin,
        ),
    ],
  );
}
