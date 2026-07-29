import 'package:database/database.dart' show jsonDecode;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';

import 'seed_pack.dart';

/// Reads the bundled content pack, if the build has one.
///
/// Packs are gitignored and bundled at build time (see `content/README.md`),
/// so "there is no pack" is a normal state, not a failure — a fork building
/// from source gets an app with an empty dictionary. [load] returns null for
/// that case and throws only when a pack exists but cannot be read, which is
/// a real problem worth surfacing.
@lazySingleton
class SeedPackLoader {
  SeedPackLoader() : _bundle = rootBundle;

  @visibleForTesting
  SeedPackLoader.withBundle(this._bundle);

  final AssetBundle _bundle;

  /// The pack this build looks for.
  ///
  /// One pack, one path. If a second ever ships, this becomes a lookup over
  /// the asset manifest rather than a longer list of constants.
  static const String assetPath = 'content/everyday-v1.json';

  /// The pack, or null when the build shipped without one.
  ///
  /// Throws [SeedPackFormatException] if a pack is present but malformed.
  Future<SeedPack?> load() async {
    final String raw;
    try {
      raw = await _bundle.loadString(assetPath);
      // A missing asset is the one thing an AssetBundle reports as a
      // FlutterError, and there is no ask-first API on the bundle itself —
      // so catching it is the only way to tell "no pack" from a real fault.
      // ignore: avoid_catching_errors
    } on FlutterError {
      return null;
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      throw SeedPackFormatException(
        '$assetPath is not valid JSON: ${e.message}',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const SeedPackFormatException('Pack root is not an object');
    }
    return SeedPack.fromJson(decoded);
  }
}
