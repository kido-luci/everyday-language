import 'package:architecture/architecture.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:database/database.dart' show CardKind;
import 'package:feature_vocabulary/feature_vocabulary.dart';
import 'package:feature_vocabulary/src/domain/usecases/count_due_cards.dart';
import 'package:feature_vocabulary/src/domain/usecases/grade_card.dart';
import 'package:feature_vocabulary/src/domain/usecases/load_due_cards.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:srs/srs.dart';
import 'package:storage/storage.dart';

class _MockLoad extends Mock implements LoadDueCards {}

class _MockCount extends Mock implements CountDueCards {}

class _MockGrade extends Mock implements GradeCard {}

class _MockDailyGoal extends Mock implements DailyGoalStore {}

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
  late _MockCount count;
  late _MockGrade grade;
  late _MockDailyGoal goal;

  setUpAll(() => registerFallbackValue(_FakeParams()));

  setUp(() {
    load = _MockLoad();
    count = _MockCount();
    grade = _MockGrade();
    goal = _MockDailyGoal();

    when(goal.read).thenReturn(20);
    // Nothing left over unless a test says otherwise.
    when(count.call).thenAnswer((_) async => const Ok(0));
  });

  blocTest<ReviewSessionCubit, ReviewSessionState>(
    'an empty queue finishes the session rather than showing a blank card',
    setUp: () => when(() => load(any())).thenAnswer((_) async => const Ok([])),
    build: () => ReviewSessionCubit(load, count, grade, goal),
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
      when(() => load(any())).thenAnswer((_) async => Ok([_card(1)]));
    },
    build: () => ReviewSessionCubit(load, count, grade, goal),
    act: (cubit) async {
      await cubit.start();
      await cubit.grade(ReviewGrade.easy);
    },
    verify: (_) => verifyNever(() => grade(any())),
  );

  blocTest<ReviewSessionCubit, ReviewSessionState>(
    'a graduated card leaves the queue',
    setUp: () {
      when(() => load(any())).thenAnswer((_) async => Ok([_card(1), _card(2)]));
      when(
        () => grade(any()),
      ).thenAnswer((_) async => Ok(_scheduled(SchedulePhase.review)));
    },
    build: () => ReviewSessionCubit(load, count, grade, goal),
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
      when(() => load(any())).thenAnswer((_) async => Ok([_card(1), _card(2)]));
      when(
        () => grade(any()),
      ).thenAnswer((_) async => Ok(_scheduled(SchedulePhase.relearning)));
    },
    build: () => ReviewSessionCubit(load, count, grade, goal),
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
      when(() => load(any())).thenAnswer((_) async => Ok([_card(1)]));
      when(
        () => grade(any()),
      ).thenAnswer((_) async => Ok(_scheduled(SchedulePhase.learning)));
    },
    build: () => ReviewSessionCubit(load, count, grade, goal),
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
      when(() => load(any())).thenAnswer((_) async => Ok([_card(1)]));
      when(
        () => grade(any()),
      ).thenAnswer((_) async => Ok(_scheduled(SchedulePhase.review)));
    },
    build: () => ReviewSessionCubit(load, count, grade, goal),
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

  group('a sitting is the daily goal, and says what it left behind', () {
    blocTest<ReviewSessionCubit, ReviewSessionState>(
      'asks for exactly the goal, not the whole queue',
      setUp: () {
        when(goal.read).thenReturn(20);
        when(() => load(any())).thenAnswer((_) async => Ok([_card(1)]));
      },
      build: () => ReviewSessionCubit(load, count, grade, goal),
      act: (cubit) => cubit.start(),
      verify: (cubit) {
        verify(() => load(20)).called(1);
        expect(cubit.state.sessionSize, 20);
      },
    );

    blocTest<ReviewSessionCubit, ReviewSessionState>(
      'finishing with cards left over reports how many',
      setUp: () {
        when(() => load(any())).thenAnswer((_) async => Ok([_card(1)]));
        when(
          () => grade(any()),
        ).thenAnswer((_) async => Ok(_scheduled(SchedulePhase.review)));
        // 160 still waiting: the sitting cleared its share, not the queue.
        when(count.call).thenAnswer((_) async => const Ok(160));
      },
      build: () => ReviewSessionCubit(load, count, grade, goal),
      act: (cubit) async {
        await cubit.start();
        cubit.reveal();
        await cubit.grade(ReviewGrade.good);
      },
      verify: (cubit) {
        expect(cubit.state.status, ReviewSessionStatus.finished);
        expect(cubit.state.dueAfter, 160);
        expect(cubit.state.hasMoreDue, isTrue);
        expect(
          cubit.state.nextSessionSize,
          20,
          reason: 'the next sitting is another goal-sized batch',
        );
      },
    );

    blocTest<ReviewSessionCubit, ReviewSessionState>(
      'clearing the queue reports nothing left',
      setUp: () {
        when(() => load(any())).thenAnswer((_) async => Ok([_card(1)]));
        when(
          () => grade(any()),
        ).thenAnswer((_) async => Ok(_scheduled(SchedulePhase.review)));
        when(count.call).thenAnswer((_) async => const Ok(0));
      },
      build: () => ReviewSessionCubit(load, count, grade, goal),
      act: (cubit) async {
        await cubit.start();
        cubit.reveal();
        await cubit.grade(ReviewGrade.good);
      },
      verify: (cubit) => expect(cubit.state.hasMoreDue, isFalse),
    );

    blocTest<ReviewSessionCubit, ReviewSessionState>(
      'an empty queue counts what is due before calling it a day',
      setUp: () =>
          when(() => load(any())).thenAnswer((_) async => const Ok([])),
      build: () => ReviewSessionCubit(load, count, grade, goal),
      act: (cubit) => cubit.start(),
      verify: (cubit) {
        expect(cubit.state.status, ReviewSessionStatus.finished);
        expect(cubit.state.hasMoreDue, isFalse);
      },
    );

    blocTest<ReviewSessionCubit, ReviewSessionState>(
      'carrying on loads another batch',
      setUp: () {
        when(() => load(any())).thenAnswer((_) async => Ok([_card(1)]));
        when(
          () => grade(any()),
        ).thenAnswer((_) async => Ok(_scheduled(SchedulePhase.review)));
        when(count.call).thenAnswer((_) async => const Ok(5));
      },
      build: () => ReviewSessionCubit(load, count, grade, goal),
      act: (cubit) async {
        await cubit.start();
        cubit.reveal();
        await cubit.grade(ReviewGrade.good);
        // What the "review N more" button does.
        await cubit.start();
      },
      verify: (cubit) {
        verify(() => load(20)).called(2);
        expect(cubit.state.status, ReviewSessionStatus.reviewing);
        expect(
          cubit.state.reviewed,
          0,
          reason: 'a fresh sitting counts from zero',
        );
      },
    );

    test('the offer never promises more than is actually left', () {
      const state = ReviewSessionState(
        status: ReviewSessionStatus.finished,
        sessionSize: 20,
        dueAfter: 3,
      );

      expect(state.nextSessionSize, 3);
    });
  });

  _typedDrillTests();

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

void _typedDrillTests() {
  late _MockLoad load;
  late _MockCount count;
  late _MockGrade grade;
  late _MockDailyGoal goal;

  ReviewCard cloze(int id) => _card(id, kind: CardKind.cloze);

  setUp(() {
    load = _MockLoad();
    count = _MockCount();
    grade = _MockGrade();
    goal = _MockDailyGoal();
    when(goal.read).thenReturn(20);
    when(count.call).thenAnswer((_) async => const Ok(0));
    when(() => load(any())).thenAnswer((_) async => Ok([cloze(1)]));
    when(
      () => grade(any()),
    ).thenAnswer((_) async => Ok(_scheduled(SchedulePhase.review)));
  });

  group('answer checking', () {
    test('ignores surrounding space, case and doubled spaces', () {
      final card = cloze(1); // display: 'w1'

      expect(card.accepts('  W1 '), isTrue);
      expect(card.accepts('w1'), isTrue);
    });

    test('rejects a misspelling', () {
      // Accepting near-misses would report a success the learner did not have,
      // and the scheduler would space the card as though they knew it.
      expect(cloze(1).accepts('w2'), isFalse);
      expect(cloze(1).accepts(''), isFalse);
    });
  });

  blocTest<ReviewSessionCubit, ReviewSessionState>(
    'a typing drill offers no way to reveal without answering',
    build: () => ReviewSessionCubit(load, count, grade, goal),
    act: (cubit) async {
      await cubit.start();
      cubit.reveal();
    },
    verify: (cubit) => expect(
      cubit.state.isRevealed,
      isFalse,
      reason: 'revealing would skip the retrieval the card exists for',
    ),
  );

  blocTest<ReviewSessionCubit, ReviewSessionState>(
    'an empty answer cannot be submitted',
    build: () => ReviewSessionCubit(load, count, grade, goal),
    act: (cubit) async {
      await cubit.start();
      cubit.answerChanged('   ');
      cubit.submitAnswer();
    },
    verify: (cubit) {
      expect(cubit.state.canSubmitAnswer, isFalse);
      expect(cubit.state.isRevealed, isFalse);
    },
  );

  blocTest<ReviewSessionCubit, ReviewSessionState>(
    'a correct answer reveals the card and records the verdict',
    build: () => ReviewSessionCubit(load, count, grade, goal),
    act: (cubit) async {
      await cubit.start();
      cubit.answerChanged('W1');
      cubit.submitAnswer();
    },
    verify: (cubit) {
      expect(cubit.state.isRevealed, isTrue);
      expect(cubit.state.wasCorrect, isTrue);
    },
  );

  blocTest<ReviewSessionCubit, ReviewSessionState>(
    'a wrong answer still reveals the word rather than moving on',
    build: () => ReviewSessionCubit(load, count, grade, goal),
    act: (cubit) async {
      await cubit.start();
      cubit.answerChanged('wrong');
      cubit.submitAnswer();
    },
    verify: (cubit) {
      // Being told you were wrong and moving on teaches nothing.
      expect(cubit.state.isRevealed, isTrue);
      expect(cubit.state.wasCorrect, isFalse);
      verifyNever(() => grade(any()));
    },
  );

  blocTest<ReviewSessionCubit, ReviewSessionState>(
    'submitting does not grade — that is a separate step',
    build: () => ReviewSessionCubit(load, count, grade, goal),
    act: (cubit) async {
      await cubit.start();
      cubit.answerChanged('w1');
      cubit.submitAnswer();
    },
    verify: (_) => verifyNever(() => grade(any())),
  );

  blocTest<ReviewSessionCubit, ReviewSessionState>(
    'after a wrong answer only "again" is accepted',
    build: () => ReviewSessionCubit(load, count, grade, goal),
    act: (cubit) async {
      await cubit.start();
      cubit.answerChanged('wrong');
      cubit.submitAnswer();
      await cubit.grade(ReviewGrade.easy);
    },
    verify: (_) => verifyNever(() => grade(any())),
  );

  blocTest<ReviewSessionCubit, ReviewSessionState>(
    'after a wrong answer "again" goes through',
    build: () => ReviewSessionCubit(load, count, grade, goal),
    act: (cubit) async {
      await cubit.start();
      cubit.answerChanged('wrong');
      cubit.submitAnswer();
      await cubit.grade(ReviewGrade.again);
    },
    verify: (_) => verify(() => grade(any())).called(1),
  );

  blocTest<ReviewSessionCubit, ReviewSessionState>(
    'the typed answer is cleared before the next card',
    setUp: () => when(() => load(any())).thenAnswer(
      (_) async => Ok([cloze(1), cloze(2)]),
    ),
    build: () => ReviewSessionCubit(load, count, grade, goal),
    act: (cubit) async {
      await cubit.start();
      cubit.answerChanged('w1');
      cubit.submitAnswer();
      await cubit.grade(ReviewGrade.good);
    },
    verify: (cubit) {
      // Otherwise the next card opens pre-filled with the previous answer.
      expect(cubit.state.typed, isEmpty);
      expect(cubit.state.wasCorrect, isNull);
      expect(cubit.state.current?.id, 2);
    },
  );

  blocTest<ReviewSessionCubit, ReviewSessionState>(
    'a recognition card still reveals and takes any grade',
    setUp: () =>
        when(() => load(any())).thenAnswer((_) async => Ok([_card(1)])),
    build: () => ReviewSessionCubit(load, count, grade, goal),
    act: (cubit) async {
      await cubit.start();
      cubit.reveal();
      await cubit.grade(ReviewGrade.easy);
    },
    verify: (cubit) {
      expect(cubit.state.reviewed, 1);
      verify(() => grade(any())).called(1);
    },
  );

  test('a production card with nothing to prompt with is not a drill', () {
    // No meaning and no usable sentence: the prompt falls back to the word, so
    // asking the learner to type it would be asking them to copy it.
    final card = ReviewCard(
      id: 1,
      kind: CardKind.recall,
      schedule: CardSchedule(dueAt: _due),
      display: 'decision',
    );

    expect(card.asksForProduction, isFalse);
  });
}
