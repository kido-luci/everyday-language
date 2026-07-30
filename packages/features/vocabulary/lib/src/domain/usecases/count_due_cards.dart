import 'package:architecture/architecture.dart';
import 'package:injectable/injectable.dart';

import '../repositories/review_repository.dart';

/// How many cards are due right now — all of them, not just this session's
/// share.
@injectable
class CountDueCards extends NoParamUseCase<int> {
  const CountDueCards(this._repository);

  final ReviewRepository _repository;

  @override
  Future<Result<int>> call([NoParams param = noParams]) =>
      runResultGuarded(_repository.dueCount);
}
