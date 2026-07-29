import 'package:database/database.dart';
import 'package:everyday_language/app/app.dart';
import 'package:everyday_language/app/di/injection.dart';
import 'package:feature_vocabulary/feature_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

/// Boots the real app for an end-to-end run.
///
/// Everything below the widget tree is genuine: the real DI graph, the real
/// Drift database on the device's filesystem, the real scheduler. Only the
/// starting data is controlled — the database is emptied first, because a
/// device carries the previous run's words and a test that passes only on a
/// fresh install is worse than no test.
///
/// Set [seeded] to run the bundled content pack in first, the way `main` does
/// on a real launch. It is off by default so the flows about capturing a word
/// start from a genuinely empty list.
Future<void> launchApp(WidgetTester tester, {bool seeded = false}) async {
  if (!getIt.isRegistered<AppDatabase>()) {
    await configureDependencies();
  }
  await clearDatabase();
  if (seeded) await getIt<ImportSeedPack>()();

  await tester.pumpWidget(const App());
  await tester.pumpAndSettle();

  // The app opens on splash and leaves only once its minimum display time has
  // elapsed. That is a real timer, not an animation, so pumpAndSettle returns
  // while it is still running — the shell has to be waited for explicitly.
  //
  // Found by tooltip, not text: on a phone the bottom bar renders labels as
  // semantics and tooltips only, so find.text never matches a tab.
  await waitFor(tester, find.byTooltip('Words'));
}

/// Pumps until [finder] matches, or fails after [timeout].
///
/// `pumpAndSettle` only waits for frames to stop being scheduled; anything
/// gated on a real timer or a database read needs this instead.
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = tester.binding.clock.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (tester.binding.clock.now().isAfter(deadline)) {
      fail('Timed out after $timeout waiting for: $finder');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

/// Removes every row the app owns.
///
/// Deleting words is enough for cards, examples and review logs — they cascade
/// — but decks and capture sources are roots of their own.
Future<void> clearDatabase() async {
  final db = getIt<AppDatabase>();
  await db.delete(db.words).go();
  await db.delete(db.decks).go();
  await db.delete(db.captureSources).go();
}

/// Taps [finder] and lets the frame settle.
Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
