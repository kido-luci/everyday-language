import 'package:meta/meta.dart';

/// What a blob of text shared from another app means for the add-word form.
///
/// The share sheet hands over whatever the learner had selected, and that is
/// one of two quite different things: a single word they want to keep, or the
/// run of text they met it in. Guessing which is the whole job here.
///
/// A single token becomes the **word**. Anything longer becomes the
/// **sentence** and leaves the word blank — picking one word out of a phrase
/// is a judgement only the learner can make, and filling it in wrongly would
/// be worse than leaving it empty, because the form's own rule is that the
/// sentence must contain the word.
@immutable
class SharedCapture {
  const SharedCapture({this.word, this.sentence});

  /// Reads [raw] as it arrived from the share sheet.
  factory SharedCapture.parse(String raw) {
    // Browsers commonly append the page URL to shared selections. It is never
    // the word and never part of the sentence.
    final text = raw.replaceAll(_link, ' ').replaceAll(_whitespace, ' ').trim();
    if (text.isEmpty) return const SharedCapture();

    if (!text.contains(' ')) {
      final word = _trimPunctuation(text);
      return word.isEmpty ? const SharedCapture() : SharedCapture(word: word);
    }
    return SharedCapture(sentence: _firstSentence(text));
  }

  /// The word to study, when the share was one.
  final String? word;

  /// The text it was met in, when the share was longer than a word.
  final String? sentence;

  bool get isEmpty => word == null && sentence == null;

  /// Longest sentence worth keeping. Beyond this the learner shared a
  /// paragraph, and a card cannot use one.
  static const int _maxSentence = 200;

  /// Shortest run that counts as a sentence when cutting a long share, so an
  /// abbreviation's full stop does not end it after three words.
  static const int _minSentence = 40;

  static final RegExp _link = RegExp(r'(https?://|www\.)\S+');
  static final RegExp _whitespace = RegExp(r'\s+');

  /// Strips surrounding punctuation and quotes, keeping what is inside a word.
  ///
  /// A shared word usually arrives with the comma or closing quote that
  /// followed it. Hyphens and apostrophes in the middle stay, because
  /// "co-worker" and "don't" are the words.
  static final RegExp _edgePunctuation = RegExp(
    r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$',
    unicode: true,
  );

  static String _trimPunctuation(String value) =>
      value.replaceAll(_edgePunctuation, '');

  /// The first sentence of [text], or a whole-word cut when there isn't one.
  static String _firstSentence(String text) {
    if (text.length <= _maxSentence) return text;

    final end = text.indexOf(RegExp(r'[.!?]\s'), _minSentence);
    if (end != -1 && end < _maxSentence) return text.substring(0, end + 1);

    final lastSpace = text.lastIndexOf(' ', _maxSentence);
    return text.substring(0, lastSpace == -1 ? _maxSentence : lastSpace);
  }
}
