import 'package:architecture/architecture.dart';
import 'package:injectable/injectable.dart';

import '../repositories/vocabulary_repository.dart';

@injectable
class DeleteWord extends UseCase<int, void> {
  const DeleteWord(this._repository);

  final VocabularyRepository _repository;

  @override
  Future<Result<void>> call(int param) =>
      runResultGuarded(() => _repository.deleteWord(param));
}
