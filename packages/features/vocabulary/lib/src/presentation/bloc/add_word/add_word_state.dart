import 'package:meta/meta.dart';

enum AddWordStatus { editing, submitting, success, failure }

@immutable
class AddWordState {
  const AddWordState({
    this.display = '',
    this.sentence = '',
    this.status = AddWordStatus.editing,
    this.failureMessage,
  });

  final String display;
  final String sentence;
  final AddWordStatus status;
  final String? failureMessage;

  /// Whether the form is worth submitting.
  ///
  /// Only checks that there is a word at all — the real rules (single token,
  /// sentence must contain the word) live in the use case, so they cannot be
  /// bypassed by another caller.
  bool get canSubmit =>
      display.trim().isNotEmpty && status != AddWordStatus.submitting;

  AddWordState copyWith({
    String? display,
    String? sentence,
    AddWordStatus? status,
    String? failureMessage,
  }) => AddWordState(
    display: display ?? this.display,
    sentence: sentence ?? this.sentence,
    status: status ?? this.status,
    failureMessage: failureMessage,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AddWordState &&
          other.display == display &&
          other.sentence == sentence &&
          other.status == status &&
          other.failureMessage == failureMessage;

  @override
  int get hashCode => Object.hash(display, sentence, status, failureMessage);
}
