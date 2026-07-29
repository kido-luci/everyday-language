// The case that matters here is the missing pack: packs are gitignored, so
// every build from a fresh clone — and every CI run — has none. That has to
// be a quiet null rather than an exception, or the app fails to start for
// anyone who did not generate one.

import 'dart:convert';

import 'package:feature_vocabulary/src/data/seed/seed_pack.dart';
import 'package:feature_vocabulary/src/data/seed/seed_pack_loader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const path = SeedPackLoader.assetPath;

  test('a build with no pack loads nothing, quietly', () async {
    final loader = SeedPackLoader.withBundle(_FakeBundle(const {}));

    expect(await loader.load(), isNull);
  });

  test('reads a pack that is there', () async {
    final loader = SeedPackLoader.withBundle(
      _FakeBundle({
        path: jsonEncode({
          'schemaVersion': 1,
          'id': 'everyday-v1',
          'name': 'Everyday starter',
          'entries': [
            {
              'display': 'decision',
              'meaningEn': 'a choice you make',
              'collocation': 'make a decision',
              'sentence': 'It was a hard decision to make.',
            },
          ],
        }),
      }),
    );

    final pack = await loader.load();

    expect(pack, isNotNull);
    expect(pack!.id, 'everyday-v1');
    expect(pack.entries.single.lemma, 'decision');
  });

  test(
    'a pack that is present but broken throws rather than vanishing',
    () async {
      final loader = SeedPackLoader.withBundle(_FakeBundle({path: 'not json'}));

      await expectLater(
        loader.load(),
        throwsA(isA<SeedPackFormatException>()),
        reason: 'a malformed pack is a build mistake, not an absent pack',
      );
    },
  );

  test('rejects a pack whose root is not an object', () async {
    final loader = SeedPackLoader.withBundle(_FakeBundle({path: '[]'}));

    await expectLater(loader.load(), throwsA(isA<SeedPackFormatException>()));
  });
}

/// Serves only the assets it was given, and reports anything else the way
/// `rootBundle` does — a `FlutterError`, which is what the loader keys off.
class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this._assets);

  final Map<String, String> _assets;

  @override
  Future<ByteData> load(String key) async {
    final value = _assets[key];
    if (value == null) throw FlutterError('Unable to load asset: $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(value)));
  }
}
