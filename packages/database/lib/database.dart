/// Centralized Drift/SQLite persistence: table definitions, the generated
/// bindings, and the `AppDatabase` lifecycle wrapper.
///
/// Feature data layers receive `AppDatabase` through DI and own their own
/// queries; this package deliberately holds no business logic.
library;

export 'dart:convert' show jsonDecode, jsonEncode;

export 'package:drift/drift.dart' show OrderingTerm, Value;

export 'src/app_database.dart';
export 'src/enums.dart';
