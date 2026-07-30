// Widget tests for the search field on the word list. The filtering itself is
// covered in words_list_bloc_test; what matters here is the wiring — that
// typing narrows the list, and that the field survives a query matching
// nothing (otherwise the query cannot be cleared without retyping over it).

import 'package:architecture/architecture.dart';
import 'package:database/database.dart' show EnrichmentStatus;
import 'package:feature_vocabulary/feature_vocabulary.dart';
import 'package:feature_vocabulary/src/domain/usecases/delete_word.dart';
import 'package:feature_vocabulary/src/domain/usecases/list_words.dart';
import 'package:feature_vocabulary/src/presentation/widgets/word_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localization/localization.dart';
import 'package:mocktail/mocktail.dart';

class _MockListWords extends Mock implements ListWords {}

class _MockDeleteWord extends Mock implements DeleteWord {}

Word _word(int id, String display) => Word(
  id: id,
  lemma: display.toLowerCase(),
  display: display,
  enrichmentStatus: EnrichmentStatus.ready,
  createdAt: DateTime.utc(2026, 6, 1),
);

void main() {
  late _MockListWords listWords;
  late _MockDeleteWord deleteWord;

  setUp(() {
    listWords = _MockListWords();
    deleteWord = _MockDeleteWord();
    when(listWords.call).thenAnswer(
      (_) async => Ok([_word(1, 'decision'), _word(2, 'errand')]),
    );
  });

  Future<void> pumpList(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final bloc = WordsListBloc(listWords, deleteWord)
      ..add(const WordsRequested());
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<WordsListBloc>.value(
          value: bloc,
          child: WordsListView(
            onAdd: () async {},
            onOpen: (_) {},
            onReview: () {},
          ),
        ),
      ),
    );
    // Two pumps: one for the load to resolve, one to render its result.
    await tester.pump();
    await tester.pump();
  }

  testWidgets('typing narrows the list to what matches', (tester) async {
    await pumpList(tester);
    expect(find.byType(WordTile), findsNWidgets(2));

    await tester.enterText(find.byType(TextFormField), 'deci');
    await tester.pump();

    expect(find.byType(WordTile), findsOneWidget);
    expect(find.text('decision'), findsOneWidget);
  });

  testWidgets('a query matching nothing keeps the field on screen', (
    tester,
  ) async {
    await pumpList(tester);

    await tester.enterText(find.byType(TextFormField), 'zzz');
    await tester.pump();

    expect(find.byType(WordTile), findsNothing);
    expect(find.text('No matches'), findsOneWidget);
    // The way back out of a dead end.
    expect(find.byType(TextFormField), findsOneWidget);

    // The empty view animates in on a delay; without draining those timers the
    // test tears the tree down under them and fails on "a Timer is still
    // pending".
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('clearing the field brings the whole list back', (tester) async {
    await pumpList(tester);
    await tester.enterText(find.byType(TextFormField), 'deci');
    await tester.pump();

    await tester.enterText(find.byType(TextFormField), '');
    await tester.pump();

    expect(find.byType(WordTile), findsNWidgets(2));
  });
}
