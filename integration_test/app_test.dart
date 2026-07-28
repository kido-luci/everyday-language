// The one flow that has to work: meet a word, save it, and review it.
//
// Everything below the widget tree is real — the DI graph, the Drift database
// on the device, the FSRS scheduler. What this catches that the unit tests
// cannot is the wiring between them: a route that does not resolve, a view
// model the locator cannot build, a transaction that deadlocks on a real
// connection rather than an in-memory one.

import 'package:database/database.dart';
import 'package:everyday_language/app/di/injection.dart';
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
    await tester.enterText(find.byType(TextField).at(2), 'quyết định');
    await tester.pumpAndSettle();

    await tapAndSettle(tester, find.text('Save word'));

    // ── It is in the list, showing the meaning ──────────────────────────────
    expect(find.text('decision'), findsOneWidget);
    expect(find.text('quyết định'), findsOneWidget);

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
