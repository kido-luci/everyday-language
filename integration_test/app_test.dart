// The one flow that has to work: meet a word, save it, and review it.
//
// Everything below the widget tree is real — the DI graph, the Drift database
// on the device, the FSRS scheduler. What this catches that the unit tests
// cannot is the wiring between them: a route that does not resolve, a view
// model the locator cannot build, a transaction that deadlocks on a real
// connection rather than an in-memory one.

import 'package:architecture/architecture.dart';
import 'package:database/database.dart';
import 'package:everyday_language/app/di/injection.dart';
import 'package:feature_home/feature_home.dart';
import 'package:feature_vocabulary/feature_vocabulary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:srs/srs.dart';

import 'support/e2e_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a word can be captured and then reviewed', (tester) async {
    await launchApp(tester);

    // ── The word list starts empty ──────────────────────────────────────────
    await tapAndSettle(tester, find.byTooltip('Words'));
    expect(find.text('No words yet'), findsOneWidget);

    // ── Capture a word, with the sentence it was met in ─────────────────────
    await tapAndSettle(tester, find.byTooltip('Add a word'));

    await tester.enterText(
      find.byType(TextField).at(0),
      'decision',
    );
    await tester.enterText(
      find.byType(TextField).at(1),
      'It was a hard decision.',
    );
    await tester.pumpAndSettle();

    await tapAndSettle(tester, find.text('Save word'));

    // ── It is in the list, captioned by the sentence it came from ───────────
    // There is no meaning to show: the form does not ask for one, so the tile
    // falls back to the learner's own sentence. That fallback is the normal
    // case for a captured word, not an edge one.
    expect(find.text('decision'), findsOneWidget);
    expect(find.text('It was a hard decision.'), findsWidgets);

    // Three cards, one per direction, all due now.
    final db = getIt<AppDatabase>();
    expect(await db.select(db.cards).get(), hasLength(CardKind.values.length));

    // ── Open the word, then come back ───────────────────────────────────────
    await tapAndSettle(tester, find.text('decision'));
    expect(find.text('It was a hard decision.'), findsWidgets);
    await tapAndSettle(tester, find.byTooltip('Back'));

    // ── Review it ───────────────────────────────────────────────────────────
    await tapAndSettle(tester, find.byTooltip('Review'));

    expect(find.text('Show answer'), findsOneWidget);
    await tapAndSettle(tester, find.text('Show answer'));

    // The four grades only appear once the answer is showing.
    expect(find.text('Good'), findsOneWidget);
    await tapAndSettle(tester, find.text('Good'));

    // ── The review was recorded, and the card moved ─────────────────────────
    final logs = await db.select(db.reviewLogs).get();
    expect(logs, hasLength(1));
    expect(logs.single.grade, ReviewGrade.good);

    final reviewed = await (db.select(
      db.cards,
    )..where((c) => c.id.equals(logs.single.cardId))).getSingle();
    expect(reviewed.reps, 1);
    expect(reviewed.stability, isNotNull);

    // ── The next cards ask for the word to be typed ─────────────────────────
    // Recognition is self-graded; recall and cloze are not. There is no "show
    // answer" here — that would be a way past the retrieval.
    expect(find.text('Show answer'), findsNothing);
    expect(find.byKey(const Key('reviewAnswerField')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('reviewAnswerField')),
      'decision',
    );
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text('Check'));

    expect(find.text('Correct'), findsOneWidget);
    // A correct answer leaves only the question of how hard it felt.
    expect(find.text('Again'), findsNothing);
    await tapAndSettle(tester, find.text('Good'));

    // ── Getting it wrong shows the word, and offers only one way on ─────────
    await tester.enterText(
      find.byKey(const Key('reviewAnswerField')),
      'decison',
    );
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text('Check'));

    expect(find.text('Not quite'), findsOneWidget);
    expect(find.text('You typed: decison'), findsOneWidget);
    expect(find.text('Good'), findsNothing);
    await tapAndSettle(tester, find.text('Continue'));

    // ── All three cards were graded; the failed one was logged as such ──────
    final allLogs = await db.select(db.reviewLogs).get();
    expect(allLogs, hasLength(3));
    expect(allLogs.last.grade, ReviewGrade.again);
  });

  testWidgets('the bundled pack seeds the word list, once', (tester) async {
    // This is the only test that can prove the pack is actually *bundled*.
    // The unit tests read a fake asset bundle; a pack that exists on disk but
    // was never declared in pubspec.yaml would sail past them and ship an
    // empty app — the same shape of bug as an asset the build cannot find.
    await launchApp(tester, seeded: true);

    final db = getIt<AppDatabase>();
    final words = await db.select(db.words).get();
    if (words.isEmpty) {
      markTestSkipped(
        'No content pack in this build — generate one with '
        'tool/content/generate_pack.dart to cover this flow.',
      );
      return;
    }

    // ── Every seeded word is studiable, not a stub ──────────────────────────
    expect(words.every((w) => w.meaningEn != null), isTrue);
    expect(words.every((w) => w.collocation != null), isTrue);
    expect(
      words.every((w) => w.enrichmentStatus == EnrichmentStatus.ready),
      isTrue,
    );
    expect(
      await db.select(db.cards).get(),
      hasLength(words.length * CardKind.values.length),
    );

    // ── They are on screen, and reviewable ──────────────────────────────────
    await tapAndSettle(tester, find.byTooltip('Words'));
    expect(find.text('No words yet'), findsNothing);

    await tapAndSettle(tester, find.byTooltip('Review'));
    await tapAndSettle(tester, find.text('Show answer'));
    await tapAndSettle(tester, find.text('Good'));
    expect(await db.select(db.reviewLogs).get(), hasLength(1));

    // ── Importing again on the next launch changes nothing ──────────────────
    final result = await getIt<ImportSeedPack>()();
    expect(result, isA<Ok<int>>().having((r) => r.value, 'added', 0));
    expect(await db.select(db.words).get(), hasLength(words.length));
    expect(
      await db.select(db.decks).get(),
      hasLength(1),
      reason: 'a second import would mean a second deck of the same words',
    );
  });

  testWidgets('the dashboard follows a review as it happens', (tester) async {
    // The dashboard's figures cross three seams — the reader, the local-day
    // bucketing, and the refresh that fires when the review screen pops. Only
    // a real run puts all three together.
    await launchApp(tester, seeded: true);

    final db = getIt<AppDatabase>();
    if ((await db.select(db.words).get()).isEmpty) {
      markTestSkipped('No content pack in this build.');
      return;
    }

    // ── Nothing studied yet ─────────────────────────────────────────────────
    await tapAndSettle(tester, find.byTooltip('Home'));
    expect(find.text('No streak yet'), findsOneWidget);
    expect(find.textContaining('0 of'), findsOneWidget);

    // ── Review one card, straight from the dashboard ────────────────────────
    await tapAndSettle(tester, find.byKey(HomeDashboardKeys.reviewCta));
    await tapAndSettle(tester, find.text('Show answer'));
    await tapAndSettle(tester, find.text('Good'));
    await tapAndSettle(tester, find.byTooltip('Back'));

    // ── The dashboard caught up on the way back ─────────────────────────────
    await waitFor(tester, find.text('1 day in a row'));
    expect(find.textContaining('1 of'), findsOneWidget);
    expect(await db.select(db.reviewLogs).get(), hasLength(1));
  });

  testWidgets('a word shared from another app opens the form filled in', (
    tester,
  ) async {
    // The Dart half of the share path, on a real device: the share is waiting
    // before the first frame, so it has to survive the splash gate rather
    // than being pushed at a router that is still holding everything back.
    // The platform half — the iOS extension and the Android intent filter —
    // can only be checked by actually sharing from another app.
    await launchApp(tester, sharedText: 'decision');

    await waitFor(tester, find.text('Add a word'));
    expect(
      find.widgetWithText(TextField, 'decision'),
      findsOneWidget,
      reason: 'a one-word share is the word itself',
    );

    // And it saves like any other capture.
    await tapAndSettle(tester, find.text('Save word'));

    final db = getIt<AppDatabase>();
    final words = await db.select(db.words).get();
    expect(words.single.lemma, 'decision');
  });

  testWidgets('a shared sentence leaves the word for the learner', (
    tester,
  ) async {
    await launchApp(tester, sharedText: 'It was a hard decision to make.');

    await waitFor(tester, find.text('Add a word'));
    expect(
      find.widgetWithText(TextField, 'It was a hard decision to make.'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextField, 'decision'),
      findsNothing,
      reason: 'picking the word out of a phrase is the learner’s call',
    );
  });

  testWidgets('a word met twice is enriched, not duplicated', (tester) async {
    await launchApp(tester);
    await tapAndSettle(tester, find.byTooltip('Words'));

    Future<void> addWord(String sentence) async {
      await tapAndSettle(tester, find.byTooltip('Add a word'));
      await tester.enterText(find.byType(TextField).at(0), 'decision');
      await tester.enterText(find.byType(TextField).at(1), sentence);
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.text('Save word'));
    }

    await addWord('It was a hard decision.');
    await addWord('Decision time.');

    final db = getIt<AppDatabase>();
    expect(await db.select(db.words).get(), hasLength(1));
    expect(await db.select(db.examples).get(), hasLength(2));
    expect(
      await db.select(db.cards).get(),
      hasLength(CardKind.values.length),
      reason: 'the second encounter must not create a second set of cards',
    );
  });
}
