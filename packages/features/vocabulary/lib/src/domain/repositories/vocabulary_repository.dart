import 'package:architecture/architecture.dart';

import '../entities/word.dart';

/// The vocabulary the learner has collected.
abstract interface class VocabularyRepository {
  /// Every word, newest first.
  Future<Result<List<Word>>> listWords();

  /// A single word with its examples, or [NotFoundFailure].
  Future<Result<Word>> getWord(int id);

  /// Adds a word and the cards built from it.
  ///
  /// Returns the stored word — which may be an existing one, since re-adding a
  /// word the learner already has enriches it with another example rather than
  /// creating a duplicate.
  Future<Result<Word>> addWord({
    required String display,
    String? sentence,
    String? meaningVi,
  });

  /// Removes a word, its examples and its cards.
  Future<Result<void>> deleteWord(int id);

  /// Words still waiting for a meaning, oldest first.
  Future<Result<List<Word>>> wordsAwaitingMeaning({required int limit});

  /// Stores a looked-up meaning against [wordId] and marks it done.
  Future<Result<void>> saveMeaning(
    int wordId, {
    required String meaningVi,
    String? phonetic,
    String? partOfSpeech,
  });

  /// Records that the dictionary has nothing for [wordId], so it stops being
  /// asked about.
  Future<Result<void>> giveUpOnMeaning(int wordId);
}
