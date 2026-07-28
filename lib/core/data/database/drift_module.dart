import 'package:database/database.dart';
import 'package:injectable/injectable.dart';

/// Drift DI module: provides [AppDatabase] and the feature data sources backed
/// by Drift. Auto-discovered by injectable_generator via the `@module`
/// annotation — no explicit entry in `externalPackageModulesBefore` needed.
@module
abstract class DriftModule {
  @lazySingleton
  AppDatabase provideDatabase() => AppDatabase.open();
}
