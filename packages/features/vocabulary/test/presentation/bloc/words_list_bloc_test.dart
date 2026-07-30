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

Word _word(int id, {String? display, String? meaningVi, String? meaningEn}) =>
    Word(
      id: id,
      lemma: (display ?? 'w$id').toLowerCase(),
      display: display ?? 'w$id',
      meaningVi: meaningVi,
      meaningEn: meaningEn,
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

  group('search', () {
    blocTest<WordsListBloc, WordsListState>(
      'narrows the list without going back to storage',
      setUp: () => when(listWords.call).thenAnswer(
        (_) async =>
            Ok([_word(1, display: 'decision'), _word(2, display: 'errand')]),
      ),
      build: () => WordsListBloc(listWords, deleteWord),
      act: (bloc) async {
        bloc.add(const WordsRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const WordsSearched('deci'));
      },
      skip: 2,
      expect: () => [
        isA<WordsListState>()
            .having((s) => s.query, 'query', 'deci')
            .having((s) => s.words, 'words held', hasLength(2))
            .having(
              (s) => s.visibleWords.map((w) => w.display),
              'visible',
              ['decision'],
            ),
      ],
      verify: (_) => verify(listWords.call).called(1),
    );

    blocTest<WordsListBloc, WordsListState>(
      'clearing the query brings everything back',
      setUp: () => when(listWords.call).thenAnswer(
        (_) async => Ok([_word(1, display: 'decision'), _word(2)]),
      ),
      build: () => WordsListBloc(listWords, deleteWord),
      act: (bloc) async {
        bloc.add(const WordsRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const WordsSearched('deci'));
        bloc.add(const WordsSearched(''));
      },
      skip: 3,
      expect: () => [
        isA<WordsListState>()
            .having((s) => s.query, 'query', '')
            .having((s) => s.visibleWords, 'visible', hasLength(2)),
      ],
    );

    test('matches the word whatever the case', () {
      final state = WordsListState(
        status: WordsListStatus.ready,
        words: [_word(1, display: 'Decision')],
        query: 'DECI',
      );

      expect(state.visibleWords, hasLength(1));
    });

    test('matches a meaning, so a half-remembered one finds the word', () {
      final state = WordsListState(
        status: WordsListStatus.ready,
        words: [
          _word(1, display: 'errand', meaningVi: 'việc chạy loăng quăng'),
          _word(2, display: 'decision', meaningEn: 'a choice made'),
        ],
        query: 'choice',
      );

      expect(state.visibleWords.map((w) => w.display), ['decision']);

      final vietnamese = WordsListState(
        status: WordsListStatus.ready,
        words: state.words,
        query: 'loăng quăng',
      );
      expect(vietnamese.visibleWords.map((w) => w.display), ['errand']);
    });

    test('"nothing matches" is not the same as "nothing collected"', () {
      final noMatches = WordsListState(
        status: WordsListStatus.ready,
        words: [_word(1, display: 'decision')],
        query: 'zzz',
      );

      expect(noMatches.hasNoMatches, isTrue);
      expect(noMatches.isEmpty, isFalse);

      const nothingCollected = WordsListState(status: WordsListStatus.ready);
      expect(nothingCollected.hasNoMatches, isFalse);
      expect(nothingCollected.isEmpty, isTrue);
    });

    test('a whitespace-only query is not a query', () {
      final state = WordsListState(
        status: WordsListStatus.ready,
        words: [_word(1), _word(2)],
        query: '   ',
      );

      expect(state.visibleWords, hasLength(2));
      expect(state.hasNoMatches, isFalse);
    });
  });
}
