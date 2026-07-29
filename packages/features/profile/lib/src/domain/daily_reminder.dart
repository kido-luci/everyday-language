import 'dart:ui';

import 'package:app_platform/app_platform.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:localization/localization.dart';
import 'package:storage/storage.dart';

/// Reads the locale the notification should be written in.
typedef LocaleReader = Locale Function();

/// The daily "come back and practise" reminder: the preference, the schedule,
/// and the permission the schedule needs.
///
/// Kept out of the cubit because the app bootstrap needs it too — see
/// [restore]. Keeping the three in one place is what stops the stored
/// preference and the pending notification from drifting apart.
@lazySingleton
class DailyReminder {
  DailyReminder(this._store, this._notifications, this._permissions)
    : _readLocale = _systemLocale;

  @visibleForTesting
  DailyReminder.custom(
    this._store,
    this._notifications,
    this._permissions,
    this._readLocale,
  );

  final ReminderStore _store;
  final NotificationsService _notifications;
  final PermissionService _permissions;
  final LocaleReader _readLocale;

  /// Fixed, so re-scheduling replaces the pending reminder instead of stacking
  /// a second one on top of it.
  static const int notificationId = 1001;

  bool isEnabled() => _store.isEnabled();

  int scheduledMinutes() => _store.readMinutes();

  /// Turns the reminder on at [minutes] past midnight.
  ///
  /// Returns false when the user refuses the notification permission, in which
  /// case nothing is stored: a switch that stays on while the OS drops every
  /// notification is worse than one that visibly refuses to move.
  Future<bool> enable(int minutes) async {
    if (!await _permissions.requestNotificationPermission()) return false;
    await _store.write(enabled: true, minutes: minutes);
    await _schedule(minutes);
    return true;
  }

  Future<void> disable() async {
    await _store.write(enabled: false, minutes: _store.readMinutes());
    await _notifications.cancel(notificationId);
  }

  /// Moves the reminder to [minutes] past midnight without changing whether it
  /// is on — a time picked while the reminder is off is still the time it will
  /// use once it is turned on.
  Future<void> setTime(int minutes) async {
    await _store.write(enabled: _store.isEnabled(), minutes: minutes);
    if (_store.isEnabled()) await _schedule(minutes);
  }

  /// Opens the OS settings page for the app.
  ///
  /// Once notifications are refused, the app cannot ask again — only the
  /// settings page can undo it, so the refusal message has to be able to get
  /// the learner there.
  Future<void> openSystemSettings() => _permissions.openAppSettingsPage();

  /// Re-arms the reminder at startup, if the learner wants one.
  ///
  /// The schedule lives in the OS, and it survives a reboot but not an
  /// install — so without this, reinstalling the app silently ends the
  /// reminders while the setting still reads "on". It also re-pins the
  /// schedule to the current timezone, which matters to anyone who moves.
  Future<void> restore() async {
    if (!_store.isEnabled()) return;
    await _schedule(_store.readMinutes());
  }

  Future<void> _schedule(int minutes) {
    final l10n = lookupAppLocalizations(_resolveLocale());
    return _notifications.scheduleDaily(
      id: notificationId,
      title: l10n.reminderNotificationTitle,
      body: l10n.reminderNotificationBody,
      hour: minutes ~/ Duration.minutesPerHour,
      minute: minutes % Duration.minutesPerHour,
    );
  }

  /// The supported locale closest to the device's.
  ///
  /// `lookupAppLocalizations` throws on a language it was not generated for,
  /// and this runs outside the widget tree — there is no `Localizations` above
  /// it to have already resolved one.
  Locale _resolveLocale() {
    final system = _readLocale();
    return AppLocalizations.supportedLocales.firstWhere(
      (locale) => locale.languageCode == system.languageCode,
      orElse: () => const Locale('en'),
    );
  }
}

Locale _systemLocale() => PlatformDispatcher.instance.locale;
