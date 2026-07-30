// The list has to hear about a word changing underneath it. The dictionary
// lookup runs after the save, on its own time, so a tile built while the word
// was still pending would otherwise keep saying its details arrive when you are
// online — after they had already arrived, or after the lookup gave up.
//
// Pumped through `WordsListScreen` rather than the view, because the
// subscription is what is under test and it lives in the screen.

import 'package:architecture/architecture.dart';
import 'package:database/database.dart' show EnrichmentStatus;
import 'package:feature_vocabulary/feature_vocabulary.dart';
import 'package:feature_vocabulary/src/domain/usecases/delete_word.dart';
import 'package:feature_vocabulary/src/domain/usecases/list_words.dart';
import 'package:feature_vocabulary/src/locator.dart';
import 'package:feature_vocabulary/src/presentation/widgets/word_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localization/localization.dart';
import 'package:shared_contracts/shared_contracts.dart';

import '../../support.dart';

class _MockListWords extends Mock implements ListWords {}

class _MockDeleteWord extends Mock implements DeleteWord {}

Word _word(int id, String display, {String? meaningVi}) => Word(
  id: id,
  lemma: display,
  display: display,
  meaningVi: meaningVi,
  enrichmentStatus: meaningVi == null
      ? EnrichmentStatus.pending
      : EnrichmentStatus.ready,
  createdAt: DateTime.utc(2026, 6, 1),
);

void main() {
  late _MockListWords listWords;
  late _MockDeleteWord deleteWord;
  late ActivityNotifier activity;

  setUp(() {
    listWords = _MockListWords();
    deleteWord = _MockDeleteWord();
    activity = ActivityNotifier();

    getIt
      ..registerFactory<WordsListBloc>(
        () => WordsListBloc(listWords, deleteWord),
      )
      ..registerSingleton<ActivityNotifier>(activity);
  });

  tearDown(() async {
    activity.dispose();
    await getIt.reset();
  });

  testWidgets('a meaning that arrives after the save shows up', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // First load: captured, no meaning yet.
    when(
      listWords.call,
    ).thenAnswer((_) async => Ok([_word(1, 'procrastinate')]));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: WordsListScreen(
          onAdd: () async {},
          onOpen: (_) {},
          onReview: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(WordTile), findsOneWidget);
    expect(find.text('Details arrive when you are online'), findsOneWidget);

    // The lookup lands and announces it.
    when(listWords.call).thenAnswer(
      (_) async => Ok([_word(1, 'procrastinate', meaningVi: 'Trì hoãn.')]),
    );
    activity.notifyActivityOccurred();
    await tester.pump();
    await tester.pump();

    expect(find.text('Trì hoãn.'), findsOneWidget);
    expect(
      find.text('Details arrive when you are online'),
      findsNothing,
      reason: 'the promise has been kept, and must stop being made',
    );
  });
}
