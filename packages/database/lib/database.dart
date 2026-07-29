/// Centralized Drift/SQLite persistence: table definitions, the generated
/// bindings, and the `AppDatabase` lifecycle wrapper.
///
/// Feature data layers receive `AppDatabase` through DI and own their own
/// queries; this package deliberately holds no business logic.
library;

export 'dart:convert' show jsonDecode, jsonEncode;

// The query surface feature data layers legitimately need, and no more.
// Exporting all of drift would drag `Column` and `Table` into scope and
// collide with Flutter's widgets of the same names; keeping the list explicit
// also keeps drift itself an implementation detail of this package rather
// than a dependency every feature declares.
export 'package:drift/drift.dart'
    show
        BaseAggregate,
        // `&` and `|` between two conditions, for a multi-column `where`.
        BooleanExpressionOperators,
        ComparableExpr,
        OrderingTerm,
        Value,
        Variable,
        countAll,
        innerJoin,
        leftOuterJoin;

export 'src/app_database.dart';
export 'src/enums.dart';
