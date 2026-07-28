import 'package:architecture/architecture.dart';
import 'package:injectable/injectable.dart';

import '../entities/word.dart';
import '../repositories/vocabulary_repository.dart';

@injectable
class GetWord extends UseCase<int, Word> {
  const GetWord(this._repository);

  final VocabularyRepository _repository;

  @override
  Future<Result<Word>> call(int param) =>
      runResultGuarded(() => _repository.getWord(param));
}
