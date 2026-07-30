// The validation rules live here rather than in the form cubit so another
// caller — the share-sheet capture, later — cannot bypass them.

import 'package:architecture/architecture.dart';
import 'package:database/database.dart' show EnrichmentStatus;
import 'package:feature_vocabulary/feature_vocabulary.dart';
import 'package:feature_vocabulary/src/domain/repositories/vocabulary_repository.dart';
import 'package:feature_vocabulary/src/domain/usecases/add_word.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements VocabularyRepository {}

void main() {
  late _MockRepository repository;
  late AddWord addWord;

  final word = Word(
    id: 1,
    lemma: 'decision',
    display: 'decision',
    enrichmentStatus: EnrichmentStatus.pending,
    createdAt: DateTime.utc(2026, 6, 1),
  );

  setUp(() {
    repository = _MockRepository();
    addWord = AddWord(repository);
    when(
      () => repository.addWord(
        display: any(named: 'display'),
        sentence: any(named: 'sentence'),
      ),
    ).thenAnswer((_) async => Ok(word));
  });

  test('stores a trimmed word', () async {
    final result = await addWord(const AddWordParams(display: '  decision  '));

    expect(result, isA<Ok<Word>>());
    verify(
      () => repository.addWord(
        display: 'decision',
        sentence: null,
      ),
    ).called(1);
  });

  test('rejects an empty box without touching storage', () async {
    final result = await addWord(const AddWordParams(display: '   '));

    expect(result, isA<Err<Word>>());
    verifyNever(
      () => repository.addWord(
        display: any(named: 'display'),
        sentence: any(named: 'sentence'),
      ),
    );
  });

  test('rejects a pasted phrase', () async {
    // A multi-word card is a different feature; silently accepting one would
    // produce a card the drills cannot render.
    final result = await addWord(
      const AddWordParams(display: 'hard decision'),
    );

    expect(result, isA<Err<Word>>());
  });

  test('accepts hyphens, apostrophes and non-Latin scripts', () async {
    for (final input in ['well-known', "don't", 'quyết']) {
      expect(
        await addWord(AddWordParams(display: input)),
        isA<Ok<Word>>(),
        reason: input,
      );
    }
  });

  test('rejects a sentence that does not contain the word', () async {
    // The sentence is the cue the cloze drill blanks out. One without the word
    // in it cannot serve as one.
    final result = await addWord(
      const AddWordParams(
        display: 'decision',
        sentence: 'It was a hard choice.',
      ),
    );

    expect(result, isA<Err<Word>>());
  });

  test('matches the sentence case-insensitively', () async {
    final result = await addWord(
      const AddWordParams(
        display: 'decision',
        sentence: 'Decision time.',
      ),
    );

    expect(result, isA<Ok<Word>>());
  });

  test('treats blank optional fields as absent', () async {
    await addWord(
      const AddWordParams(display: 'decision', sentence: '  '),
    );

    verify(
      () => repository.addWord(
        display: 'decision',
        sentence: null,
      ),
    ).called(1);
  });
}
