import 'package:meta/meta.dart';

import '../../../domain/entities/word.dart';

enum WordsListStatus { initial, loading, ready, failure }

@immutable
class WordsListState {
  const WordsListState({
    this.status = WordsListStatus.initial,
    this.words = const [],
    this.failureMessage,
  });

  final WordsListStatus status;
  final List<Word> words;
  final String? failureMessage;

  /// True only once a successful load has come back empty — an empty list
  /// during the first load is "not yet", not "nothing here".
  bool get isEmpty => status == WordsListStatus.ready && words.isEmpty;

  WordsListState copyWith({
    WordsListStatus? status,
    List<Word>? words,
    String? failureMessage,
  }) => WordsListState(
    status: status ?? this.status,
    words: words ?? this.words,
    failureMessage: failureMessage,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WordsListState &&
          other.status == status &&
          other.failureMessage == failureMessage &&
          _sameWords(other.words, words);

  @override
  int get hashCode => Object.hash(
    status,
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
