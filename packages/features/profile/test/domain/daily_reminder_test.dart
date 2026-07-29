import 'dart:ui';

import 'package:feature_profile/src/domain/daily_reminder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storage/storage.dart';

import '../support.dart';

class MockReminderStore extends Mock implements ReminderStore {}

void main() {
  late MockReminderStore store;
  late MockNotificationsService notifications;
  late MockPermissionService permissions;

  DailyReminder buildReminder([Locale locale = const Locale('en')]) =>
      DailyReminder.custom(store, notifications, permissions, () => locale);

  /// Everything the store is asked for, with [minutes] as the stored time.
  void stubStore({required bool enabled, int minutes = 20 * 60}) {
    when(store.isEnabled).thenReturn(enabled);
    when(store.readMinutes).thenReturn(minutes);
  }

  setUp(() {
    store = MockReminderStore();
    notifications = MockNotificationsService();
    permissions = MockPermissionService();

    when(
      () => store.write(
        enabled: any(named: 'enabled'),
        minutes: any(named: 'minutes'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => notifications.scheduleDaily(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        hour: any(named: 'hour'),
        minute: any(named: 'minute'),
      ),
    ).thenAnswer((_) async {});
    when(() => notifications.cancel(any())).thenAnswer((_) async {});
  });

  group('enable', () {
    test('stores the choice and schedules it at that time', () async {
      stubStore(enabled: false);
      when(
        permissions.requestNotificationPermission,
      ).thenAnswer((_) async => true);

      final granted = await buildReminder().enable(7 * 60 + 30);

      expect(granted, isTrue);
      verify(() => store.write(enabled: true, minutes: 7 * 60 + 30)).called(1);
      verify(
        () => notifications.scheduleDaily(
          id: DailyReminder.notificationId,
          title: any(named: 'title'),
          body: any(named: 'body'),
          hour: 7,
          minute: 30,
        ),
      ).called(1);
    });

    test('stores nothing when the permission is refused', () async {
      stubStore(enabled: false);
      when(
        permissions.requestNotificationPermission,
      ).thenAnswer((_) async => false);

      final granted = await buildReminder().enable(7 * 60 + 30);

      expect(granted, isFalse);
      verifyNever(
        () => store.write(
          enabled: any(named: 'enabled'),
          minutes: any(named: 'minutes'),
        ),
      );
      verifyNever(
        () => notifications.scheduleDaily(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          hour: any(named: 'hour'),
          minute: any(named: 'minute'),
        ),
      );
    });
  });

  test('disable cancels the pending notification', () async {
    stubStore(enabled: true, minutes: 9 * 60);

    await buildReminder().disable();

    verify(() => store.write(enabled: false, minutes: 9 * 60)).called(1);
    verify(() => notifications.cancel(DailyReminder.notificationId)).called(1);
  });

  group('setTime', () {
    test('re-schedules while the reminder is on', () async {
      stubStore(enabled: true);

      await buildReminder().setTime(6 * 60 + 5);

      verify(() => store.write(enabled: true, minutes: 6 * 60 + 5)).called(1);
      verify(
        () => notifications.scheduleDaily(
          id: DailyReminder.notificationId,
          title: any(named: 'title'),
          body: any(named: 'body'),
          hour: 6,
          minute: 5,
        ),
      ).called(1);
    });

    test('only remembers the time while the reminder is off', () async {
      stubStore(enabled: false);

      await buildReminder().setTime(6 * 60 + 5);

      verify(() => store.write(enabled: false, minutes: 6 * 60 + 5)).called(1);
      verifyNever(
        () => notifications.scheduleDaily(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          hour: any(named: 'hour'),
          minute: any(named: 'minute'),
        ),
      );
    });
  });

  group('restore', () {
    test('re-arms a reminder that is on', () async {
      stubStore(enabled: true, minutes: 21 * 60 + 45);

      await buildReminder().restore();

      verify(
        () => notifications.scheduleDaily(
          id: DailyReminder.notificationId,
          title: any(named: 'title'),
          body: any(named: 'body'),
          hour: 21,
          minute: 45,
        ),
      ).called(1);
    });

    test('does nothing when the learner has no reminder', () async {
      stubStore(enabled: false);

      await buildReminder().restore();

      verifyNever(
        () => notifications.scheduleDaily(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          hour: any(named: 'hour'),
          minute: any(named: 'minute'),
        ),
      );
    });
  });

  group('the notification is written in the device language', () {
    /// The title [reminder] would schedule.
    Future<String> scheduledTitle(DailyReminder reminder) async {
      await reminder.restore();
      final captured = verify(
        () => notifications.scheduleDaily(
          id: any(named: 'id'),
          title: captureAny(named: 'title'),
          body: any(named: 'body'),
          hour: any(named: 'hour'),
          minute: any(named: 'minute'),
        ),
      ).captured;
      return captured.single as String;
    }

    setUp(() => stubStore(enabled: true));

    test('a supported language is used', () async {
      expect(
        await scheduledTitle(buildReminder(const Locale('vi'))),
        'Đến giờ ôn từ rồi',
      );
    });

    test('an unsupported one falls back to English', () async {
      // `lookupAppLocalizations` throws on a language it was not generated
      // for, and this runs with no Localizations widget above it to have
      // already resolved one.
      expect(
        await scheduledTitle(buildReminder(const Locale('fr'))),
        'Time to practise',
      );
    });
  });
}
