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


    final bookmarkStats = MockBookmarkStatsReader();
    when(
      bookmarkStats.call,
    ).thenAnswer((_) async => const Ok(BookmarkStats()));

    final collectionsReader = MockCollectionsReader();
    when(
      collectionsReader.call,
    ).thenAnswer((_) async => const Ok<List<CollectionSummary>>([]));

    themeBloc = ThemeBloc(await SharedPreferences.getInstance(), analytics);

    getIt.registerFactory<HomeBloc>(() {
      final bloc = HomeBloc(bookmarkStats, collectionsReader);
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
