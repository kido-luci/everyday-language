import 'package:architecture/architecture.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:database/database.dart' show EnrichmentStatus;
import 'package:feature_vocabulary/feature_vocabulary.dart';
import 'package:feature_vocabulary/src/domain/usecases/delete_word.dart';
import 'package:feature_vocabulary/src/domain/usecases/list_words.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockListWords extends Mock implements ListWords {}

class _MockDeleteWord extends Mock implements DeleteWord {}

Word _word(int id) => Word(
  id: id,
  lemma: 'w$id',
  display: 'w$id',
  enrichmentStatus: EnrichmentStatus.ready,
  createdAt: DateTime.utc(2026, 6, 1),
);

void main() {
  late _MockListWords listWords;
  late _MockDeleteWord deleteWord;

  setUp(() {
    listWords = _MockListWords();
    deleteWord = _MockDeleteWord();
  });

  blocTest<WordsListBloc, WordsListState>(
    'loads the words',
    setUp: () => when(listWords.call).thenAnswer(
      (_) async => Ok([_word(1), _word(2)]),
    ),
    build: () => WordsListBloc(listWords, deleteWord),
    act: (bloc) => bloc.add(const WordsRequested()),
    expect: () => [
      const WordsListState(status: WordsListStatus.loading),
      isA<WordsListState>()
          .having((s) => s.status, 'status', WordsListStatus.ready)
          .having((s) => s.words, 'words', hasLength(2)),
    ],
  );

  blocTest<WordsListBloc, WordsListState>(
    'surfaces a load failure',
    setUp: () => when(
      listWords.call,
    ).thenAnswer((_) async => const Err(UnknownFailure('nope'))),
    build: () => WordsListBloc(listWords, deleteWord),
    act: (bloc) => bloc.add(const WordsRequested()),
    expect: () => [
      const WordsListState(status: WordsListStatus.loading),
      isA<WordsListState>()
          .having((s) => s.status, 'status', WordsListStatus.failure)
          .having((s) => s.failureMessage, 'message', 'nope'),
    ],
  );

  blocTest<WordsListBloc, WordsListState>(
    'drops a deleted word from the list without reloading',
    setUp: () {
      when(listWords.call).thenAnswer((_) async => Ok([_word(1), _word(2)]));
      when(() => deleteWord(1)).thenAnswer((_) async => const Ok(null));
    },
    build: () => WordsListBloc(listWords, deleteWord),
    act: (bloc) async {
      bloc.add(const WordsRequested());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const WordDeleted(1));
    },
    skip: 2,
    expect: () => [
      isA<WordsListState>().having(
        (s) => s.words.map((w) => w.id),
        'remaining ids',
        [2],
      ),
    ],
    // Exactly one load: the initial one. Deleting updates the list in place
    // rather than round-tripping to storage.
    verify: (_) => verify(listWords.call).called(1),
  );

  test('an empty first load is not "nothing here" until it has landed', () {
    // The empty view must not flash while the first load is still running.
    const loading = WordsListState(status: WordsListStatus.loading);
    const ready = WordsListState(status: WordsListStatus.ready);

    expect(loading.isEmpty, isFalse);
    expect(ready.isEmpty, isTrue);
  });
}
