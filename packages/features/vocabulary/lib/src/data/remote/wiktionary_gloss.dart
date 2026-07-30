/// What a Vietnamese Wiktionary entry has to say about an English word.
class WordGloss {
  const WordGloss({required this.meaningVi, this.phonetic, this.partOfSpeech});

  /// The first Vietnamese sense listed — the shortest true answer to "what
  /// does this word mean", which is what a card back needs.
  final String meaningVi;

  final String? phonetic;
  final String? partOfSpeech;
}

/// Pulls the Vietnamese gloss for an English word out of a `prop=extracts`
/// plaintext dump, or returns null if the entry has none.
///
/// The dump is wiki prose, not data, so this is a parser against a shape
/// rather than a schema. Everything it relies on was read off real responses
/// (kept as fixtures next to the test):
///
/// ```text
/// == Tiếng Anh ==
///
/// === Cách phát âm ===
/// IPA: /ˈɛr.ənd/
///
/// === Danh từ ===
/// errand  /ˈɛr.ənd/
///
/// Việc vặt (đưa thư, mua thuốc lá... ).
/// to run errands —  chạy việc vặt
/// ```
///
/// Returns null rather than guessing when the page exists but has no English
/// section — plenty of pages are Vietnamese words only.
WordGloss? parseVietnameseGloss(String extract) {
  final english = _englishSection(extract);
  if (english == null) return null;

  String? phonetic;
  String? partOfSpeech;
  String? meaning;

  for (final section in _subsections(english)) {
    if (section.title == _pronunciationHeading) {
      phonetic ??= _ipa(section.body);
      continue;
    }
    if (section.title == _referencesHeading) continue;

    // Any other subsection is a part of speech: "Danh từ", "Nội động từ", …
    final gloss = _firstGloss(section.body);
    if (gloss != null && meaning == null) {
      meaning = gloss;
      partOfSpeech = section.title;
    }
  }

  if (meaning == null) return null;
  return WordGloss(
    meaningVi: meaning,
    phonetic: phonetic,
    partOfSpeech: partOfSpeech,
  );
}

const _englishHeading = 'Tiếng Anh';
const _pronunciationHeading = 'Cách phát âm';
const _referencesHeading = 'Tham khảo';

/// The `== Tiếng Anh ==` section, up to the next language.
///
/// Selected by name, not by position: an entry like `run` carries a Vietnamese
/// section too ("run" is a Vietnamese word), and taking the first section
/// would gloss the wrong language entirely.
String? _englishSection(String extract) {
  // `(?!=)` keeps this off the `=== … ===` subsections: without it the pattern
  // happily matches a subsection heading, captures `= Cách phát âm =` as a
  // language, and slices the English section down to nothing.
  final headings = RegExp(r'^==(?!=)\s*(.+?)\s*==$', multiLine: true);
  final matches = headings.allMatches(extract).toList();
  for (var i = 0; i < matches.length; i++) {
    if (matches[i].group(1) != _englishHeading) continue;
    final start = matches[i].end;
    final end = i + 1 < matches.length ? matches[i + 1].start : extract.length;
    return extract.substring(start, end);
  }
  return null;
}

class _Subsection {
  const _Subsection(this.title, this.body);

  final String title;
  final String body;
}

/// The `=== … ===` subsections, in order.
///
/// Exactly three equals signs: deeper headings are nested content (an idiom
/// list under a noun, say), not senses of the word.
Iterable<_Subsection> _subsections(String section) {
  final headings = RegExp(r'^===(?!=)\s*(.+?)\s*===$', multiLine: true);
  final matches = headings.allMatches(section).toList();
  return [
    for (var i = 0; i < matches.length; i++)
      _Subsection(
        matches[i].group(1)!,
        section.substring(
          matches[i].end,
          i + 1 < matches.length ? matches[i + 1].start : section.length,
        ),
      ),
  ];
}

String? _ipa(String body) {
  final match = RegExp(r'IPA:\s*(\S+)').firstMatch(body);
  return match?.group(1);
}

/// The first Vietnamese sense in a part-of-speech section.
///
/// Two lines are skipped on the way. The first non-empty line repeats the
/// headword (`errand  /ˈɛr.ənd/`, or `run (số nhiều runs)`) — skipped by
/// position, since its shape varies. Then example lines, which pair an English
/// phrase with its translation across an em dash; a sense never does.
String? _firstGloss(String body) {
  final lines = body
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
  if (lines.length < 2) return null;

  for (final line in lines.skip(1)) {
    if (line.contains(' — ')) continue;
    if (line.startsWith('IPA:')) continue;
    return line;
  }
  return null;
}
