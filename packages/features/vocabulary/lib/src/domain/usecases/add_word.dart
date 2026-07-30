import 'package:architecture/architecture.dart';
import 'package:injectable/injectable.dart';

import '../entities/word.dart';
import '../repositories/vocabulary_repository.dart';

/// What the learner typed, before it becomes a word.
///
/// The word and the sentence they met it in, and nothing else. A meaning is
/// not theirs to write: capture has to stay quick enough to do mid-sentence,
/// and a field asking what the word means turns a two-second capture into
/// homework — so words arrive unglossed and something else fills them in.
class AddWordParams {
  const AddWordParams({required this.display, this.sentence});

  final String display;

  /// The sentence they met it in, if they had one to hand.
  final String? sentence;
}

@injectable
class AddWord extends UseCase<AddWordParams, Word> {
  const AddWord(this._repository);

  final VocabularyRepository _repository;

  /// A word is one token: no spaces, and something other than punctuation.
  ///
  /// Deliberately permissive about what a "word" is — hyphens, apostrophes and
  /// non-Latin scripts all belong. What it rejects is an empty box and a
  /// pasted phrase, because a multi-word card is a different feature.
  static final _wordPattern = RegExp(r'^[^\s]+$');

  @override
  Future<Result<Word>> call(AddWordParams param) {
    final display = param.display.trim();
    if (display.isEmpty) {
      return Future.value(const Err(ValidationFailure('Enter a word')));
    }
    if (!_wordPattern.hasMatch(display)) {
      return Future.value(
        const Err(ValidationFailure('Enter a single word, without spaces')),
      );
    }

    final sentence = param.sentence?.trim();
    if (sentence != null &&
        sentence.isNotEmpty &&
        !sentence.toLowerCase().contains(display.toLowerCase())) {
      // The sentence is the point: it is the retrieval cue the cloze drill
      // blanks out. One that does not contain the word cannot serve as one.
      return Future.value(
        const Err(ValidationFailure('The sentence must contain the word')),
      );
    }

    return runResultGuarded(
      () => _repository.addWord(
        display: display,
        sentence: (sentence?.isEmpty ?? true) ? null : sentence,
      ),
    );
  }
}
