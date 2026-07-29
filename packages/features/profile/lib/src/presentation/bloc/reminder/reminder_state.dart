import 'package:flutter/foundation.dart';
import 'package:storage/storage.dart';

@immutable
class ReminderState {
  const ReminderState({
    this.enabled = false,
    this.minutes = ReminderStore.defaultMinutes,
    this.permissionBlocked = false,
  });

  final bool enabled;

  /// Minutes past midnight, in the device's own zone.
  final int minutes;

  /// Set when the OS refused the notification permission, so the screen can
  /// explain why the switch sprang back instead of leaving it a mystery.
  final bool permissionBlocked;

  int get hour => minutes ~/ Duration.minutesPerHour;

  int get minute => minutes % Duration.minutesPerHour;

  ReminderState copyWith({
    bool? enabled,
    int? minutes,
    bool? permissionBlocked,
  }) {
    return ReminderState(
      enabled: enabled ?? this.enabled,
      minutes: minutes ?? this.minutes,
      permissionBlocked: permissionBlocked ?? this.permissionBlocked,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReminderState &&
          other.enabled == enabled &&
          other.minutes == minutes &&
          other.permissionBlocked == permissionBlocked;

  @override
  int get hashCode => Object.hash(enabled, minutes, permissionBlocked);
}
