import 'package:drift/drift.dart';

import '../enums.dart';

/// Where a word was captured — the article, the app, the photo.
///
/// Kept as its own row rather than columns on the example because one page
/// usually yields several words, and because "show me everything I picked up
/// from this article" is a view worth having later.
@DataClassName('CaptureSourceRow')
class CaptureSources extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get kind => textEnum<CaptureKind>()();

  /// Human-readable origin: a page title, an app name.
  TextColumn get label => text().nullable()();

  /// The URL or deep link, when there is one.
  TextColumn get uri => text().nullable()();

  IntColumn get createdAtUs => integer()();
}
