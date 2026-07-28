// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i687;

import 'package:database/database.dart' as _i252;
import 'package:feature_vocabulary/src/data/local/vocabulary_local_data_source.dart'
    as _i566;
import 'package:feature_vocabulary/src/data/repositories/vocabulary_repository_impl.dart'
    as _i669;
import 'package:feature_vocabulary/src/di.dart' as _i41;
import 'package:feature_vocabulary/src/domain/repositories/vocabulary_repository.dart'
    as _i644;
import 'package:feature_vocabulary/src/domain/usecases/add_word.dart' as _i967;
import 'package:feature_vocabulary/src/domain/usecases/delete_word.dart'
    as _i314;
import 'package:feature_vocabulary/src/domain/usecases/get_word.dart' as _i985;
import 'package:feature_vocabulary/src/domain/usecases/list_words.dart'
    as _i1044;
import 'package:feature_vocabulary/src/presentation/bloc/add_word/add_word_cubit.dart'
    as _i330;
import 'package:feature_vocabulary/src/presentation/bloc/word_detail/word_detail_cubit.dart'
    as _i122;
import 'package:feature_vocabulary/src/presentation/bloc/words_list/words_list_bloc.dart'
    as _i980;
import 'package:injectable/injectable.dart' as _i526;
import 'package:srs/srs.dart' as _i902;

class FeatureVocabularyPackageModule extends _i526.MicroPackageModule {
  // initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    final vocabularyExternalModule = _$VocabularyExternalModule();
    gh.lazySingleton<_i902.SrsScheduler>(
      () => vocabularyExternalModule.provideScheduler(),
    );
    gh.lazySingleton<_i566.VocabularyLocalDataSource>(
      () => _i566.VocabularyLocalDataSource(
        gh<_i252.AppDatabase>(),
        gh<_i902.SrsScheduler>(),
      ),
    );
    gh.lazySingleton<_i644.VocabularyRepository>(
      () =>
          _i669.VocabularyRepositoryImpl(gh<_i566.VocabularyLocalDataSource>()),
    );
    gh.factory<_i967.AddWord>(
      () => _i967.AddWord(gh<_i644.VocabularyRepository>()),
    );
    gh.factory<_i314.DeleteWord>(
      () => _i314.DeleteWord(gh<_i644.VocabularyRepository>()),
    );
    gh.factory<_i985.GetWord>(
      () => _i985.GetWord(gh<_i644.VocabularyRepository>()),
    );
    gh.factory<_i1044.ListWords>(
      () => _i1044.ListWords(gh<_i644.VocabularyRepository>()),
    );
    gh.factory<_i980.WordsListBloc>(
      () => _i980.WordsListBloc(
        gh<_i1044.ListWords>(),
        gh<_i314.DeleteWord>(),
      ),
    );
    gh.factory<_i122.WordDetailCubit>(
      () => _i122.WordDetailCubit(gh<_i985.GetWord>()),
    );
    gh.factory<_i330.AddWordCubit>(
      () => _i330.AddWordCubit(gh<_i967.AddWord>()),
    );
  }
}

class _$VocabularyExternalModule extends _i41.VocabularyExternalModule {}
