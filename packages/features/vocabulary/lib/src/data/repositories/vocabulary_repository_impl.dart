import 'package:architecture/architecture.dart';
import 'package:database/database.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/word.dart';
import '../../domain/repositories/vocabulary_repository.dart';
import '../local/vocabulary_local_data_source.dart';

@LazySingleton(as: VocabularyRepository)
class VocabularyRepositoryImpl implements VocabularyRepository {
  const VocabularyRepositoryImpl(this._local);

  final VocabularyLocalDataSource _local;

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
    return Ok(_toWord(row, await _local.examplesFor([row.id])));
  }

  @override
  Future<Result<void>> deleteWord(int id) async {
    await _local.deleteWord(id);
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
