import 'package:architecture/architecture.dart';
import 'package:injectable/injectable.dart';
import 'package:srs/srs.dart';

import '../entities/review_card.dart';
import '../repositories/review_repository.dart';

class GradeCardParams {
  const GradeCardParams({required this.card, required this.grade});

  final ReviewCard card;
  final ReviewGrade grade;
}

@injectable
class GradeCard extends UseCase<GradeCardParams, CardSchedule> {
  const GradeCard(this._repository);

  final ReviewRepository _repository;

  @override
  Future<Result<CardSchedule>> call(GradeCardParams param) =>
      runResultGuarded(() => _repository.grade(param.card, param.grade));
}
