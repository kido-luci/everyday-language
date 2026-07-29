// Against a real in-memory database, because the behaviour worth testing is
// what the transaction does to rows the learner already owns: importing a
// pack must never reset a schedule they have been building, and must never
// run twice.

import 'package:database/database.dart';
import 'package:drift/native.dart';
import 'package:feature_vocabulary/src/data/local/seed_local_data_source.dart';
import 'package:feature_vocabulary/src/data/local/vocabulary_local_data_source.dart';
import 'package:feature_vocabulary/src/data/seed/seed_pack.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:srs/srs.dart';

void main() {
  late AppDatabase db;
  late SeedLocalDataSource seed;
  late VocabularyLocalDataSource vocabulary;

  final now = DateTime.utc(2026, 6, 1, 9);

  const decision = SeedEntry(
    display: 'decision',
    phonetic: '/dɪˈsɪʒn/',
    partOfSpeech: 'noun',
    meaningEn: 'a choice you make after weighing the options',
    meaningVi: 'quyết định',
    collocation: 'make a decision',
    sentence: 'We put off the decision until we had seen the numbers.',
  );

  const deadline = SeedEntry(
    display: 'deadline',
    meaningEn: 'the time by which something has to be finished',
    collocation: 'meet a deadline',
    sentence: 'We will not hit that deadline without dropping a feature.',
  );

  SeedPack packOf(List<SeedEntry> entries, {String id = 'everyday-v1'}) =>
      SeedPack(id: id, name: 'Everyday starter', entries: entries);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    final scheduler = SrsScheduler(fuzz: false);
    seed = SeedLocalDataSource(db, scheduler);
    vocabulary = VocabularyLocalDataSource(db, scheduler);
  });
  tearDown(() => db.close());

  group('a first import', () {
    test('stores the words, their sentences and their cards', () async {
      final added = await seed.importPack(
        packOf([decision, deadline]),
        now: now,
      );

      expect(added, 2);
      expect(await db.select(db.words).get(), hasLength(2));
      expect(await db.select(db.examples).get(), hasLength(2));
      expect(
        await db.select(db.cards).get(),
        hasLength(2 * CardKind.values.length),
      );
    });

    test('carries every field the pack had', () async {
      await seed.importPack(packOf([decision]), now: now);

      final word = (await db.select(db.words).get()).single;
      expect(word.lemma, 'decision');
      expect(word.phonetic, '/dɪˈsɪʒn/');
      expect(word.partOfSpeech, 'noun');
      expect(word.meaningEn, decision.meaningEn);
      expect(word.meaningVi, 'quyết định');
      expect(word.collocation, 'make a decision');
      expect(
        word.enrichmentStatus,
        EnrichmentStatus.ready,
        reason: 'a pack entry arrives complete; there is nothing left to fetch',
      );
    });

    test('marks the sentence as coming from the pack', () async {
      await seed.importPack(packOf([decision]), now: now);

      final example = (await db.select(db.examples).get()).single;
      expect(example.origin, ExampleOrigin.seed);
      expect(example.sentence, decision.sentence);
    });

    test('files the words under one seed deck', () async {
      await seed.importPack(packOf([decision, deadline]), now: now);

      final deck = (await db.select(db.decks).get()).single;
      expect(deck.name, 'everyday-v1');
      expect(deck.isSeed, isTrue);
      expect(await db.select(db.deckWords).get(), hasLength(2));
    });
  });

  group('importing again', () {
    test('adds nothing the second time', () async {
      await seed.importPack(packOf([decision]), now: now);
      final added = await seed.importPack(
        packOf([decision, deadline]),
        now: now,
      );

      expect(added, 0);
      expect(
        await db.select(db.words).get(),
        hasLength(1),
        reason:
            'the pack was already imported; a later edition of it is a '
            'new pack, not a reason to re-read this one',
      );
    });

    test('is reported by hasImported', () async {
      expect(await seed.hasImported('everyday-v1'), isFalse);
      await seed.importPack(packOf([decision]), now: now);
      expect(await seed.hasImported('everyday-v1'), isTrue);
      expect(await seed.hasImported('everyday-v2'), isFalse);
    });

    test('a different pack id imports alongside the first', () async {
      await seed.importPack(packOf([decision]), now: now);
      final added = await seed.importPack(
        packOf([deadline], id: 'everyday-v2'),
        now: now,
      );

      expect(added, 1);
      expect(await db.select(db.decks).get(), hasLength(2));
    });
  });

  group('a word the learner already has', () {
    setUp(() async {
      await vocabulary.addWord(
        display: 'Decision',
        now: now.subtract(const Duration(days: 30)),
        sentence: 'Big decision today.',
        meaningVi: 'chọn lựa',
      );
    });

    test(
      'is not counted, duplicated, or given a second set of cards',
      () async {
        final added = await seed.importPack(packOf([decision]), now: now);

        expect(added, 0, reason: 'nothing new was added, only filled in');
        expect(await db.select(db.words).get(), hasLength(1));
        expect(
          await db.select(db.cards).get(),
          hasLength(CardKind.values.length),
          reason:
              'a second set of cards would reset a schedule they have been '
              'building for a month',
        );
      },
    );

    test('keeps what they typed and fills only what was blank', () async {
      await seed.importPack(packOf([decision]), now: now);

      final word = (await db.select(db.words).get()).single;
      expect(word.display, 'Decision', reason: 'as they met it');
      expect(word.meaningVi, 'chọn lựa', reason: 'theirs, not the pack’s');
      expect(word.meaningEn, decision.meaningEn, reason: 'was blank');
      expect(word.collocation, 'make a decision', reason: 'was blank');
      expect(word.enrichmentStatus, EnrichmentStatus.ready);
    });

    test('keeps their own sentence and adds the pack’s beside it', () async {
      await seed.importPack(packOf([decision]), now: now);

      final examples = await db.select(db.examples).get();
      expect(examples, hasLength(2));
      expect(
        examples.map((e) => e.origin),
        containsAll([ExampleOrigin.userCapture, ExampleOrigin.seed]),
      );
    });

    test('is filed under the seed deck too', () async {
      await seed.importPack(packOf([decision]), now: now);

      expect(await db.select(db.deckWords).get(), hasLength(1));
    });
  });

  test('does not add a sentence the word already has', () async {
    await vocabulary.addWord(
      display: 'decision',
      now: now,
      sentence: decision.sentence,
    );

    await seed.importPack(packOf([decision]), now: now);

    expect(await db.select(db.examples).get(), hasLength(1));
  });

  test('a failure part-way leaves nothing behind', () async {
    // The deck row is written first and is also the "already imported" marker.
    // If it survived a failed import, the next launch would consider the pack
    // done and the learner would never receive it — so the rollback has to
    // take the deck with it, not just the words.
    final failing = SeedLocalDataSource(db, _SchedulerThatFails(afterCards: 4));

    await expectLater(
      failing.importPack(packOf([decision, deadline]), now: now),
      throwsA(isA<StateError>()),
    );

    expect(await db.select(db.words).get(), isEmpty);
    expect(await db.select(db.examples).get(), isEmpty);
    expect(await db.select(db.decks).get(), isEmpty);
    expect(await seed.hasImported('everyday-v1'), isFalse);
  });
}

/// Throws once it has handed out [afterCards] cards, to break an import
/// mid-transaction the way a real fault would.
class _SchedulerThatFails extends SrsScheduler {
  _SchedulerThatFails({required this.afterCards}) : super(fuzz: false);

  final int afterCards;
  int _handedOut = 0;

  @override
  CardSchedule newCard({DateTime? now}) {
    if (_handedOut++ >= afterCards) throw StateError('scheduler failed');
    return super.newCard(now: now);
  }
}
