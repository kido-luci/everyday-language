// The dashboard's view model: it maps study figures into state and owns the
// daily goal. The goal is exercised against a real DailyGoalStore backed by
// mock preferences rather than a double, because the behaviour worth pinning
// is the store's clamping — the bloc deliberately reports what was kept, not
// what was asked for.

import 'package:architecture/architecture.dart';
import 'package:feature_home/feature_home.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_contracts/shared_contracts.dart';
import 'package:storage/storage.dart';

import '../../support.dart';

void main() {
  late MockStudyStatsReader reader;
  late DailyGoalStore goals;

  const stats = StudyStats(
    streakDays: 4,
    reviewsToday: 12,
    dueNow: 7,
    totalWords: 60,
  );

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    goals = DailyGoalStore(await SharedPreferences.getInstance());
    reader = MockStudyStatsReader();
  });

  test('loads the figures and the stored goal', () async {
    when(reader.call).thenAnswer((_) async => const Ok(stats));
    await goals.write(30);

    final bloc = HomeBloc(reader, goals)..add(const HomeLoadRequested());
    final state = await bloc.stream.firstWhere((s) => !s.isLoading);

    expect(state.stats.streakDays, 4);
    expect(state.stats.reviewsToday, 12);
    expect(state.stats.dueNow, 7);
    expect(state.stats.totalWords, 60);
    expect(state.dailyGoal, 30);
    expect(state.failure, isNull);

    await bloc.close();
  });

  test('falls back to the default goal when none was ever set', () async {
    when(reader.call).thenAnswer((_) async => const Ok(stats));

    final bloc = HomeBloc(reader, goals)..add(const HomeLoadRequested());
    final state = await bloc.stream.firstWhere((s) => !s.isLoading);

    expect(state.dailyGoal, DailyGoalStore.defaultGoal);

    await bloc.close();
  });

  test('surfaces a read failure instead of showing zeros', () async {
    when(
      reader.call,
    ).thenAnswer(
      (_) async => const Err(UnknownFailure('database unavailable')),
    );

    final bloc = HomeBloc(reader, goals)..add(const HomeLoadRequested());
    final state = await bloc.stream.firstWhere((s) => !s.isLoading);

    expect(state.failure, isNotNull);
    expect(
      state.stats.totalWords,
      0,
      reason: 'nothing was read, so nothing is claimed',
    );

    await bloc.close();
  });

  test('a new goal is stored and reported back', () async {
    when(reader.call).thenAnswer((_) async => const Ok(stats));

    final bloc = HomeBloc(reader, goals)..add(const HomeGoalChanged(45));
    final state = await bloc.stream.firstWhere((s) => s.dailyGoal == 45);

    expect(state.dailyGoal, 45);
    expect(goals.read(), 45, reason: 'and it survives a restart');

    await bloc.close();
  });

  test('a goal beyond the supported range is reported as clamped', () async {
    when(reader.call).thenAnswer((_) async => const Ok(stats));

    final bloc = HomeBloc(reader, goals)..add(const HomeGoalChanged(100000));
    final state = await bloc.stream.first;

    expect(
      state.dailyGoal,
      DailyGoalStore.maxGoal,
      reason: 'reporting what was asked for would misstate what was kept',
    );

    await bloc.close();
  });

  group('goal progress', () {
    test('is the fraction of the goal done today', () {
      const state = HomeState(
        stats: StudyStats(reviewsToday: 5),
        dailyGoal: 20,
      );
      expect(state.goalProgress, 0.25);
    });

    test('stops at full rather than overflowing', () {
      const state = HomeState(
        stats: StudyStats(reviewsToday: 99),
        dailyGoal: 20,
      );
      expect(state.goalProgress, 1.0);
    });

    test('survives a goal of zero rather than dividing by it', () {
      const state = HomeState(stats: StudyStats(reviewsToday: 1), dailyGoal: 0);
      expect(state.goalProgress, 1.0);
    });
  });
}
