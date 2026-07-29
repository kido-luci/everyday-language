import 'package:flutter_test/flutter_test.dart';
import 'package:storage/storage.dart';
import 'package:test_utils/test_utils.dart';

void main() {
  const enabledKey = 'study.reminder_enabled';
  const minutesKey = 'study.reminder_minutes';

  late MockSharedPreferences prefs;
  late ReminderStore store;

  setUp(() {
    prefs = MockSharedPreferences();
    store = ReminderStore(prefs);

    when(() => prefs.setBool(any(), any())).thenAnswer((_) async => true);
    when(() => prefs.setInt(any(), any())).thenAnswer((_) async => true);
  });

  group('ReminderStore', () {
    test('is off by default, at eight in the evening', () {
      when(() => prefs.getBool(enabledKey)).thenReturn(null);
      when(() => prefs.getInt(minutesKey)).thenReturn(null);

      expect(store.isEnabled(), isFalse);
      expect(store.readMinutes(), 20 * 60);
    });

    test('reads back what was stored', () {
      when(() => prefs.getBool(enabledKey)).thenReturn(true);
      when(() => prefs.getInt(minutesKey)).thenReturn(7 * 60 + 15);

      expect(store.isEnabled(), isTrue);
      expect(store.readMinutes(), 7 * 60 + 15);
    });

    test('writes both keys together', () async {
      await store.write(enabled: true, minutes: 21 * 60 + 30);

      verify(() => prefs.setBool(enabledKey, true)).called(1);
      verify(() => prefs.setInt(minutesKey, 21 * 60 + 30)).called(1);
    });

    test('wraps a time past midnight back into the day', () async {
      await store.write(enabled: true, minutes: 24 * 60 + 30);

      verify(() => prefs.setInt(minutesKey, 30)).called(1);
    });
  });
}
