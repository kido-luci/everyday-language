import 'package:architecture/architecture.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../domain/usecases/get_word.dart';
import 'word_detail_state.dart';

@injectable
class WordDetailCubit extends Cubit<WordDetailState> {
  WordDetailCubit(this._getWord) : super(const WordDetailState());

  final GetWord _getWord;

  Future<void> load(int id) async {
    emit(const WordDetailState());
    switch (await _getWord(id)) {
      case Ok(:final value):
        emit(WordDetailState(status: WordDetailStatus.ready, word: value));
      case Err(:final failure):
        emit(
          WordDetailState(
            status: WordDetailStatus.failure,
            failureMessage: failure.message,
          ),
        );
    }
  }
}
