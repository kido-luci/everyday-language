// What the repository announces, and when. The word list rebuilds on the
// activity notifier, so anything that changes what a tile says has to fire it —
// including the lookup giving up, which is how a stale "details arrive when you
// are online" stayed on screen for a word that would never get any.

import 'package:architecture/architecture.dart';
import 'package:feature_vocabulary/src/data/local/vocabulary_local_data_source.dart';
import 'package:feature_vocabulary/src/data/repositories/vocabulary_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

class _MockLocal extends Mock implements VocabularyLocalDataSource {}

void main() {
  late _MockLocal local;
  late MockActivityNotifier activity;
  late VocabularyRepositoryImpl repository;

  setUp(() {
    local = _MockLocal();
    activity = MockActivityNotifier();
    repository = VocabularyRepositoryImpl(local, activity);

    when(
      () => local.applyGloss(
        any(),
        meaningVi: any(named: 'meaningVi'),
        phonetic: any(named: 'phonetic'),
        partOfSpeech: any(named: 'partOfSpeech'),
        now: any(named: 'now'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => local.markEnrichmentFailed(any(), now: any(named: 'now')),
    ).thenAnswer((_) async {});
    when(activity.notifyActivityOccurred).thenReturn(null);
  });

  test('a found meaning is announced, so the tile stops saying "soon"', () async {
    final result = await repository.saveMeaning(1, meaningVi: 'Trì hoãn.');

    expect(result, isA<Ok<void>>());
    verify(activity.notifyActivityOccurred).called(1);
  });

  test('giving up is announced too', () async {
    // Otherwise the tile keeps promising a meaning that is never coming.
    final result = await repository.giveUpOnMeaning(1);

    expect(result, isA<Ok<void>>());
    verify(activity.notifyActivityOccurred).called(1);
  });
}
