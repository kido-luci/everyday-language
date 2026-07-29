import 'package:architecture/architecture.dart';
import 'package:everyday_language/app/di/injection.dart';
import 'package:feature_home/feature_home.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_contracts/shared_contracts.dart';
import 'package:storage/storage.dart';
import 'package:theme/theme.dart';

import 'test_utils.dart';

void main() {
  late MockAnalyticsService analytics;
  late ThemeBloc themeBloc;
  HomeBloc? homeBloc;

  setUp(() async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({});
    analytics = MockAnalyticsService();
    stubAnalyticsService(analytics);

    final studyStats = MockStudyStatsReader();
    when(studyStats.call).thenAnswer((_) async => const Ok(StudyStats()));

    final prefs = await SharedPreferences.getInstance();
    themeBloc = ThemeBloc(prefs, analytics);

    // The dashboard subscribes to this on mount, so the app cannot be pumped
    // without one registered.
    getIt.registerSingleton<ActivityNotifier>(ActivityNotifier());

    getIt.registerFactory<HomeBloc>(() {
      final bloc = HomeBloc(studyStats, DailyGoalStore(prefs));
      homeBloc = bloc;
      return bloc;
    });
  });

  tearDown(() async {
    await getIt.reset();
    final bloc = homeBloc;
    if (bloc != null && !bloc.isClosed) {
      await bloc.close();
    }
    await themeBloc.close();
  });
}
