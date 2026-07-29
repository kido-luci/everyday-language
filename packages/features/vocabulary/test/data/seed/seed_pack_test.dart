// The packs themselves are gitignored, so the committed fixture is the only
// pack CI ever sees. It is what pins the format: if the parser drifts from
// what the generator writes, this is where it shows.

import 'dart:convert';
import 'dart:io';

import 'package:feature_vocabulary/src/data/seed/seed_pack.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> entry({
    Object? display = 'decision',
    Object? meaningEn = 'a choice you make',
    Object? collocation = 'make a decision',
    Object? sentence = 'It was a hard decision to make.',
  }) => <String, dynamic>{
    'display': display,
    'meaningEn': meaningEn,
    'collocation': collocation,
    'sentence': sentence,
  };

  Map<String, dynamic> pack({
    Object? schemaVersion = 1,
    Object? id = 'test-pack',
    Object? name = 'Test pack',
    List<Map<String, dynamic>>? entries,
  }) => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'id': id,
    'name': name,
    'entries': entries ?? [entry()],
  };

  group('the committed fixture', () {
    late SeedPack parsed;

    setUpAll(() async {
      final file = File('test/data/seed/fixtures/sample_pack.json');
      parsed = SeedPack.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, dynamic>,
      );
    });

    test('parses', () {
      expect(parsed.id, 'test-pack');
      expect(parsed.entries, hasLength(3));
      expect(parsed.generatedAt, DateTime.utc(2026, 6, 1, 9));
    });

    test('derives the lemma from the display, lowercased', () {
      final deadline = parsed.entries[1];
      expect(deadline.display, 'Deadline');
      expect(
        deadline.lemma,
        'deadline',
        reason:
            'the pack must not carry a key that can drift from the one '
            'the database deduplicates on',
      );
    });

    test('leaves absent optional fields null rather than empty', () {
      expect(parsed.entries[1].phonetic, isNull);
      expect(parsed.entries[1].meaningVi, isNull);
    });
  });

  group('rejects', () {
    test('a schema version it does not know', () {
      expect(
        () => SeedPack.fromJson(pack(schemaVersion: 2)),
        throwsA(isA<SeedPackFormatException>()),
      );
    });

    test('a pack with no entries', () {
      expect(
        () => SeedPack.fromJson(pack(entries: [])),
        throwsA(isA<SeedPackFormatException>()),
      );
    });

    test('a missing id', () {
      expect(
        () => SeedPack.fromJson(pack(id: null)),
        throwsA(isA<SeedPackFormatException>()),
      );
    });

    test('an entry missing a required field', () {
      for (final field in ['display', 'meaningEn', 'collocation', 'sentence']) {
        final broken = entry()..[field] = '  ';
        expect(
          () => SeedPack.fromJson(pack(entries: [broken])),
          throwsA(isA<SeedPackFormatException>()),
          reason: '$field is required',
        );
      }
    });

    test('a multi-word entry', () {
      expect(
        () => SeedPack.fromJson(
          pack(
            entries: [
              entry(display: 'make up', sentence: 'Do not make up excuses.'),
            ],
          ),
        ),
        throwsA(isA<SeedPackFormatException>()),
      );
    });

    test('two entries for the same word', () {
      // Left in, this fails the import transaction on every launch — a crash
      // loop rather than a bad word. Cheaper to name the word here.
      expect(
        () => SeedPack.fromJson(
          pack(
            entries: [
              entry(),
              entry(display: 'Decision'),
            ],
          ),
        ),
        throwsA(
          isA<SeedPackFormatException>().having(
            (e) => e.message,
            'message',
            contains('decision'),
          ),
        ),
      );
    });

    test('a sentence that does not contain the word', () {
      // The cloze card blanks this sentence out. One without the word in it
      // cannot serve as a prompt, and the failure would only surface in a
      // drill weeks later.
      expect(
        () => SeedPack.fromJson(
          pack(entries: [entry(sentence: 'It was a hard call to make.')]),
        ),
        throwsA(isA<SeedPackFormatException>()),
      );
    });
  });

  test('matches the word in the sentence regardless of case', () {
    // "Reckon we should leave" — sentence-initial capital, same word.
    final parsed = SeedPack.fromJson(
      pack(
        entries: [
          entry(display: 'reckon', sentence: 'Reckon we should leave now.'),
        ],
      ),
    );
    expect(parsed.entries.single.display, 'reckon');
  });

  test('names the entry that is wrong', () {
    expect(
      () => SeedPack.fromJson(pack(entries: [entry(), entry(display: null)])),
      throwsA(
        isA<SeedPackFormatException>().having(
          (e) => e.message,
          'message',
          contains('Entry 1'),
        ),
      ),
    );
  });
}
