part of 'home_bloc.dart';

sealed class HomeEvent {
  const HomeEvent();
}

final class HomeLoadRequested extends HomeEvent {
  const HomeLoadRequested();
}

/// The learner picked a new number of reviews to aim for each day.
final class HomeGoalChanged extends HomeEvent {
  const HomeGoalChanged(this.goal);

  final int goal;
}
