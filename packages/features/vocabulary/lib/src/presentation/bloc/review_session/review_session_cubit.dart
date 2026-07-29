import 'package:architecture/architecture.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:srs/srs.dart';

import '../../../domain/entities/review_card.dart';
import '../../../domain/usecases/grade_card.dart';
import '../../../domain/usecases/load_due_cards.dart';
import 'review_session_state.dart';

@injectable
class ReviewSessionCubit extends Cubit<ReviewSessionState> {
  ReviewSessionCubit(this._loadDueCards, this._gradeCard)
    : super(const ReviewSessionState());

  final LoadDueCards _loadDueCards;
  final GradeCard _gradeCard;

  Future<void> start() async {
    emit(const ReviewSessionState());
    switch (await _loadDueCards()) {
      case Ok(:final value):
        emit(
          ReviewSessionState(
            status: value.isEmpty
                ? ReviewSessionStatus.finished
                : ReviewSessionStatus.reviewing,
            queue: value,
          ),
        );
      case Err(:final failure):
        emit(
          ReviewSessionState(
            status: ReviewSessionStatus.failure,
            failureMessage: failure.message,
          ),
        );
    }
  }

  /// Shows the answer on a recognition card.
  ///
  /// Refused on a typing drill: there the answer appears by submitting one, and
  /// a reveal button would be a way to skip the retrieval the card exists for.
  void reveal() {
    if (state.current == null || state.isRevealed || state.isTypingDrill) {
      return;
    }
    emit(state.copyWith(isRevealed: true, typed: state.typed));
  }

  void answerChanged(String value) {
    if (state.isRevealed) return;
    emit(state.copyWith(typed: value));
  }

  /// Checks what was typed and shows the answer either way.
  ///
  /// Deliberately does not grade. A wrong answer still has to show the word —
  /// being told you were wrong and moving on teaches nothing — so the grade is
  /// a separate step, with `again` as the only option offered.
  void submitAnswer() {
    final card = state.current;
    if (card == null || !state.canSubmitAnswer) return;
    emit(
      state.copyWith(
        isRevealed: true,
        wasCorrect: card.accepts(state.typed),
      ),
    );
  }

  /// Grades the card on screen and moves on.
  ///
  /// A card still in learning or relearning goes to the back of the queue
  /// rather than out of it: those phases exist precisely to repeat the card
  /// within the same sitting, and dropping it would mean the learner never
  /// sees the word they just failed.
  Future<void> grade(ReviewGrade grade) async {
    final card = state.current;
    if (card == null || !state.isRevealed) return;
    // Typing it wrong is not recall, whatever the learner would rather press.
    if (state.wasCorrect == false && grade != ReviewGrade.again) return;

    final result = await _gradeCard(
      GradeCardParams(card: card, grade: grade),
    );

    switch (result) {
      case Ok(:final value):
        final rest = state.queue.sublist(1);
        final stillLearning =
            value.phase == SchedulePhase.learning ||
            value.phase == SchedulePhase.relearning;
        final queue = [
          ...rest,
          if (stillLearning)
            ReviewCard(
              id: card.id,
              kind: card.kind,
              schedule: value,
              display: card.display,
              phonetic: card.phonetic,
              meaning: card.meaning,
              collocation: card.collocation,
              sentence: card.sentence,
            ),
        ];
        emit(
          state.copyWith(
            queue: queue,
            isRevealed: false,
            typed: '',
            reviewed: state.reviewed + 1,
            status: queue.isEmpty
                ? ReviewSessionStatus.finished
                : ReviewSessionStatus.reviewing,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(failureMessage: failure.message));
    }
  }
}
