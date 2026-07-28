import 'package:architecture/architecture.dart';
import 'package:injectable/injectable.dart';

import '../entities/word.dart';
import '../repositories/vocabulary_repository.dart';

@injectable
class ListWords extends NoParamUseCase<List<Word>> {
  const ListWords(this._repository);

  final VocabularyRepository _repository;

  @override
  Future<Result<List<Word>>> call([NoParams param = noParams]) =>
      runResultGuarded(_repository.listWords);
}
