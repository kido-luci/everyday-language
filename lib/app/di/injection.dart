import 'package:analytics/analytics.dart';
import 'package:app_platform/app_platform.dart';
import 'package:config/config.dart';
import 'package:feature_home/feature_home.dart';
import 'package:feature_profile/feature_profile.dart';
import 'package:feature_vocabulary/feature_vocabulary.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_contracts/shared_contracts.dart';
import 'package:storage/storage.dart';
import 'package:theme/theme.dart';

import 'injection.config.dart';
import 'reader_fallbacks.dart';

final GetIt getIt = GetIt.instance;

/// Async because core database modules use `@preResolve` to open native
/// resources before any consumer is constructed. Must be awaited from `main`.
///
/// Ordering: `storage` provides the `AuthTokenStore` + `FlutterSecureStorage`
/// that `network` builds the authenticated `Dio` on, so it is listed before
/// `network`. `shared_contracts` registers `ActivityNotifier`, consumed by a
/// feature BLoC, so it precedes the feature modules. The authenticated `Dio` is
/// now provided by `network` (not by `feature_auth`), so no feature module
/// needs to be ordered relative to `feature_auth` for it.
@InjectableInit(
  externalPackageModulesBefore: [
    ExternalModule(AnalyticsPackageModule),
    ExternalModule(ConfigPackageModule),
    ExternalModule(StoragePackageModule),
    ExternalModule(AppPlatformPackageModule),
    ExternalModule(ThemePackageModule),
    ExternalModule(SharedContractsPackageModule),
    ExternalModule(FeatureHomePackageModule),
    ExternalModule(FeatureProfilePackageModule),
    ExternalModule(FeatureVocabularyPackageModule),
    // fst:feature-modules — `fst add-feature` inserts new feature modules above
  ],
)
Future<void> configureDependencies() async {
  await getIt.init();
  // Fill in Null-Object readers for any feature dropped at scaffold time, so
  // `home` keeps working when bookmarks/collections were excluded.
  registerReaderFallbacks(getIt);
}
