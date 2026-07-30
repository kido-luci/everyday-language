/// Vocabulary feature: the words the learner collects, and the cards built
/// from them.
///
/// The host app wires `FeatureVocabularyPackageModule` via
/// `externalPackageModulesBefore` and mounts the exported screens in its
/// router, the same way it mounts home and profile. View models are
/// exported so the app's tests can reference them.
///
/// `ImportSeedPack` is the one use case exported: seeding happens during
/// bootstrap, before any of these screens exist, so the app shell has to run
/// it rather than a widget.
library;

export 'src/data/remote/wiktionary_client.dart'
    show registerWiktionaryAttribution;
export 'src/di.module.dart' show FeatureVocabularyPackageModule;
export 'src/domain/entities/review_card.dart';
export 'src/domain/entities/shared_capture.dart';
export 'src/domain/entities/word.dart';
export 'src/domain/usecases/import_seed_pack.dart';
export 'src/domain/word_enricher.dart' show WordEnricher;
export 'src/presentation/bloc/add_word/add_word_cubit.dart';
export 'src/presentation/bloc/add_word/add_word_state.dart';
export 'src/presentation/bloc/review_session/review_session_cubit.dart';
export 'src/presentation/bloc/review_session/review_session_state.dart';
export 'src/presentation/bloc/word_detail/word_detail_cubit.dart';
export 'src/presentation/bloc/word_detail/word_detail_state.dart';
export 'src/presentation/bloc/words_list/words_list_bloc.dart';
export 'src/presentation/bloc/words_list/words_list_event.dart';
export 'src/presentation/bloc/words_list/words_list_state.dart';
export 'src/presentation/screens/add_word_screen.dart';
export 'src/presentation/screens/review_screen.dart';
export 'src/presentation/screens/word_detail_screen.dart';
export 'src/presentation/screens/words_list_screen.dart';
