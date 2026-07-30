// The sweep that fills in meanings. The distinction these tests exist to
// protect: "the dictionary has no such word" is a permanent answer, "the
// request failed" is not — and confusing the two would let one flight without
// signal blank a word for good.

import 'package:architecture/architecture.dart';
import 'package:database/database.dart' show EnrichmentStatus;
import 'package:feature_vocabulary/feature_vocabulary.dart';
import 'package:feature_vocabulary/src/data/remote/wiktionary_client.dart';
import 'package:feature_vocabulary/src/data/remote/wiktionary_gloss.dart';
import 'package:feature_vocabulary/src/domain/repositories/vocabulary_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements VocabularyRepository {}

class _MockClient extends Mock implements WiktionaryClient {}

Word _word(int id, String display) => Word(
  id: id,
  lemma: display,
  display: display,
  enrichmentStatus: EnrichmentStatus.pending,
  createdAt: DateTime.utc(2026, 6, 1),
);

void main() {
  late _MockRepository repository;
  late _MockClient client;
  late WordEnricher enricher;

  setUp(() {
    repository = _MockRepository();
    client = _MockClient();
    enricher = WordEnricher(repository, client);

    when(
      () => repository.saveMeaning(
        any(),
        meaningVi: any(named: 'meaningVi'),
        phonetic: any(named: 'phonetic'),
        partOfSpeech: any(named: 'partOfSpeech'),
      ),
    ).thenAnswer((_) async => const Ok(null));
    when(() => repository.giveUpOnMeaning(any())).thenAnswer(
      (_) async => const Ok(null),
    );
  });

  void pending(List<Word> words) => when(
    () => repository.wordsAwaitingMeaning(limit: any(named: 'limit')),
  ).thenAnswer((_) async => Ok(words));

  test('a found gloss is stored against the word', () async {
    pending([_word(1, 'errand')]);
    when(() => client.lookUp('errand')).thenAnswer(
      (_) async => const LookupFound(
        WordGloss(
          meaningVi: 'Việc vặt.',
          phonetic: '/ˈɛr.ənd/',
          partOfSpeech: 'Danh từ',
        ),
      ),
    );

    await enricher.sweep();

    verify(
      () => repository.saveMeaning(
        1,
        meaningVi: 'Việc vặt.',
        phonetic: '/ˈɛr.ənd/',
        partOfSpeech: 'Danh từ',
      ),
    ).called(1);
  });

  test('a word the dictionary does not have is given up on', () async {
    pending([_word(1, 'gaslighting')]);
    when(
      () => client.lookUp('gaslighting'),
    ).thenAnswer((_) async => const LookupAbsent());

    await enricher.sweep();

    verify(() => repository.giveUpOnMeaning(1)).called(1);
    verifyNever(
      () => repository.saveMeaning(
        any(),
        meaningVi: any(named: 'meaningVi'),
        phonetic: any(named: 'phonetic'),
        partOfSpeech: any(named: 'partOfSpeech'),
      ),
    );
  });

  test(
    'a failed request leaves the word pending, and stops the sweep',
    () async {
      pending([_word(1, 'errand'), _word(2, 'decision')]);
      when(
        () => client.lookUp(any()),
      ).thenAnswer((_) async => const LookupFailed());

      await enricher.sweep();

      // Neither written off nor written to: it will be asked again next launch.
      verifyNever(() => repository.giveUpOnMeaning(any()));
      verifyNever(
        () => repository.saveMeaning(
          any(),
          meaningVi: any(named: 'meaningVi'),
          phonetic: any(named: 'phonetic'),
          partOfSpeech: any(named: 'partOfSpeech'),
        ),
      );
      // And the rest of the batch is not hammered while the network is down.
      verify(() => client.lookUp('errand')).called(1);
      verifyNever(() => client.lookUp('decision'));
    },
  );

  test("the batch is bounded — it is someone else's free service", () async {
    pending([_word(1, 'errand')]);
    when(
      () => client.lookUp(any()),
    ).thenAnswer((_) async => const LookupAbsent());

    await enricher.sweep();

    verify(
      () => repository.wordsAwaitingMeaning(limit: WordEnricher.batchSize),
    ).called(1);
  });

  test('two sweeps at once do not ask the same questions twice', () async {
    pending([_word(1, 'errand')]);
    when(() => client.lookUp(any())).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return const LookupAbsent();
    });

    // Capturing two words in a row fires two sweeps.
    await Future.wait([enricher.sweep(), enricher.sweep()]);

    verify(() => client.lookUp('errand')).called(1);
  });

  test('a sweep with nothing pending asks the dictionary nothing', () async {
    pending([]);

    await enricher.sweep();

    verifyNever(() => client.lookUp(any()));
  });

  test('an unreadable queue is survived rather than thrown', () async {
    when(
      () => repository.wordsAwaitingMeaning(limit: any(named: 'limit')),
    ).thenAnswer((_) async => const Err(UnknownFailure('database is busy')));

    await expectLater(enricher.sweep(), completes);
    verifyNever(() => client.lookUp(any()));
  });
}
