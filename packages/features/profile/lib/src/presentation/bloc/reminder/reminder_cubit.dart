import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../domain/daily_reminder.dart';
import 'reminder_state.dart';

@injectable
class ReminderCubit extends Cubit<ReminderState> {
  ReminderCubit(this._reminder) : super(const ReminderState());

  final DailyReminder _reminder;

  void load() {
    emit(
      ReminderState(
        enabled: _reminder.isEnabled(),
        minutes: _reminder.scheduledMinutes(),
      ),
    );
  }

  /// Turns the reminder on or off.
  ///
  /// Turning it on can fail — the permission is the OS's to give — so the new
  /// value comes from what actually happened, never from what was asked for.
  Future<void> toggle({required bool on}) async {
    if (!on) {
      await _reminder.disable();
      emit(state.copyWith(enabled: false, permissionBlocked: false));
      return;
    }
    final granted = await _reminder.enable(state.minutes);
    emit(state.copyWith(enabled: granted, permissionBlocked: !granted));
  }

  /// Moves the reminder to [minutes] past midnight.
  Future<void> changeTime(int minutes) async {
    await _reminder.setTime(minutes);
    emit(state.copyWith(minutes: minutes));
  }

  Future<void> openSystemSettings() => _reminder.openSystemSettings();

  /// Clears [ReminderState.permissionBlocked] once the screen has shown it,
  /// so a later rebuild does not repeat the message.
  void acknowledgePermissionNotice() {
    if (!state.permissionBlocked) return;
    emit(state.copyWith(permissionBlocked: false));
  }
}
