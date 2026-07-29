import 'package:architecture/architecture.dart';
import 'package:injectable/injectable.dart';

import '../repositories/seed_repository.dart';

/// Puts the bundled starter words in place before the first screen.
///
/// Safe to call on every launch: the repository imports at most once per pack
/// and answers zero thereafter.
@injectable
class ImportSeedPack extends NoParamUseCase<int> {
  const ImportSeedPack(this._repository);

  final SeedRepository _repository;

  @override
  Future<Result<int>> call([NoParams param = noParams]) =>
      runResultGuarded(_repository.importBundledPack);
}
