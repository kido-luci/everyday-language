import 'package:injectable/injectable.dart';
import 'package:srs/srs.dart';

/// Code-generation anchor for the feature_vocabulary micro-package.
///
/// Running `build_runner` here generates `di.module.dart` containing
/// `FeatureVocabularyPackageModule`, which the host app wires via
/// `externalPackageModulesBefore`.
@InjectableInit.microPackage()
void initVocabularyFeature() {}

/// Third-party objects this feature needs registered.
@module
abstract class VocabularyExternalModule {
  /// `package:srs` is a plain Dart package with no DI of its own, so the
  /// feature that uses it registers it. Defaults are deliberate: 0.9 retention
  /// is FSRS's own, and there is no review history yet to tune against.
  @lazySingleton
  SrsScheduler provideScheduler() => SrsScheduler();
}
