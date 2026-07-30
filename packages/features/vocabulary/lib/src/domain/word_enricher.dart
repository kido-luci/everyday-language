import 'dart:developer' as developer;

import 'package:architecture/architecture.dart';
import 'package:injectable/injectable.dart';

import '../data/remote/wiktionary_client.dart';
import 'repositories/vocabulary_repository.dart';

/// Fills in the meanings of words captured without one.
///
/// Capture has to be instant and has to work on the underground, so a word
/// arrives with nothing but itself and the sentence it came from. This is what
/// comes along afterwards and looks each one up.
///
/// A singleton rather than something a screen owns: the sweep outlives the
/// screen that triggered it, and a cubit closed on the way back would have to
/// either abandon the work or emit into a dead bloc.
@lazySingleton
class WordEnricher {
  WordEnricher(this._repository, this._dictionary);

  final VocabularyRepository _repository;
  final WiktionaryClient _dictionary;

  /// How many words one sweep will look up.
  ///
  /// Bounded because it is someone else's free service: a learner who imports
  /// a backlog should not fire two hundred requests at Wikimedia in a burst.
  /// Whatever is left stays pending and is picked up by the next sweep.
  static const int batchSize = 10;

  bool _running = false;

  /// Looks up as many pending words as [batchSize] allows.
  ///
  /// Re-entrant calls are dropped rather than queued: the trigger is "a word
  /// was captured", which can arrive several times in a row, and two sweeps at
  /// once would ask the same questions twice.
  Future<void> sweep() async {
    if (_running) return;
    _running = true;
    try {
      await _sweepOnce();
    } finally {
      _running = false;
    }
  }

  Future<void> _sweepOnce() async {
    final pending = await _repository.wordsAwaitingMeaning(limit: batchSize);
    if (pending case Err(:final failure)) {
      _log('could not read the pending words: ${failure.message}');
      return;
    }
    if (pending case Ok(:final value)) {
      for (final word in value) {
        // Sequential on purpose. Ten parallel requests would be rude to a free
        // API and would gain a learner nothing they can perceive.
        switch (await _dictionary.lookUp(word.display)) {
          case LookupFound(:final gloss):
            await _repository.saveMeaning(
              word.id,
              meaningVi: gloss.meaningVi,
              phonetic: gloss.phonetic,
              partOfSpeech: gloss.partOfSpeech,
            );
          case LookupAbsent():
            // A settled answer: the dictionary does not have this word, and
            // asking again tomorrow will not change that.
            await _repository.giveUpOnMeaning(word.id);
          case LookupFailed():
            // Offline, or the service was unhappy. Leave it pending — this is
            // the case that must not be mistaken for "no such word", or one
            // flight without signal would permanently blank a word.
            _log('lookup failed for ${word.display}; leaving it pending');
            return;
        }
      }
    }
  }

  void _log(String message) =>
      developer.log(message, name: 'vocabulary.enrich');
}
