/// Profile feature: the account and settings presentation layer.
///
/// The host app wires `FeatureProfilePackageModule` via
/// `externalPackageModulesBefore` and mounts the exported `ProfileScreen` in
/// its router. Profile surfaces auth's delete-account flow as a single-consumer
/// capability and owns its own reaction to it (snackbars, session clearing).
///
/// It also owns the daily reminder, because that is where its switch lives.
/// `DailyReminder` is exported for one caller: the app bootstrap has to re-arm
/// the schedule, which does not survive a reinstall.
library;

export 'src/di.module.dart' show FeatureProfilePackageModule;
export 'src/domain/daily_reminder.dart' show DailyReminder;
export 'src/presentation/bloc/profile_bloc.dart';
export 'src/presentation/bloc/profile_state.dart';
export 'src/presentation/screens/profile_screen.dart';
