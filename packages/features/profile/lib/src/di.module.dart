// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i687;

import 'package:analytics/analytics.dart' as _i548;
import 'package:app_platform/app_platform.dart' as _i199;
import 'package:feature_profile/src/domain/daily_reminder.dart' as _i821;
import 'package:feature_profile/src/presentation/bloc/profile_bloc.dart'
    as _i56;
import 'package:feature_profile/src/presentation/bloc/reminder/reminder_cubit.dart'
    as _i604;
import 'package:injectable/injectable.dart' as _i526;
import 'package:storage/storage.dart' as _i431;

class FeatureProfilePackageModule extends _i526.MicroPackageModule {
  // initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    gh.lazySingleton<_i821.DailyReminder>(
      () => _i821.DailyReminder(
        gh<_i431.ReminderStore>(),
        gh<_i199.NotificationsService>(),
        gh<_i199.PermissionService>(),
      ),
    );
    gh.factory<_i56.ProfileBloc>(
      () => _i56.ProfileBloc(gh<_i548.AnalyticsService>()),
    );
    gh.factory<_i604.ReminderCubit>(
      () => _i604.ReminderCubit(gh<_i821.DailyReminder>()),
    );
  }
}
