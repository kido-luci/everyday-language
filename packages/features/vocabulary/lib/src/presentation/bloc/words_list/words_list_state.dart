import 'package:meta/meta.dart';

import '../../../domain/entities/word.dart';

enum WordsListStatus { initial, loading, ready, failure }

@immutable
class WordsListState {
  const WordsListState({
    this.status = WordsListStatus.initial,
    this.words = const [],
    this.query = '',
    this.failureMessage,
  });

  final WordsListStatus status;
  final List<Word> words;

  /// What the learner typed into the search field.
  final String query;
  final String? failureMessage;

  /// True only once a successful load has come back empty — an empty list
  /// during the first load is "not yet", not "nothing here".
  bool get isEmpty => status == WordsListStatus.ready && words.isEmpty;

  /// The words [query] matches, in the order they were loaded.
  ///
  /// Filtered here rather than in SQL: the list is already in memory in full,
  /// and a query round-trip per keystroke buys nothing at this size.
  List<Word> get visibleWords {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return words;
    return words.where((word) => _matches(word, needle)).toList();
  }

  /// True when there are words, but the query hides every one of them.
  ///
  /// Distinct from [isEmpty]: that is "you have collected nothing", this is
  /// "you have words, just none like this" — and the two want different
  /// screens.
  bool get hasNoMatches =>
      status == WordsListStatus.ready &&
      words.isNotEmpty &&
      visibleWords.isEmpty;

  WordsListState copyWith({
    WordsListStatus? status,
    List<Word>? words,
    String? query,
    String? failureMessage,
  }) => WordsListState(
    status: status ?? this.status,
    words: words ?? this.words,
    query: query ?? this.query,
    failureMessage: failureMessage,
  );

  /// Matches the word itself and what it means, so a half-remembered meaning
  /// finds the word — which is the search most worth having in a vocabulary
  /// list.
  static bool _matches(Word word, String needle) =>
      word.display.toLowerCase().contains(needle) ||
      word.lemma.toLowerCase().contains(needle) ||
      (word.meaningVi?.toLowerCase().contains(needle) ?? false) ||
      (word.meaningEn?.toLowerCase().contains(needle) ?? false);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WordsListState &&
          other.status == status &&
          other.query == query &&
          other.failureMessage == failureMessage &&
          _sameWords(other.words, words);

  @override
  int get hashCode => Object.hash(
    status,
    query,
    failureMessage,
    Object.hashAll(words.map((w) => w.id)),
  );

  static bool _sameWords(List<Word> a, List<Word> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }
}
