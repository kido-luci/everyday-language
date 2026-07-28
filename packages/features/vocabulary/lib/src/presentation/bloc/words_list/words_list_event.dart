import 'package:meta/meta.dart';

@immutable
sealed class WordsListEvent {
  const WordsListEvent();
}

/// Load, or reload after something changed elsewhere.
final class WordsRequested extends WordsListEvent {
  const WordsRequested();
}

final class WordDeleted extends WordsListEvent {
  const WordDeleted(this.id);

  final int id;
}
