import 'package:architecture/architecture.dart';

/// The starter vocabulary a build ships with.
///
/// One method, and the linter would rather this were a function — but the
/// point of the interface is direction, not polymorphism: it is what lets the
/// use case above stay clear of the asset bundle and the database below it,
/// the same as every other repository in this feature.
// ignore: one_member_abstracts
abstract interface class SeedRepository {
  /// Imports the bundled content pack if there is one and it has not been
  /// imported before, and reports how many words it added.
  ///
  /// Zero is the ordinary answer: on every launch after the first, and on
  /// every launch of a build that shipped without a pack.
  Future<Result<int>> importBundledPack();
}
