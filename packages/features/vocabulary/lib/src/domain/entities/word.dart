import 'package:database/database.dart' show EnrichmentStatus, ExampleOrigin;
import 'package:meta/meta.dart';

/// A sentence the word was met in, or one written to show it in use.
@immutable
class WordExample {
  const WordExample({
    required this.id,
    required this.sentence,
    required this.origin,
    this.translation,
  });

  final int id;
  final String sentence;
  final String? translation;
  final ExampleOrigin origin;

  /// Whether the learner met this sentence themselves.
  ///
  /// Drills prefer these: a sentence from your own reading is a far stronger
  /// retrieval cue than a generated one.
  bool get isFromLife => origin == ExampleOrigin.userCapture;
}

/// A word the learner is collecting.
///
/// [display] is how they met it; [lemma] is the lowercased key the database
/// deduplicates on. A word captured before the device was online carries
/// [EnrichmentStatus.pending] and has no meaning yet — the UI shows it as
/// still arriving rather than as broken.
@immutable
class Word {
  const Word({
    required this.id,
    required this.lemma,
    required this.display,
    required this.enrichmentStatus,
    required this.createdAt,
    this.phonetic,
    this.partOfSpeech,
    this.meaningEn,
    this.meaningVi,
    this.collocation,
    this.examples = const [],
  });

  final int id;
  final String lemma;
  final String display;
  final String? phonetic;
  final String? partOfSpeech;
  final String? meaningEn;
  final String? meaningVi;

  /// The word's most useful partner ("make a decision") — most of knowing how
  /// to use a word is knowing what it goes with.
  final String? collocation;

  final EnrichmentStatus enrichmentStatus;
  final List<WordExample> examples;
  final DateTime createdAt;

  /// Whether there is enough here to study.
  ///
  /// A word with no meaning can still be reviewed for recognition, but a drill
  /// that asks the learner to produce it has nothing to show as a prompt.
  bool get isStudiable => meaningEn != null || meaningVi != null;

  /// The example a drill should prefer: one from the learner's own life if
  /// there is one, otherwise whatever exists.
  WordExample? get bestExample {
    if (examples.isEmpty) return null;
    return examples.firstWhere(
      (e) => e.isFromLife,
      orElse: () => examples.first,
    );
  }
}
