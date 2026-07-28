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

  final Future<void> Function() onAdd;
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

  final Future<void> Function() onAdd;
  final void Function(int wordId) onOpen;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WordsListBloc, WordsListState>(
      builder: (context, state) {
        return AppScaffold(
          title: context.l10n.vocabularyTitle,
          // Both actions live in the app bar rather than in a floating action
          // button: on a phone the shell's floating nav pill sits over the
          // bottom-right corner, so a FAB there is unreachable.
          actions: [
            if (state.words.isNotEmpty)
              IconButton(
                onPressed: onReview,
                tooltip: context.l10n.reviewStart,
                icon: const FaIcon(FontAwesomeIcons.graduationCap),
              ),
            IconButton(
              // Reload on return: the add screen writes through the repository,
              // so the list this bloc is holding is stale the moment it pops.
              onPressed: () async {
                await onAdd();
                if (context.mounted) {
                  context.read<WordsListBloc>().add(const WordsRequested());
                }
              },
              tooltip: context.l10n.vocabularyAddTitle,
              icon: const FaIcon(FontAwesomeIcons.plus),
            ),
          ],
          padding: EdgeInsets.zero,
          isLoading: state.status == WordsListStatus.loading,
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
              // The last card would otherwise sit behind the shell's
              // floating nav pill.
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md + kFloatingNavBarInset,
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
