import 'package:architecture/architecture.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shared_contracts/shared_contracts.dart';
import 'package:storage/storage.dart';

part 'home_state.freezed.dart';

@freezed
abstract class HomeState with _$HomeState {
  const factory HomeState({
    @Default(StudyStats()) StudyStats stats,
    @Default(DailyGoalStore.defaultGoal) int dailyGoal,
    @Default(false) bool isLoading,
    Failure? failure,
  }) = _HomeState;

  const HomeState._();

  /// How far through today's goal the learner is, from 0 to 1.
  ///
  /// Clamped at the top so overshooting shows a full bar rather than an
  /// overflowing one, and guarded at the bottom because a goal of zero should
  /// never reach the store — but dividing by it would take the dashboard down
  /// rather than merely look wrong.
  double get goalProgress =>
      dailyGoal <= 0 ? 1 : (stats.reviewsToday / dailyGoal).clamp(0.0, 1.0);

  /// Whether there is anything to study yet.
  ///
  /// A learner with no words has no streak worth reporting and nothing due, so
  /// the dashboard offers a way in rather than three zeros.
  bool get hasNothingToStudy => stats.totalWords == 0;
}
