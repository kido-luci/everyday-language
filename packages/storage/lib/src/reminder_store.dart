import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kReminderEnabledKey = 'study.reminder_enabled';
const _kReminderMinutesKey = 'study.reminder_minutes';

/// Whether the learner wants a daily nudge, and when.
///
/// The time is minutes from midnight rather than an hour/minute pair: it is
/// what a time picker's result reduces to, and one key cannot be found
/// half-written the way two can.
///
/// Off by default. A reminder the learner never asked for is a notification
/// they will turn off at the OS level, which costs every future one too.
@lazySingleton
class ReminderStore {
  ReminderStore(this._prefs);

  final SharedPreferences _prefs;

  /// Eight in the evening — late enough that the day's obligations are done,
  /// early enough that there is still time to act on it.
  static const int defaultMinutes = 20 * 60;

  bool isEnabled() => _prefs.getBool(_kReminderEnabledKey) ?? false;

  int readMinutes() => _prefs.getInt(_kReminderMinutesKey) ?? defaultMinutes;

  /// Stores [enabled] and [minutes], the latter wrapped into a single day.
  Future<void> write({required bool enabled, required int minutes}) async {
    await _prefs.setBool(_kReminderEnabledKey, enabled);
    await _prefs.setInt(
      _kReminderMinutesKey,
      minutes % Duration.minutesPerDay,
    );
  }
}
