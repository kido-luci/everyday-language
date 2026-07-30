import 'dart:async';

import 'package:architecture/architecture.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../domain/usecases/add_word.dart';
import '../../../domain/word_enricher.dart';
import 'add_word_state.dart';

@injectable
class AddWordCubit extends Cubit<AddWordState> {
  AddWordCubit(this._addWord, this._enricher) : super(const AddWordState());

  final AddWord _addWord;

  /// Looks up the meaning after the word is safely stored. A singleton, so the
  /// sweep outlives this cubit — the screen pops the moment the save lands.
  final WordEnricher _enricher;

  /// Seeds the form from text shared in from another app.
  ///
  /// Called once, as the screen is created. Nothing is validated here — the
  /// share is only a starting point, and the learner still has to press save,
  /// which is where the real rules run.
  void prefill({String? word, String? sentence}) {
    if (word == null && sentence == null) return;
    emit(
      state.copyWith(
        display: word ?? state.display,
        sentence: sentence ?? state.sentence,
      ),
    );
  }

  void displayChanged(String value) =>
      emit(state.copyWith(display: value, status: AddWordStatus.editing));

  void sentenceChanged(String value) =>
      emit(state.copyWith(sentence: value, status: AddWordStatus.editing));

  Future<void> submit() async {
    if (!state.canSubmit) return;
    emit(state.copyWith(status: AddWordStatus.submitting));

    final result = await _addWord(
      AddWordParams(display: state.display, sentence: state.sentence),
    );

    switch (result) {
      case Ok():
        emit(state.copyWith(status: AddWordStatus.success));
        // Not awaited: the word is stored, the screen is about to pop, and a
        // network round trip is not something to hold a save behind.
        unawaited(_enricher.sweep());
      case Err(:final failure):
        emit(
          state.copyWith(
            status: AddWordStatus.failure,
            failureMessage: failure.message,
          ),
        );
    }
  }
}
