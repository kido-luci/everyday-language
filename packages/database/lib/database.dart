/// Centralized Drift persistence: entity types, AppDatabase, and Drift
/// primitives re-exported for convenience.
///
/// After `fst create --database drift` this package is renamed to `database`
/// and consumed as `package:database/database.dart`, mirroring the ObjectBox
/// package's public surface.
library;

export 'dart:convert' show jsonDecode, jsonEncode;

export 'package:drift/drift.dart' show OrderingTerm, Value;

export 'src/app_database.dart';
