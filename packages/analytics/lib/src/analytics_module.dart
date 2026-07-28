import 'package:injectable/injectable.dart';

import 'analytics_service.dart';

@module
abstract class AnalyticsModule {
  /// Binds the app's [AnalyticsService].
  ///
  /// `fst create --no-firebase` rewrites the expression at the
  /// `// fst:analytics-impl` marker to `const NoOpAnalyticsService()`. To use a
  /// non-Firebase backend, replace it with your own [AnalyticsService].
  @lazySingleton
  AnalyticsService provideAnalyticsService() =>
      const NoOpAnalyticsService(); // fst:analytics-impl
}
