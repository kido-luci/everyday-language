// Against a real in-memory database, because the behaviour worth testing is
// the transaction: adding a word must produce its three cards or none, and
// meeting a word a second time must enrich it rather than duplicate it.

import 'package:database/database.dart';
import 'package:drift/native.dart';
import 'package:feature_vocabulary/src/data/local/vocabulary_local_data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:srs/srs.dart';

void main() {
  late AppDatabase db;
  late VocabularyLocalDataSource source;

  final now = DateTime.utc(2026, 6, 1, 9);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    source = VocabularyLocalDataSource(db, SrsScheduler(fuzz: false));
  });
  tearDown(() => db.close());

  test('a new word gets one card per kind', () async {
    await source.addWord(display: 'decision', now: now);

    final cards = await db.select(db.cards).get();
    expect(
      cards.map((c) => c.kind).toSet(),
      CardKind.values.toSet(),
      reason: 'recognition and production are separate memories',
    );
    expect(cards.every((c) => c.phase == SchedulePhase.learning), isTrue);
    expect(cards.every((c) => c.dueAtUs == now.microsecondsSinceEpoch), isTrue);
  });

  test('the lemma is lowercased, the display kept as met', () async {
    final row = await source.addWord(display: 'Decision', now: now);

    expect(row.lemma, 'decision');
    expect(row.display, 'Decision');
  });

  test('meeting a word again adds a sentence, not a second word', () async {
    await source.addWord(
      display: 'decision',
      now: now,
      sentence: 'It was a hard decision.',
    );

    await source.addWord(
      display: 'Decision',
      now: now,
      sentence: 'Decision time.',
    );

    expect(await db.select(db.words).get(), hasLength(1));
    expect(await db.select(db.examples).get(), hasLength(2));
    expect(
      await db.select(db.cards).get(),
      hasLength(CardKind.values.length),
      reason: 'only the first encounter creates cards',
    );
  });

  test('a later encounter can fill in a meaning that was missing', () async {
    await source.addWord(display: 'decision', now: now);

    final row = await source.addWord(
      display: 'decision',
      now: now,
      meaningVi: 'quyết định',
    );

    expect(row.meaningVi, 'quyết định');
  });

  test('captured sentences are marked as the learner own', () async {
    await source.addWord(
      display: 'decision',
      now: now,
      sentence: 'It was a hard decision.',
    );

    final example = await db.select(db.examples).getSingle();
    expect(example.origin, ExampleOrigin.userCapture);
  });

  test('deleting a word takes its cards and examples with it', () async {
    final row = await source.addWord(
      display: 'decision',
      now: now,
      sentence: 'It was a hard decision.',
    );

    await source.deleteWord(row.id);

    expect(await db.select(db.words).get(), isEmpty);
    expect(await db.select(db.cards).get(), isEmpty);
    expect(await db.select(db.examples).get(), isEmpty);
  });

  test('lists newest first', () async {
    await source.addWord(display: 'first', now: now);
    await source.addWord(
      display: 'second',
      now: now.add(const Duration(minutes: 1)),
    );

    final words = await source.listWords();
    expect(words.map((w) => w.display), ['second', 'first']);
  });

  group('the enrichment queue', () {
    test('holds the words with no meaning, oldest first', () async {
      await source.addWord(display: 'older', now: now);
      await source.addWord(
        display: 'newer',
        now: now.add(const Duration(minutes: 1)),
      );

      final queue = await source.pendingEnrichment(limit: 10);

      // Oldest first, opposite to the list: a backlog should drain in the
      // order it built up.
      expect(queue.map((w) => w.display), ['older', 'newer']);
    });

    test('drops a word once it has been glossed', () async {
      final row = await source.addWord(display: 'errand', now: now);

      await source.applyGloss(row.id, meaningVi: 'Việc vặt.', now: now);

      expect(await source.pendingEnrichment(limit: 10), isEmpty);
      final stored = await source.findWord(row.id);
      expect(stored!.meaningVi, 'Việc vặt.');
      expect(stored.enrichmentStatus, EnrichmentStatus.ready);
    });

    test('drops a word the dictionary could not help with', () async {
      final row = await source.addWord(display: 'gaslighting', now: now);

      await source.markEnrichmentFailed(row.id, now: now);

      expect(await source.pendingEnrichment(limit: 10), isEmpty);
      expect(
        (await source.findWord(row.id))!.enrichmentStatus,
        EnrichmentStatus.failed,
      );
    });

    test('never writes over a meaning that is already there', () async {
      // The seed pack's own glosses, and anything a future import brings, are
      // not the dictionary's to replace.
      final row = await source.addWord(
        display: 'decision',
        now: now,
        meaningVi: 'quyết định',
      );

      await source.applyGloss(row.id, meaningVi: 'Sự giải quyết.', now: now);

      expect((await source.findWord(row.id))!.meaningVi, 'quyết định');
    });

    test('honours its limit', () async {
      for (final word in ['one', 'two', 'three']) {
        await source.addWord(display: word, now: now);
      }

      expect(await source.pendingEnrichment(limit: 2), hasLength(2));
    });
  });
}
