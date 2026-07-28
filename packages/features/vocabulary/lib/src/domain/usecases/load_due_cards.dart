import 'package:architecture/architecture.dart';
import 'package:injectable/injectable.dart';

import '../entities/review_card.dart';
import '../repositories/review_repository.dart';

@injectable
class LoadDueCards extends NoParamUseCase<List<ReviewCard>> {
  const LoadDueCards(this._repository);

  final ReviewRepository _repository;

  @override
  Future<Result<List<ReviewCard>>> call([NoParams param = noParams]) =>
      runResultGuarded(_repository.dueCards);
}
