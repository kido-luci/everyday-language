import 'package:database/database.dart' show CardKind;
import 'package:meta/meta.dart';
import 'package:srs/srs.dart';

/// A card as the review session sees it: what to ask, and what to reveal.
@immutable
class ReviewCard {
  const ReviewCard({
    required this.id,
    required this.kind,
    required this.schedule,
    required this.display,
    this.phonetic,
    this.meaning,
    this.collocation,
    this.sentence,
  });

  final int id;
  final CardKind kind;
  final CardSchedule schedule;

  /// The word itself, as the learner met it.
  final String display;

  final String? phonetic;

  /// The best meaning available — the learner's own language if it is there.
  final String? meaning;

  final String? collocation;

  /// The sentence the word was met in, if there is one.
  final String? sentence;

  /// What the learner is shown before revealing.
  ///
  /// The prompt is what makes a card kind different; the answer is the same
  /// word every time. A card whose kind has nothing to prompt with falls back
  /// to recognition rather than showing a blank screen.
  String prompt() => switch (kind) {
    CardKind.recognise => display,
    CardKind.recall => meaning ?? display,
    CardKind.cloze => _blanked() ?? display,
  };

  /// Whether the prompt asks the learner to produce the word rather than
  /// recognise it.
  ///
  /// A production card that fell back to showing the word (no meaning, no
  /// usable sentence) is not one — it would be asking the learner to copy what
  /// is already on screen.
  bool get asksForProduction =>
      kind != CardKind.recognise && prompt() != display;

  /// Whether [typed] is the word this card is asking for.
  ///
  /// Compared after trimming, lowercasing and collapsing internal whitespace,
  /// so a stray space or a capital does not count as forgetting the word. A
  /// misspelling does: the point of typing it is that recall has to be exact,
  /// and accepting near-misses would feed the scheduler a success the learner
  /// did not have.
  bool accepts(String typed) => _normalise(typed) == _normalise(display);

  static String _normalise(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// The sentence with the word replaced by a blank, or null if there is no
  /// usable sentence.
  String? _blanked() {
    final source = sentence;
    if (source == null) return null;
    final pattern = RegExp(RegExp.escape(display), caseSensitive: false);
    if (!pattern.hasMatch(source)) return null;
    return source.replaceAll(pattern, '____');
  }
}
