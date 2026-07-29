import 'package:architecture/architecture.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_contracts/shared_contracts.dart';
import 'package:storage/storage.dart';

import 'home_state.dart';

part 'home_event.dart';

/// The dashboard's view model.
///
/// Reads study figures through [StudyStatsReader] rather than reaching into
/// the vocabulary feature: this feature owns no data, and the reader is the
/// documented seam between the two.
@injectable
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc(this._stats, this._goals) : super(const HomeState()) {
    on<HomeLoadRequested>(_onLoadRequested, transformer: droppable());
    on<HomeGoalChanged>(_onGoalChanged, transformer: sequential());
  }

  final StudyStatsReader _stats;
  final DailyGoalStore _goals;

  Future<void> _onLoadRequested(
    HomeLoadRequested event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, failure: null));

    final result = await _stats();
    switch (result) {
      case Ok(value: final stats):
        emit(
          state.copyWith(
            isLoading: false,
            failure: null,
            stats: stats,
            dailyGoal: _goals.read(),
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(isLoading: false, failure: failure));
    }
  }

  Future<void> _onGoalChanged(
    HomeGoalChanged event,
    Emitter<HomeState> emit,
  ) async {
    await _goals.write(event.goal);
    // Read back rather than echoing what was asked for: the store clamps to a
    // supported range, and the dashboard should show what was actually kept.
    emit(state.copyWith(dailyGoal: _goals.read()));
  }
}
