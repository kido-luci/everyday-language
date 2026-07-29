/// Home feature: the dashboard presentation layer.
///
/// The host app wires `FeatureHomePackageModule` via
/// `externalPackageModulesBefore` and mounts the exported `HomeScreen` in its
/// router. The bloc is exported so the app's shared test mocks can reference
/// it; data-less, this feature reads the learner's study figures through the
/// `StudyStatsReader` contract in `shared_contracts` rather than depending on
/// the vocabulary feature that owns them.
library;

export 'src/di.module.dart' show FeatureHomePackageModule;
export 'src/presentation/bloc/home_bloc.dart';
export 'src/presentation/bloc/home_state.dart';
export 'src/presentation/screens/home_screen.dart';
export 'src/presentation/widgets/home_widgets.dart' show HomeDashboardKeys;
