// What arrives from a share sheet is whatever the learner had selected, and
// the guess this makes decides which field it lands in. Getting it wrong is
// not fatal — they can edit — but a wrong guess costs more than an empty
// field, so the rules are worth pinning.

import 'package:feature_vocabulary/src/domain/entities/shared_capture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a single word', () {
    test('becomes the word, with no sentence', () {
      final capture = SharedCapture.parse('decision');

      expect(capture.word, 'decision');
      expect(capture.sentence, isNull);
    });

    test('loses the punctuation it was selected with', () {
      // Double-tapping a word in a browser often takes the comma with it.
      for (final raw in [
        'decision,',
        '"decision"',
        '(decision)',
        'decision.',
      ]) {
        expect(SharedCapture.parse(raw).word, 'decision', reason: raw);
      }
    });

    test('keeps the punctuation that is part of it', () {
      expect(SharedCapture.parse('co-worker').word, 'co-worker');
      expect(SharedCapture.parse("don't").word, "don't");
    });

    test('keeps its case, so the display stays as it was met', () {
      expect(SharedCapture.parse('Decision').word, 'Decision');
    });

    test('survives an accented or non-Latin script', () {
      expect(SharedCapture.parse('«café»').word, 'café');
      expect(SharedCapture.parse('quyết').word, 'quyết');
    });
  });

  group('a longer selection', () {
    test('becomes the sentence, leaving the word to the learner', () {
      final capture = SharedCapture.parse('It was a hard decision to make.');

      expect(capture.sentence, 'It was a hard decision to make.');
      expect(
        capture.word,
        isNull,
        reason:
            'picking one word out of a phrase is the learner’s call, and '
            'guessing wrongly would break the form’s own rule that the '
            'sentence must contain the word',
      );
    });

    test('collapses the whitespace a copy brought with it', () {
      final capture = SharedCapture.parse('  It was\n\n a hard   decision. ');

      expect(capture.sentence, 'It was a hard decision.');
    });

    test('drops the page URL a browser appends', () {
      final capture = SharedCapture.parse(
        'It was a hard decision. https://example.com/article?x=1',
      );

      expect(capture.sentence, 'It was a hard decision.');
    });

    test('a share that is only a link yields nothing to capture', () {
      expect(
        SharedCapture.parse('https://example.com/article').isEmpty,
        isTrue,
      );
      expect(SharedCapture.parse('www.example.com').isEmpty, isTrue);
    });
  });

  group('a share far longer than a sentence', () {
    test('is cut at the end of its first sentence', () {
      final raw =
          'The committee reached a decision after four hours of argument. '
          '${'Then everyone went home and thought about it again. ' * 5}';

      final sentence = SharedCapture.parse(raw).sentence!;

      expect(
        sentence,
        'The committee reached a decision after four hours of argument.',
      );
    });

    test('is cut at a word boundary when it has no sentence end', () {
      final raw = 'word ' * 100;

      final sentence = SharedCapture.parse(raw).sentence!;

      expect(sentence.length, lessThanOrEqualTo(200));
      expect(sentence, isNot(endsWith('wor')), reason: 'never mid-word');
      expect(sentence.trim(), sentence);
    });
  });

  group('nothing worth capturing', () {
    test('an empty or blank share', () {
      expect(SharedCapture.parse('').isEmpty, isTrue);
      expect(SharedCapture.parse('   \n  ').isEmpty, isTrue);
    });

    test('punctuation on its own', () {
      expect(SharedCapture.parse('---').isEmpty, isTrue);
      expect(SharedCapture.parse('…').isEmpty, isTrue);
    });
  });
}
