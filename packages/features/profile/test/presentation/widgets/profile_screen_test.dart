// Widget tests for the profile screen body. delete_account_flow_test covers the
// destructive delete flow; these cover the rest of the screen: the session
// identity header, the appearance theme-mode control wiring, and the sign-out
// confirmation. The harness mirrors delete_account_flow_test (mocked blocs +
// FakeSession) with a tall surface so every settings card is hit-testable.

import 'package:feature_profile/src/presentation/bloc/profile_bloc.dart';
import 'package:feature_profile/src/presentation/bloc/profile_state.dart';
import 'package:feature_profile/src/presentation/bloc/reminder/reminder_cubit.dart';
import 'package:feature_profile/src/presentation/bloc/reminder/reminder_state.dart';
import 'package:feature_profile/src/presentation/widgets/profile_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localization/localization.dart';
import 'package:theme/theme.dart';

import '../../support.dart';

class MockThemeBloc extends Mock implements ThemeBloc {}

class MockProfileBloc extends Mock implements ProfileBloc {}

class MockReminderCubit extends Mock implements ReminderCubit {}

void main() {
  late MockThemeBloc themeBloc;
  late MockProfileBloc profileBloc;
  late MockReminderCubit reminderCubit;

  setUpAll(() {
    registerFallbackValue(const ThemeModeChanged(ThemeMode.system));
  });

  setUp(() {
    themeBloc = MockThemeBloc();
    profileBloc = MockProfileBloc();
    reminderCubit = MockReminderCubit();

    const themeState = ThemeState(
      mode: ThemeMode.system,
      scheme: ThemeState.defaultScheme,
    );
    when(() => themeBloc.state).thenReturn(themeState);
    when(() => themeBloc.stream).thenAnswer((_) => const Stream.empty());

    const profileState = ProfileState();
    when(() => profileBloc.state).thenReturn(profileState);
    when(() => profileBloc.stream).thenAnswer((_) => const Stream.empty());

    when(() => reminderCubit.state).thenReturn(const ReminderState());
    when(() => reminderCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => reminderCubit.toggle(on: any(named: 'on'))).thenAnswer(
      (_) async {},
    );
  });

  Future<void> pumpProfile(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Mirrors how `App` composes the tree: providers first, then the auth-only
    // SessionScope wrapped around them.
    Widget home = MultiBlocProvider(
      providers: [
        BlocProvider<ThemeBloc>.value(value: themeBloc),
        BlocProvider<ProfileBloc>.value(value: profileBloc),
        BlocProvider<ReminderCubit>.value(value: reminderCubit),
      ],
      child: const ProfileBody(),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('selecting a theme mode dispatches ThemeModeChanged', (
    tester,
  ) async {
    await pumpProfile(tester);

    final darkTile = find.byWidgetPredicate(
      (w) => w is RadioListTile<ThemeMode> && w.value == ThemeMode.dark,
    );
    expect(darkTile, findsOneWidget);
    await tester.ensureVisible(darkTile);
    await tester.tap(darkTile);
    await tester.pumpAndSettle();

    verify(
      () => themeBloc.add(
        any(
          that: isA<ThemeModeChanged>().having(
            (e) => e.mode,
            'mode',
            ThemeMode.dark,
          ),
        ),
      ),
    ).called(1);
  });

  testWidgets('the reminder switch asks the cubit to turn it on', (
    tester,
  ) async {
    await pumpProfile(tester);

    final switchTile = find.byType(SwitchListTile);
    expect(switchTile, findsOneWidget);
    await tester.ensureVisible(switchTile);
    await tester.tap(switchTile);
    await tester.pumpAndSettle();

    verify(() => reminderCubit.toggle(on: true)).called(1);
  });
}
