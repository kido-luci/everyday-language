import 'package:meta/meta.dart';

/// A pack of words that ships with the app, parsed from its JSON asset.
///
/// The packs live outside this repository (see `content/README.md`), so this
/// file is the contract between the generator that writes them and the app
/// that reads them. It is deliberately strict: a malformed pack should fail
/// loudly at import, where the message can name the entry, rather than
/// producing a word with a blank meaning that only shows up in a drill weeks
/// later.
@immutable
class SeedPack {
  const SeedPack({
    required this.id,
    required this.name,
    required this.entries,
    this.generatedAt,
  });

  /// Parses a decoded JSON map.
  ///
  /// Throws [SeedPackFormatException] on anything it cannot read.
  factory SeedPack.fromJson(Map<String, dynamic> json) {
    final version = json['schemaVersion'];
    if (version != schemaVersion) {
      throw SeedPackFormatException(
        'Unsupported schemaVersion $version; this build reads $schemaVersion',
      );
    }

    final rawEntries = json['entries'];
    if (rawEntries is! List || rawEntries.isEmpty) {
      throw const SeedPackFormatException('Pack has no entries');
    }

    final entries = [
      for (final (index, raw) in rawEntries.indexed)
        if (raw is Map<String, dynamic>)
          SeedEntry.fromJson(raw, index: index)
        else
          throw SeedPackFormatException('Entry $index is not an object'),
    ];

    // Two entries for one word is a pack that cannot be imported: the second
    // would merge into the first and then collide on deck membership, failing
    // the whole transaction on every launch. Caught here, where the message
    // can say which word, rather than as a startup crash loop.
    final seen = <String>{};
    for (final entry in entries) {
      if (!seen.add(entry.lemma)) {
        throw SeedPackFormatException('Duplicate entry for "${entry.lemma}"');
      }
    }

    return SeedPack(
      id: _requireText(json, 'id'),
      name: _requireText(json, 'name'),
      generatedAt: DateTime.tryParse(json['generatedAt'] as String? ?? ''),
      entries: entries,
    );
  }

  /// The version this code can read.
  ///
  /// A pack declaring anything else is rejected rather than best-guessed: an
  /// older build meeting a newer pack has no way to know which fields moved.
  static const int schemaVersion = 1;

  /// Stable identifier, e.g. `everyday-v1`. The import keys off this, so
  /// changing it re-imports the pack as a new deck.
  final String id;

  /// What the pack calls itself.
  final String name;

  final DateTime? generatedAt;
  final List<SeedEntry> entries;

  static String _requireText(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw SeedPackFormatException('Pack is missing "$key"');
    }
    return value.trim();
  }
}

/// One word in a pack, with everything needed to study it.
///
/// [meaningEn] and [sentence] are required because a word without them cannot
/// fill two of the three cards: recall has no prompt to show, and cloze has no
/// sentence to blank out. [collocation] is required for the reason the column
/// exists — knowing what a word goes *with* is most of knowing how to use it,
/// and a pack that skipped it would quietly ship worse words than a learner's
/// own captures.
@immutable
class SeedEntry {
  const SeedEntry({
    required this.display,
    required this.meaningEn,
    required this.collocation,
    required this.sentence,
    this.phonetic,
    this.partOfSpeech,
    this.meaningVi,
  });

  factory SeedEntry.fromJson(Map<String, dynamic> json, {required int index}) {
    String required(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw SeedPackFormatException('Entry $index is missing "$key"');
      }
      return value.trim();
    }

    String? optional(String key) {
      final value = json[key];
      if (value is! String) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    final display = required('display');
    if (display.contains(RegExp(r'\s'))) {
      // Same rule the add-word form enforces: a multi-word card is a
      // different feature, and a pack must not smuggle one in.
      throw SeedPackFormatException('Entry $index "$display" is not one word');
    }

    final sentence = required('sentence');
    if (!sentence.toLowerCase().contains(display.toLowerCase())) {
      // The sentence is what the cloze card blanks out. One that does not
      // contain the word cannot serve as one.
      throw SeedPackFormatException(
        'Entry $index sentence does not contain "$display"',
      );
    }

    return SeedEntry(
      display: display,
      phonetic: optional('phonetic'),
      partOfSpeech: optional('partOfSpeech'),
      meaningEn: required('meaningEn'),
      meaningVi: optional('meaningVi'),
      collocation: required('collocation'),
      sentence: sentence,
    );
  }

  final String display;
  final String? phonetic;
  final String? partOfSpeech;
  final String meaningEn;
  final String? meaningVi;
  final String collocation;
  final String sentence;

  /// The deduplication key, derived rather than carried in the pack so it
  /// cannot drift from the one the database enforces.
  String get lemma => display.toLowerCase();
}

/// A pack that could not be read. Carries what was wrong and where.
class SeedPackFormatException implements Exception {
  const SeedPackFormatException(this.message);

  final String message;

  @override
  String toString() => 'SeedPackFormatException: $message';
}
