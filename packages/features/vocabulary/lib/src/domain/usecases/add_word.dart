import 'package:architecture/architecture.dart';
import 'package:injectable/injectable.dart';

import '../entities/word.dart';
import '../repositories/vocabulary_repository.dart';

/// What the learner typed, before it becomes a word.
class AddWordParams {
  const AddWordParams({required this.display, this.sentence, this.meaningVi});

  final String display;

  /// The sentence they met it in, if they had one to hand.
  final String? sentence;

  final String? meaningVi;
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
        meaningVi: _blankToNull(param.meaningVi),
      ),
    );
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
