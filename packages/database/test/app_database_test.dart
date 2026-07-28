// Guards the schema's contract: a fresh install lands on the shape the
// generated bindings expect, foreign keys are actually enforced, and the
// constraints protecting the review queue hold.
//
// Schema failures are silent by nature — a missing cascade leaves orphan rows
// that surface as a crash months later, and a missing unique index lets one
// word grow two competing schedules for the same direction.

import 'package:database/database.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:srs/srs.dart';

void main() {
  late AppDatabase db;

  final t0 = DateTime.utc(2026, 6, 1, 9).microsecondsSinceEpoch;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> insertWord({String lemma = 'decision'}) => db
      .into(db.words)
      .insert(
        WordsCompanion.insert(
          lemma: lemma,
          display: lemma,
          createdAtUs: t0,
          updatedAtUs: t0,
        ),
      );

  Future<int> insertCard(int wordId, {CardKind kind = CardKind.recognise}) => db
      .into(db.cards)
      .insert(
        CardsCompanion.insert(wordId: wordId, kind: kind, dueAtUs: t0),
      );

  test('a fresh database matches the schema drift generated', () async {
    // Fails if a table was edited without regenerating the bindings, or if a
    // hand-written migration step drifted from the table definitions.
    await db.validateDatabaseSchema();
  });

  test('foreign key enforcement is on for the connection', () async {
    final result = await db.customSelect('PRAGMA foreign_keys').getSingle();

    expect(result.data.values.first, 1);
  });

  group('words', () {
    test('the same lemma cannot be stored twice', () async {
      await insertWord();

      // Re-capturing a word must merge into the existing row, so the database
      // refuses the second insert rather than leaving the app to notice.
      await expectLater(insertWord(), throwsA(isA<SqliteException>()));
    });

    test('a captured word starts out needing enrichment', () async {
      final id = await insertWord();

      final word = await (db.select(
        db.words,
      )..where((w) => w.id.equals(id))).getSingle();

      expect(word.enrichmentStatus, EnrichmentStatus.pending);
    });
  });

  group('cards', () {
    test('a word may have one card per kind, but not two of a kind', () async {
      final wordId = await insertWord();

      for (final kind in CardKind.values) {
        await insertCard(wordId, kind: kind);
      }

      // Two schedules for the same direction would compete: whichever the
      // review query happened to pick would silently win.
      await expectLater(insertCard(wordId), throwsA(isA<SqliteException>()));
    });

    test('cannot point at a word that does not exist', () async {
      await expectLater(insertCard(999), throwsA(isA<SqliteException>()));
    });

    test('starts unreviewed, with no memory model yet', () async {
      final id = await insertCard(await insertWord());

      final card = await (db.select(
        db.cards,
      )..where((c) => c.id.equals(id))).getSingle();

      expect(card.phase, SchedulePhase.learning);
      expect(card.stability, isNull);
      expect(card.difficulty, isNull);
      expect(card.lastReviewedAtUs, isNull);
      expect(card.reps, 0);
      expect(card.lapses, 0);
    });

    test('goes when its word goes', () async {
      final wordId = await insertWord();
      await insertCard(wordId);

      await (db.delete(db.words)..where((w) => w.id.equals(wordId))).go();

      expect(await db.select(db.cards).get(), isEmpty);
    });
  });

  group('examples', () {
    test('go when their word goes', () async {
      final wordId = await insertWord();
      await db
          .into(db.examples)
          .insert(
            ExamplesCompanion.insert(
              wordId: wordId,
              sentence: 'It was a hard decision.',
              origin: ExampleOrigin.userCapture,
              createdAtUs: t0,
            ),
          );

      await (db.delete(db.words)..where((w) => w.id.equals(wordId))).go();

      expect(await db.select(db.examples).get(), isEmpty);
    });

    test('survive losing the source they were captured from', () async {
      final wordId = await insertWord();
      final sourceId = await db
          .into(db.captureSources)
          .insert(
            CaptureSourcesCompanion.insert(
              kind: CaptureKind.url,
              createdAtUs: t0,
            ),
          );
      await db
          .into(db.examples)
          .insert(
            ExamplesCompanion.insert(
              wordId: wordId,
              sentence: 'It was a hard decision.',
              origin: ExampleOrigin.userCapture,
              sourceId: Value(sourceId),
              createdAtUs: t0,
            ),
          );

      // Forgetting where a sentence came from is no reason to lose the
      // sentence — it is still the one the learner met the word in.
      await (db.delete(
        db.captureSources,
      )..where((s) => s.id.equals(sourceId))).go();

      final examples = await db.select(db.examples).get();
      expect(examples, hasLength(1));
      expect(examples.single.sourceId, isNull);
    });
  });

  group('review logs', () {
    test('record the phase the card came from', () async {
      final cardId = await insertCard(await insertWord());

      await db
          .into(db.reviewLogs)
          .insert(
            ReviewLogsCompanion.insert(
              cardId: cardId,
              grade: ReviewGrade.again,
              previousPhase: SchedulePhase.review,
              reviewedAtUs: t0,
            ),
          );

      final log = await db.select(db.reviewLogs).getSingle();
      expect(log.grade, ReviewGrade.again);
      expect(log.previousPhase, SchedulePhase.review);
      expect(log.elapsedMs, isNull, reason: 'first review of this card');
    });
  });

  group('decks', () {
    test('a word can sit in more than one deck', () async {
      final wordId = await insertWord();
      final mine = await db
          .into(db.decks)
          .insert(DecksCompanion.insert(name: 'My words', createdAtUs: t0));
      final seed = await db
          .into(db.decks)
          .insert(
            DecksCompanion.insert(
              name: 'Everyday 500',
              isSeed: const Value(true),
              createdAtUs: t0,
            ),
          );

      for (final deckId in [mine, seed]) {
        await db
            .into(db.deckWords)
            .insert(DeckWordsCompanion.insert(deckId: deckId, wordId: wordId));
      }

      expect(await db.select(db.deckWords).get(), hasLength(2));
    });

    test('removing a deck leaves its words alone', () async {
      final wordId = await insertWord();
      final deckId = await db
          .into(db.decks)
          .insert(DecksCompanion.insert(name: 'Everyday 500', createdAtUs: t0));
      await db
          .into(db.deckWords)
          .insert(DeckWordsCompanion.insert(deckId: deckId, wordId: wordId));

      await (db.delete(db.decks)..where((d) => d.id.equals(deckId))).go();

      expect(await db.select(db.deckWords).get(), isEmpty);
      expect(await db.select(db.words).get(), hasLength(1));
    });
  });

  group('enum storage', () {
    test('is by name, so reordering an enum cannot reinterpret rows', () async {
      final id = await insertCard(await insertWord(), kind: CardKind.cloze);

      final raw = await db
          .customSelect(
            'SELECT kind FROM cards WHERE id = ?',
            variables: [Variable.withInt(id)],
          )
          .getSingle();

      expect(raw.data['kind'], 'cloze');
    });
  });
}
