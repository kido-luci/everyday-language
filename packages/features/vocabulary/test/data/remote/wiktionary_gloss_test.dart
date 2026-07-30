// Against real responses, kept in fixtures/ exactly as vi.wiktionary.org
// returned them. The extract is wiki prose, so the only honest test of a
// parser for it is the prose itself.
//
// Refresh a fixture with:
//   curl -A "EverydayLanguageDev/0.1 (…)" \
//     "https://vi.wiktionary.org/w/api.php?action=query&prop=extracts&explaintext=1&format=json&titles=<word>"

import 'dart:convert';
import 'dart:io';

import 'package:feature_vocabulary/src/data/remote/wiktionary_gloss.dart';
import 'package:flutter_test/flutter_test.dart';

String? extractOf(String word) {
  final file = File('test/data/remote/fixtures/$word.json');
  final body = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final query = body['query'] as Map<String, dynamic>;
  final pages = query['pages'] as Map<String, dynamic>;
  return (pages.values.first as Map<String, dynamic>)['extract'] as String?;
}

void main() {
  test('reads the first sense, the part of speech and the pronunciation', () {
    final gloss = parseVietnameseGloss(extractOf('errand')!);

    expect(gloss, isNotNull);
    expect(gloss!.meaningVi, 'Việc vặt (đưa thư, mua thuốc lá... ).');
    expect(gloss.partOfSpeech, 'Danh từ');
    expect(gloss.phonetic, '/ˈɛr.ənd/');
  });

  test('skips the line that just repeats the headword', () {
    // `decision  /dɪ.ˈsɪ.ʒən/` opens the noun section and is not a meaning.
    final gloss = parseVietnameseGloss(extractOf('decision')!);

    expect(gloss!.meaningVi, startsWith('Sự giải quyết'));
  });

  test('takes the English section, not whichever comes first', () {
    // `run` is also a Vietnamese word (to tremble), and its Vietnamese section
    // is the one that comes first in the page.
    final gloss = parseVietnameseGloss(extractOf('run')!);

    expect(gloss!.meaningVi, 'Sự chạy.');
    expect(
      gloss.meaningVi,
      isNot(contains('rung')),
      reason: 'that would be the Vietnamese entry',
    );
  });

  test('an example is not a sense', () {
    // Examples pair an English phrase with a translation across an em dash.
    final gloss = parseVietnameseGloss(extractOf('run')!);

    expect(gloss!.meaningVi, isNot(contains(' — ')));
  });

  test('a page with no English section yields nothing', () {
    const vietnameseOnly = '''
== Tiếng Việt ==

=== Động từ ===
run

Rung, lắc.
''';

    expect(parseVietnameseGloss(vietnameseOnly), isNull);
  });

  test('a section with a headword and no senses yields nothing', () {
    const headwordOnly = '''
== Tiếng Anh ==

=== Danh từ ===
widget  /ˈwɪdʒɪt/
''';

    expect(parseVietnameseGloss(headwordOnly), isNull);
  });

  test('a missing page has no extract at all', () {
    // What the API returns for a word it does not have: `"missing": ""` and no
    // extract. The caller treats that as a permanent answer, not a failure.
    expect(extractOf('gaslighting'), isNull);
  });
}
