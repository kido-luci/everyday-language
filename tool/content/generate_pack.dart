#!/usr/bin/env dart
// Generates a vocabulary content pack with Claude.
//
// Packs live outside this repository (see content/README.md); this script is
// how one is made. Run it from the repository root:
//
//     dart run tool/content/generate_pack.dart --count 60
//
// Raw HTTP rather than an SDK because Anthropic publishes no official Dart
// SDK, and `dart:io` keeps this a zero-dependency build-time script.
//
// Resumable and additive: point it at an existing pack and it tops it up to
// --count, never repeating a word already in the file. That is the intended
// way to grow a pack — generate a small batch, read it, then raise --count.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _model = 'claude-opus-5';
const _apiUrl = 'https://api.anthropic.com/v1/messages';
const _anthropicVersion = '2023-06-01';

/// Topics the pack should spread across, weighted towards the situations the
/// app is for: using English, not sitting an exam.
const _topics = <String>[
  'work, meetings and email',
  'everyday conversation and small talk',
  'travel and getting around',
  'food, cooking and eating out',
  'health, the body and feeling unwell',
  'money, shopping and bills',
  'feelings, opinions and disagreement',
  'home, chores and daily routine',
];

const _systemPrompt = '''
You write vocabulary entries for Everyday Language, an app for learners who
want English they will actually use — not exam preparation.

Choose words a learner meets in ordinary life and would be glad to have ready:
common, useful, and worth the effort of memorising. Skip anything rare,
archaic, technical, or so basic that an intermediate learner already owns it
("water", "happy"). Prefer the word that unlocks a situation over the word
that scores a point.

Every entry is one word — no phrases, no spaces, no hyphenated compounds.

For each entry:
- display: the word in its dictionary form, lower case unless it is a proper
  noun.
- phonetic: IPA in slashes, e.g. /dɪˈsɪʒn/. Use the General American reading.
- partOfSpeech: one of noun, verb, adjective, adverb, preposition,
  conjunction.
- meaningEn: one plain-English clause. No "the state of being" padding, no
  restating the word inside its own definition.
- meaningVi: the Vietnamese equivalent, as a Vietnamese learner would write it
  in their own notebook — one to four words, not a translated definition.
- collocation: the two or three words this word most naturally travels with,
  written as they appear together ("make a decision", "deeply regret"). This
  is the field that teaches use rather than recognition, so choose the pairing
  a native speaker would actually produce.
- sentence: one natural sentence, 8 to 16 words, that a person might really
  say or write. It MUST contain the word exactly as spelled in display. Make
  the sentence carry the meaning — a learner who only reads the sentence
  should be able to guess what the word means. No dictionary-example
  stiffness, no "The X was very Y."
''';

Future<void> main(List<String> args) async {
  final options = _Options.parse(args);
  if (options == null) {
    stderr.writeln(_usage);
    exit(64);
  }

  final auth = await _resolveAuth();
  if (auth == null) {
    stderr.writeln(
      'No Anthropic credentials found.\n'
      'Set ANTHROPIC_API_KEY, or run `ant auth login` and try again.',
    );
    exit(1);
  }

  final file = File(options.outputPath);
  final entries = await _readExisting(file);
  if (entries.isNotEmpty) {
    stdout.writeln('Resuming ${options.outputPath}: ${entries.length} entries');
  }

  final client = HttpClient();
  var emptyRounds = 0;
  try {
    while (entries.length < options.count) {
      final want = (options.count - entries.length).clamp(1, options.batch);
      stdout.writeln(
        'Requesting $want more (${entries.length}/${options.count})...',
      );

      final batch = await _requestBatch(
        client,
        auth: auth,
        count: want,
        exclude: entries.map((e) => e['display']! as String).toList(),
        topic: _topics[entries.length ~/ options.batch % _topics.length],
      );

      final fresh = _accept(batch, into: entries);
      if (fresh == 0) {
        // Either everything came back a duplicate or everything failed
        // validation. One more round is worth trying; a second means the
        // model has run out of room under these constraints.
        if (++emptyRounds >= 2) {
          stderr.writeln('No usable new entries in two rounds — stopping.');
          break;
        }
      } else {
        emptyRounds = 0;
      }

      await _write(file, options, entries);
    }
  } finally {
    client.close();
  }

  await _write(file, options, entries);
  stdout.writeln('Wrote ${entries.length} entries to ${options.outputPath}');
}

/// Validates a batch and appends what survives. Returns how many were added.
int _accept(
  List<Map<String, dynamic>> batch, {
  required List<Map<String, dynamic>> into,
}) {
  final seen = {
    for (final e in into) (e['display']! as String).toLowerCase(),
  };

  var added = 0;
  for (final entry in batch) {
    final problem = _validate(entry);
    if (problem != null) {
      stderr.writeln('  skipped ${entry['display']}: $problem');
      continue;
    }
    final lemma = (entry['display']! as String).toLowerCase();
    if (!seen.add(lemma)) continue;
    into.add(entry);
    added++;
  }
  return added;
}

/// Mirrors what `SeedEntry.fromJson` enforces, so a pack that reaches the app
/// cannot fail to parse there. Returns null when the entry is fine.
String? _validate(Map<String, dynamic> entry) {
  const required = [
    'display',
    'meaningEn',
    'collocation',
    'sentence',
  ];
  for (final key in required) {
    final value = entry[key];
    if (value is! String || value.trim().isEmpty) return 'missing $key';
  }

  final display = (entry['display']! as String).trim();
  if (display.contains(RegExp(r'\s'))) return 'not one word';

  final sentence = (entry['sentence']! as String).trim();
  if (!sentence.toLowerCase().contains(display.toLowerCase())) {
    return 'sentence does not contain the word';
  }
  return null;
}

/// One request to the API, returning the entries it produced.
Future<List<Map<String, dynamic>>> _requestBatch(
  HttpClient client, {
  required _Auth auth,
  required int count,
  required List<String> exclude,
  required String topic,
}) async {
  final body = <String, dynamic>{
    'model': _model,
    'max_tokens': 16000,
    'stream': true,
    'thinking': {'type': 'adaptive'},
    'output_config': {
      'effort': 'high',
      'format': {'type': 'json_schema', 'schema': _responseSchema},
    },
    'system': _systemPrompt,
    'messages': [
      {
        'role': 'user',
        'content':
            'Write $count entries, leaning towards $topic.\n\n'
            'Do not use any of these words, which the pack already has:\n'
            '${exclude.isEmpty ? '(none yet)' : exclude.join(', ')}',
      },
    ],
  };

  final request = await client.postUrl(Uri.parse(_apiUrl));
  request.headers
    ..set(HttpHeaders.contentTypeHeader, 'application/json')
    ..set('anthropic-version', _anthropicVersion);
  auth.apply(request.headers);
  request.add(utf8.encode(jsonEncode(body)));

  final response = await request.close();
  if (response.statusCode != HttpStatus.ok) {
    final error = await response.transform(utf8.decoder).join();
    throw HttpException('HTTP ${response.statusCode}: $error');
  }

  final text = await _readTextFromStream(response);
  final decoded = jsonDecode(text);
  if (decoded is! Map<String, dynamic> || decoded['entries'] is! List) {
    throw const FormatException('Response did not match the schema');
  }
  return [
    for (final e in decoded['entries']! as List)
      if (e is Map<String, dynamic>) e,
  ];
}

/// Accumulates the assistant's text from the SSE stream.
///
/// Only `text_delta` is collected: with adaptive thinking on, the stream also
/// carries `thinking_delta` events, and folding those into the buffer would
/// produce reasoning where JSON is expected.
Future<String> _readTextFromStream(HttpClientResponse response) async {
  final text = StringBuffer();
  String? stopReason;

  final lines = response
      .transform(utf8.decoder)
      .transform(const LineSplitter());

  await for (final line in lines) {
    if (!line.startsWith('data:')) continue;
    final payload = line.substring(5).trim();
    if (payload.isEmpty) continue;

    final event = jsonDecode(payload);
    if (event is! Map<String, dynamic>) continue;

    switch (event['type']) {
      case 'content_block_delta':
        final delta = event['delta'];
        if (delta is Map<String, dynamic> && delta['type'] == 'text_delta') {
          text.write(delta['text'] as String? ?? '');
        }
      case 'message_delta':
        final delta = event['delta'];
        if (delta is Map<String, dynamic>) {
          stopReason = delta['stop_reason'] as String? ?? stopReason;
        }
      case 'error':
        throw HttpException('Stream error: ${jsonEncode(event['error'])}');
    }
  }

  switch (stopReason) {
    case 'refusal':
      throw const HttpException('The model declined this request');
    case 'max_tokens':
      throw const HttpException(
        'Hit max_tokens mid-answer — lower --batch and retry',
      );
  }
  return text.toString();
}

/// Structured-output schema. Keep in step with `SeedEntry` on the app side.
const _responseSchema = <String, dynamic>{
  'type': 'object',
  'properties': {
    'entries': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'display': {'type': 'string'},
          'phonetic': {'type': 'string'},
          'partOfSpeech': {'type': 'string'},
          'meaningEn': {'type': 'string'},
          'meaningVi': {'type': 'string'},
          'collocation': {'type': 'string'},
          'sentence': {'type': 'string'},
        },
        'required': [
          'display',
          'phonetic',
          'partOfSpeech',
          'meaningEn',
          'meaningVi',
          'collocation',
          'sentence',
        ],
        'additionalProperties': false,
      },
    },
  },
  'required': ['entries'],
  'additionalProperties': false,
};

Future<List<Map<String, dynamic>>> _readExisting(File file) async {
  if (!file.existsSync()) return [];
  final decoded = jsonDecode(await file.readAsString());
  if (decoded is! Map<String, dynamic> || decoded['entries'] is! List) {
    throw const FormatException('Existing pack is not readable — move it away');
  }
  return [
    for (final e in decoded['entries']! as List)
      if (e is Map<String, dynamic>) e,
  ];
}

Future<void> _write(
  File file,
  _Options options,
  List<Map<String, dynamic>> entries,
) async {
  await file.parent.create(recursive: true);
  await file.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': 1,
      'id': options.id,
      'name': options.name,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'entries': entries,
    })}\n',
  );
}

/// How to authenticate: an API key, or an OAuth token from `ant auth login`.
class _Auth {
  const _Auth.apiKey(this._value) : _isOAuth = false;
  const _Auth.oauth(this._value) : _isOAuth = true;

  final String _value;
  final bool _isOAuth;

  void apply(HttpHeaders headers) {
    if (_isOAuth) {
      headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $_value')
        ..set('anthropic-beta', 'oauth-2025-04-20');
    } else {
      headers.set('x-api-key', _value);
    }
  }
}

/// Prefers an exported key; falls back to the `ant` CLI's stored profile so a
/// machine set up with `ant auth login` needs no extra configuration.
Future<_Auth?> _resolveAuth() async {
  final key = Platform.environment['ANTHROPIC_API_KEY'];
  if (key != null && key.isNotEmpty) return _Auth.apiKey(key);

  try {
    final result = await Process.run('ant', [
      'auth',
      'print-credentials',
      '--access-token',
    ]);
    final token = (result.stdout as String).trim();
    if (result.exitCode == 0 && token.isNotEmpty) return _Auth.oauth(token);
  } on ProcessException {
    // `ant` is not installed; fall through to the "no credentials" message.
  }
  return null;
}

class _Options {
  const _Options({
    required this.count,
    required this.batch,
    required this.id,
    required this.name,
    required this.outputPath,
  });

  final int count;
  final int batch;
  final String id;
  final String name;
  final String outputPath;

  static _Options? parse(List<String> args) {
    var count = 60;
    var batch = 20;
    var id = 'everyday-v1';
    var name = 'Everyday starter';
    String? out;

    for (var i = 0; i < args.length; i += 2) {
      if (i + 1 >= args.length) return null;
      final value = args[i + 1];
      switch (args[i]) {
        case '--count':
          count = int.tryParse(value) ?? -1;
        case '--batch':
          batch = int.tryParse(value) ?? -1;
        case '--id':
          id = value;
        case '--name':
          name = value;
        case '--out':
          out = value;
        default:
          return null;
      }
    }

    if (count < 1 || batch < 1 || id.isEmpty) return null;
    return _Options(
      count: count,
      batch: batch,
      id: id,
      name: name,
      outputPath: out ?? 'content/$id.json',
    );
  }
}

const _usage = '''
Usage: dart run tool/content/generate_pack.dart [options]

  --count N   How many entries the pack should end up with (default 60)
  --batch N   How many to request per API call (default 20)
  --id S      Pack id, also the output filename (default everyday-v1)
  --name S    Deck name shown to the learner (default "Everyday starter")
  --out PATH  Where to write (default content/<id>.json)

The app loads content/everyday-v1.json; a pack written under another id will
not be picked up without changing SeedPackLoader.assetPath.
''';
