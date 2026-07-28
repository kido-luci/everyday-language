import 'package:architecture/architecture.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../domain/usecases/delete_word.dart';
import '../../../domain/usecases/list_words.dart';
import 'words_list_event.dart';
import 'words_list_state.dart';

@injectable
class WordsListBloc extends Bloc<WordsListEvent, WordsListState> {
  WordsListBloc(this._listWords, this._deleteWord)
    : super(const WordsListState()) {
    // `restartable`: a reload triggered while one is in flight should show the
    // newer result, not race the older one to the screen.
    on<WordsRequested>(_onRequested, transformer: restartable());
    on<WordDeleted>(_onDeleted, transformer: sequential());
  }

  final ListWords _listWords;
  final DeleteWord _deleteWord;

  Future<void> _onRequested(
    WordsRequested event,
    Emitter<WordsListState> emit,
  ) async {
    emit(state.copyWith(status: WordsListStatus.loading));
    switch (await _listWords()) {
      case Ok(:final value):
        emit(state.copyWith(status: WordsListStatus.ready, words: value));
      case Err(:final failure):
        emit(
          state.copyWith(
            status: WordsListStatus.failure,
            failureMessage: failure.message,
          ),
        );
    }
  }

  Future<void> _onDeleted(
    WordDeleted event,
    Emitter<WordsListState> emit,
  ) async {
    switch (await _deleteWord(event.id)) {
      case Ok():
        emit(
          state.copyWith(
            words: state.words.where((w) => w.id != event.id).toList(),
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(failureMessage: failure.message));
    }
  }
}
