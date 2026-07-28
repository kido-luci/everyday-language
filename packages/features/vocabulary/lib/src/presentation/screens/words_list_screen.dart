import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:localization/localization.dart';

import '../../locator.dart';
import '../bloc/words_list/words_list_bloc.dart';
import '../bloc/words_list/words_list_event.dart';
import '../bloc/words_list/words_list_state.dart';
import '../widgets/word_tile.dart';

/// The learner's collected words, newest first.
class WordsListScreen extends StatelessWidget {
  const WordsListScreen({
    super.key,
    required this.onAdd,
    required this.onOpen,
    required this.onReview,
  });

  final VoidCallback onAdd;
  final void Function(int wordId) onOpen;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<WordsListBloc>()..add(const WordsRequested()),
      child: WordsListView(
        onAdd: onAdd,
        onOpen: onOpen,
        onReview: onReview,
      ),
    );
  }
}

@visibleForTesting
class WordsListView extends StatelessWidget {
  const WordsListView({
    super.key,
    required this.onAdd,
    required this.onOpen,
    required this.onReview,
  });

  final VoidCallback onAdd;
  final void Function(int wordId) onOpen;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WordsListBloc, WordsListState>(
      builder: (context, state) {
        return AppScaffold(
          title: context.l10n.vocabularyTitle,
          actions: [
            if (state.words.isNotEmpty)
              IconButton(
                onPressed: onReview,
                tooltip: context.l10n.reviewStart,
                icon: const FaIcon(FontAwesomeIcons.graduationCap),
              ),
          ],
          padding: EdgeInsets.zero,
          isLoading: state.status == WordsListStatus.loading,
          floatingActionButton: FloatingActionButton(
            onPressed: onAdd,
            child: const FaIcon(FontAwesomeIcons.plus),
          ),
          body: switch (state.status) {
            WordsListStatus.failure => AppErrorView(
              message: state.failureMessage ?? context.l10n.commonErrorGeneric,
              onRetry: () =>
                  context.read<WordsListBloc>().add(const WordsRequested()),
            ),
            _ when state.isEmpty => AppEmptyView(
              icon: FontAwesomeIcons.bookOpen,
              title: context.l10n.vocabularyEmptyTitle,
              message: context.l10n.vocabularyEmptyMessage,
            ),
            _ => ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              itemCount: state.words.length,
              itemBuilder: (context, i) {
                final word = state.words[i];
                return WordTile(word: word, onTap: () => onOpen(word.id));
              },
            ),
          },
        );
      },
    );
  }
}
