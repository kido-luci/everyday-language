import 'package:architecture/architecture.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:database/database.dart' show EnrichmentStatus;
import 'package:feature_vocabulary/feature_vocabulary.dart';
import 'package:feature_vocabulary/src/domain/usecases/add_word.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAddWord extends Mock implements AddWord {}

class _FakeParams extends Fake implements AddWordParams {}

void main() {
  late _MockAddWord addWord;

  final word = Word(
    id: 1,
    lemma: 'decision',
    display: 'decision',
    enrichmentStatus: EnrichmentStatus.pending,
    createdAt: DateTime.utc(2026, 6, 1),
  );

  setUpAll(() => registerFallbackValue(_FakeParams()));
  setUp(() => addWord = _MockAddWord());

  group('a share seeds the form', () {
    blocTest<AddWordCubit, AddWordState>(
      'a shared word fills the word, leaving the sentence empty',
      build: () => AddWordCubit(addWord),
      act: (cubit) => cubit.prefill(word: 'decision'),
      expect: () => [
        isA<AddWordState>()
            .having((s) => s.display, 'display', 'decision')
            .having((s) => s.sentence, 'sentence', ''),
      ],
    );

    blocTest<AddWordCubit, AddWordState>(
      'a shared sentence fills the sentence, leaving the word to the learner',
      build: () => AddWordCubit(addWord),
      act: (cubit) => cubit.prefill(sentence: 'It was a hard decision.'),
      expect: () => [
        isA<AddWordState>()
            .having((s) => s.display, 'display', '')
            .having((s) => s.sentence, 'sentence', 'It was a hard decision.'),
      ],
    );

    blocTest<AddWordCubit, AddWordState>(
      'nothing shared emits nothing',
      build: () => AddWordCubit(addWord),
      act: (cubit) => cubit.prefill(),
      expect: () => <AddWordState>[],
    );
  });

  blocTest<AddWordCubit, AddWordState>(
    'passes what was typed to the use case',
    setUp: () => when(() => addWord(any())).thenAnswer((_) async => Ok(word)),
    build: () => AddWordCubit(addWord),
    act: (cubit) async {
      cubit
        ..displayChanged('decision')
        ..sentenceChanged('It was a hard decision.')
        ..meaningChanged('quyết định');
      await cubit.submit();
    },
    verify: (_) {
      final params = verify(() => addWord(captureAny())).captured.single;
      expect((params as AddWordParams).display, 'decision');
      expect(params.sentence, 'It was a hard decision.');
      expect(params.meaningVi, 'quyết định');
    },
  );

  blocTest<AddWordCubit, AddWordState>(
    'refuses to submit an empty word',
    build: () => AddWordCubit(addWord),
    act: (cubit) => cubit.submit(),
    expect: () => <AddWordState>[],
    verify: (_) => verifyNever(() => addWord(any())),
  );

  blocTest<AddWordCubit, AddWordState>(
    'surfaces the validation message from the use case',
    setUp: () => when(() => addWord(any())).thenAnswer(
      (_) async => const Err(ValidationFailure('Enter a single word')),
    ),
    build: () => AddWordCubit(addWord),
    act: (cubit) async {
      cubit.displayChanged('hard decision');
      await cubit.submit();
    },
    expect: () => [
      isA<AddWordState>().having((s) => s.canSubmit, 'canSubmit', isTrue),
      isA<AddWordState>().having(
        (s) => s.status,
        'status',
        AddWordStatus.submitting,
      ),
      isA<AddWordState>()
          .having((s) => s.status, 'status', AddWordStatus.failure)
          .having((s) => s.failureMessage, 'message', 'Enter a single word'),
    ],
  );

  blocTest<AddWordCubit, AddWordState>(
    'editing again clears the previous failure',
    setUp: () => when(() => addWord(any())).thenAnswer(
      (_) async => const Err(ValidationFailure('nope')),
    ),
    build: () => AddWordCubit(addWord),
    act: (cubit) async {
      cubit.displayChanged('hard decision');
      await cubit.submit();
      cubit.displayChanged('decision');
    },
    skip: 3,
    expect: () => [
      isA<AddWordState>()
          .having((s) => s.status, 'status', AddWordStatus.editing)
          .having((s) => s.failureMessage, 'message', isNull),
    ],
  );

  blocTest<AddWordCubit, AddWordState>(
    'does not submit twice while one is in flight',
    setUp: () => when(() => addWord(any())).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return Ok(word);
    }),
    build: () => AddWordCubit(addWord),
    act: (cubit) async {
      cubit.displayChanged('decision');
      final first = cubit.submit();
      await cubit.submit();
      await first;
    },
    verify: (_) => verify(() => addWord(any())).called(1),
  );
}
