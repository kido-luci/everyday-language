import 'package:feature_profile/src/domain/daily_reminder.dart';
import 'package:feature_profile/src/presentation/bloc/reminder/reminder_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support.dart';

class MockDailyReminder extends Mock implements DailyReminder {}

void main() {
  late MockDailyReminder reminder;
  late ReminderCubit cubit;

  setUp(() {
    reminder = MockDailyReminder();
    cubit = ReminderCubit(reminder);

    when(reminder.isEnabled).thenReturn(false);
    when(reminder.scheduledMinutes).thenReturn(20 * 60);
    when(reminder.disable).thenAnswer((_) async {});
    when(() => reminder.setTime(any())).thenAnswer((_) async {});
  });

  tearDown(() => cubit.close());

  test('load shows what is stored', () {
    when(reminder.isEnabled).thenReturn(true);
    when(reminder.scheduledMinutes).thenReturn(7 * 60 + 30);

    cubit.load();

    expect(cubit.state.enabled, isTrue);
    expect(cubit.state.hour, 7);
    expect(cubit.state.minute, 30);
  });

  test('turning it on uses the time on screen', () async {
    when(() => reminder.enable(any())).thenAnswer((_) async => true);
    cubit.load();
    await cubit.changeTime(6 * 60 + 45);

    await cubit.toggle(on: true);

    verify(() => reminder.enable(6 * 60 + 45)).called(1);
    expect(cubit.state.enabled, isTrue);
    expect(cubit.state.permissionBlocked, isFalse);
  });

  test('a refused permission leaves the switch off, and says so', () async {
    when(() => reminder.enable(any())).thenAnswer((_) async => false);

    await cubit.toggle(on: true);

    expect(cubit.state.enabled, isFalse);
    expect(cubit.state.permissionBlocked, isTrue);
  });

  test('the refusal notice is shown once', () async {
    when(() => reminder.enable(any())).thenAnswer((_) async => false);
    await cubit.toggle(on: true);

    cubit.acknowledgePermissionNotice();

    expect(cubit.state.permissionBlocked, isFalse);
  });

  test('turning it off cancels the reminder', () async {
    when(() => reminder.enable(any())).thenAnswer((_) async => true);
    await cubit.toggle(on: true);

    await cubit.toggle(on: false);

    verify(reminder.disable).called(1);
    expect(cubit.state.enabled, isFalse);
  });

  test('changing the time keeps the reminder on', () async {
    when(reminder.isEnabled).thenReturn(true);
    cubit.load();

    await cubit.changeTime(9 * 60 + 5);

    verify(() => reminder.setTime(9 * 60 + 5)).called(1);
    expect(cubit.state.enabled, isTrue);
    expect(cubit.state.hour, 9);
    expect(cubit.state.minute, 5);
  });
}
