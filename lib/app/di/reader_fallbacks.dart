import 'package:architecture/architecture.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_contracts/shared_contracts.dart';

/// Registers Null-Object readers for the cross-feature data sources that a
/// feature normally provides.
///
/// The home dashboard reads the learner's study figures through the
/// `shared_contracts` reader interface; the vocabulary feature owns the
/// implementation. When `fst create --exclude-feature` drops that feature,
/// this fallback keeps home resolving — and showing an honest zero — instead
/// of failing to build its bloc. It registers only if the owning feature
/// didn't, so the real reader always wins.
void registerReaderFallbacks(GetIt getIt) {
  if (!getIt.isRegistered<StudyStatsReader>()) {
    getIt.registerLazySingleton<StudyStatsReader>(NoOpStudyStatsReader.new);
  }
}

/// A [StudyStatsReader] for a build with no vocabulary feature: nothing
/// studied, nothing due.
class NoOpStudyStatsReader extends StudyStatsReader {
  const NoOpStudyStatsReader();

  @override
  Future<Result<StudyStats>> call([NoParams param = noParams]) async =>
      const Ok(StudyStats());
}
