import 'package:architecture/architecture.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../domain/usecases/add_word.dart';
import 'add_word_state.dart';

@injectable
class AddWordCubit extends Cubit<AddWordState> {
  AddWordCubit(this._addWord) : super(const AddWordState());

  final AddWord _addWord;

  void displayChanged(String value) =>
      emit(state.copyWith(display: value, status: AddWordStatus.editing));

  void sentenceChanged(String value) =>
      emit(state.copyWith(sentence: value, status: AddWordStatus.editing));

  void meaningChanged(String value) =>
      emit(state.copyWith(meaningVi: value, status: AddWordStatus.editing));

  Future<void> submit() async {
    if (!state.canSubmit) return;
    emit(state.copyWith(status: AddWordStatus.submitting));

    final result = await _addWord(
      AddWordParams(
        display: state.display,
        sentence: state.sentence,
        meaningVi: state.meaningVi,
      ),
    );

    switch (result) {
      case Ok():
        emit(state.copyWith(status: AddWordStatus.success));
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
