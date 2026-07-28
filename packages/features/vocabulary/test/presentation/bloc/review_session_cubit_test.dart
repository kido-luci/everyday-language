import 'package:architecture/architecture.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:database/database.dart' show CardKind;
import 'package:feature_vocabulary/feature_vocabulary.dart';
import 'package:feature_vocabulary/src/domain/usecases/grade_card.dart';
import 'package:feature_vocabulary/src/domain/usecases/load_due_cards.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:srs/srs.dart';

class _MockLoad extends Mock implements LoadDueCards {}

class _MockGrade extends Mock implements GradeCard {}

class _FakeParams extends Fake implements GradeCardParams {}

final _due = DateTime.utc(2026, 6, 1, 9);

ReviewCard _card(int id, {CardKind kind = CardKind.recognise}) => ReviewCard(
  id: id,
  kind: kind,
  schedule: CardSchedule(dueAt: _due),
  display: 'w$id',
  meaning: 'nghĩa $id',
  sentence: 'A w$id in a sentence.',
);

CardSchedule _scheduled(SchedulePhase phase) =>
    CardSchedule(phase: phase, dueAt: _due.add(const Duration(days: 1)));

void main() {
  late _MockLoad load;
  late _MockGrade grade;

  setUpAll(() => registerFallbackValue(_FakeParams()));

  setUp(() {
    load = _MockLoad();
    grade = _MockGrade();
  });

  blocTest<ReviewSessionCubit, ReviewSessionState>(
    'an empty queue finishes the session rather than showing a blank card',
    setUp: () => when(load.call).thenAnswer((_) async => const Ok([])),
    build: () => ReviewSessionCubit(load, grade),
    act: (cubit) => cubit.start(),
    expect: () => [
      const ReviewSessionState(),
      isA<ReviewSessionState>()
          .having((s) => s.status, 'status', ReviewSessionStatus.finished)
          .having((s) => s.reviewed, 'reviewed', 0),
    ],
  );

  blocTest<ReviewSessionCubit, ReviewSessionState>(
    'grading is refused until the answer has been shown',
    setUp: () {
      when(load.call).thenAnswer((_) async => Ok([_card(1)]));
    },
    build: () => ReviewSessionCubit(load, grade),
    act: (cubit) async {
      await cubit.start();
      await cubit.grade(ReviewGrade.easy);
    },
    verify: (_) => verifyNever(() => grade(any())),
  );

  blocTest<ReviewSessionCubit, ReviewSessionState>(
    'a graduated card leaves the queue',
    setUp: () {
      when(load.call).thenAnswer((_) async => Ok([_card(1), _card(2)]));
      when(
        () => grade(any()),
      ).thenAnswer((_) async => Ok(_scheduled(SchedulePhase.review)));
    },
    build: () => ReviewSessionCubit(load, grade),
    act: (cubit) async {
      await cubit.start();
      cubit.reveal();
      await cubit.grade(ReviewGrade.good);
    },
    verify: (cubit) {
      expect(cubit.state.remaining, 1);
      expect(cubit.state.current?.id, 2);
      expect(
        cubit.state.isRevealed,
        isFalse,
        reason: 'next card starts hidden',
      );
      expect(cubit.state.reviewed, 1);
    },
  );

  blocTest<ReviewSessionCubit, ReviewSessionState>(
    'a card still learning comes back later in the same sitting',
    setUp: () {
      when(load.call).thenAnswer((_) async => Ok([_card(1), _card(2)]));
      when(
        () => grade(any()),
      ).thenAnswer((_) async => Ok(_scheduled(SchedulePhase.relearning)));
    },
    build: () => ReviewSessionCubit(load, grade),
    act: (cubit) async {
      await cubit.start();
      cubit.reveal();
      await cubit.grade(ReviewGrade.again);
    },
    verify: (cubit) {
      // Dropping it would mean never seeing the word you just failed.
      expect(cubit.state.remaining, 2);
      expect(cubit.state.current?.id, 2, reason: 'requeued behind the others');
      expect(cubit.state.queue.last.id, 1);
    },
  );

  blocTest<ReviewSessionCubit, ReviewSessionState>(
    'the requeued card carries its new schedule, not the stale one',
    setUp: () {
      when(load.call).thenAnswer((_) async => Ok([_card(1)]));
      when(
        () => grade(any()),
      ).thenAnswer((_) async => Ok(_scheduled(SchedulePhase.learning)));
    },
    build: () => ReviewSessionCubit(load, grade),
    act: (cubit) async {
      await cubit.start();
      cubit.reveal();
      await cubit.grade(ReviewGrade.again);
    },
    verify: (cubit) => expect(
      cubit.state.current?.schedule.phase,
      SchedulePhase.learning,
    ),
  );

  blocTest<ReviewSessionCubit, ReviewSessionState>(
    'the last card finishes the session',
    setUp: () {
      when(load.call).thenAnswer((_) async => Ok([_card(1)]));
      when(
        () => grade(any()),
      ).thenAnswer((_) async => Ok(_scheduled(SchedulePhase.review)));
    },
    build: () => ReviewSessionCubit(load, grade),
    act: (cubit) async {
      await cubit.start();
      cubit.reveal();
      await cubit.grade(ReviewGrade.good);
    },
    verify: (cubit) {
      expect(cubit.state.status, ReviewSessionStatus.finished);
      expect(cubit.state.reviewed, 1);
    },
  );

  test('a cloze prompt blanks the word out of its sentence', () {
    final card = _card(1, kind: CardKind.cloze);

    expect(card.prompt(), 'A ____ in a sentence.');
    expect(card.asksForProduction, isTrue);
  });

  test('a cloze card with no usable sentence falls back to the word', () {
    final card = ReviewCard(
      id: 1,
      kind: CardKind.cloze,
      schedule: CardSchedule(dueAt: _due),
      display: 'decision',
    );

    expect(card.prompt(), 'decision');
  });

  test('recognition shows the word, recall shows the meaning', () {
    expect(_card(1).prompt(), 'w1');
    expect(_card(1, kind: CardKind.recall).prompt(), 'nghĩa 1');
  });
}
