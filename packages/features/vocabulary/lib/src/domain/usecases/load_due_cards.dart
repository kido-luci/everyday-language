import 'package:architecture/architecture.dart';
import 'package:injectable/injectable.dart';

import '../entities/review_card.dart';
import '../repositories/review_repository.dart';

/// The next batch of due cards: at most `param` of them, most overdue first.
@injectable
class LoadDueCards extends UseCase<int, List<ReviewCard>> {
  const LoadDueCards(this._repository);

  final ReviewRepository _repository;

  @override
  Future<Result<List<ReviewCard>>> call(int param) =>
      runResultGuarded(() => _repository.dueCards(limit: param));
}
