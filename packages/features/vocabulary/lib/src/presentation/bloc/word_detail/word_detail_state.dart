import 'package:meta/meta.dart';

import '../../../domain/entities/word.dart';

enum WordDetailStatus { loading, ready, failure }

@immutable
class WordDetailState {
  const WordDetailState({
    this.status = WordDetailStatus.loading,
    this.word,
    this.failureMessage,
  });

  final WordDetailStatus status;
  final Word? word;
  final String? failureMessage;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WordDetailState &&
          other.status == status &&
          other.word?.id == word?.id &&
          other.failureMessage == failureMessage;

  @override
  int get hashCode => Object.hash(status, word?.id, failureMessage);
}
