import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:localization/localization.dart';
import 'package:shared_contracts/shared_contracts.dart';

import '../../domain/entities/word.dart';
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
      child: _ReloadOnActivity(
        child: WordsListView(
          onAdd: onAdd,
          onOpen: onOpen,
          onReview: onReview,
        ),
      ),
    );
  }
}

/// Reloads the list whenever something changes the collection.
///
/// Returning from the add screen is not the only way a word changes any more:
/// the dictionary lookup runs after the save, on its own time, and writes a
/// meaning — or gives up — while this screen is already on top. Without this,
/// the tile keeps whatever it was built with, so a word sits there saying its
/// details will arrive when you are online long after they have arrived, or
/// long after the lookup decided they never would.
///
/// The shell keeps every tab alive, so leaving and coming back does not
/// rebuild this either. The dashboard listens for the same reason.
class _ReloadOnActivity extends StatefulWidget {
  const _ReloadOnActivity({required this.child});

  final Widget child;

  @override
  State<_ReloadOnActivity> createState() => _ReloadOnActivityState();
}

class _ReloadOnActivityState extends State<_ReloadOnActivity> {
  StreamSubscription<void>? _activity;

  @override
  void initState() {
    super.initState();
    _activity = getIt<ActivityNotifier>().onActivityOccurred.listen((_) {
      if (mounted) context.read<WordsListBloc>().add(const WordsRequested());
    });
  }

  @override
  void dispose() {
    unawaited(_activity?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
            _ => Column(
              children: [
                const _SearchField(),
                // The search field stays put while the results below it
                // change — including when nothing matches, or the query
                // could not be cleared without retyping over it.
                Expanded(
                  child: state.hasNoMatches
                      ? AppEmptyView(
                          icon: FontAwesomeIcons.magnifyingGlass,
                          title: context.l10n.vocabularySearchNoMatchesTitle,
                          message: context.l10n
                              .vocabularySearchNoMatchesMessage(state.query),
                        )
                      : _WordsList(words: state.visibleWords, onOpen: onOpen),
                ),
              ],
            ),
          },
        );
      },
    );
  }
}

/// Filters the list as it is typed into.
///
/// Stateful only to own the controller, which the clear button needs; the
/// query itself lives in the bloc.
class _SearchField extends StatefulWidget {
  const _SearchField();

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search(String query) =>
      context.read<WordsListBloc>().add(WordsSearched(query));

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: AppTextField(
        controller: _controller,
        hint: context.l10n.vocabularySearchHint,
        prefixIcon: FontAwesomeIcons.magnifyingGlass,
        textInputAction: TextInputAction.search,
        onChanged: _search,
        suffix: ValueListenableBuilder(
          valueListenable: _controller,
          builder: (context, value, _) {
            if (value.text.isEmpty) return const SizedBox.shrink();
            return IconButton(
              tooltip: context.l10n.vocabularySearchClear,
              icon: const FaIcon(FontAwesomeIcons.xmark, size: 16),
              onPressed: () {
                _controller.clear();
                _search('');
              },
            );
          },
        ),
      ),
    );
  }
}

class _WordsList extends StatelessWidget {
  const _WordsList({required this.words, required this.onOpen});

  final List<Word> words;
  final void Function(int wordId) onOpen;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      // The last card would otherwise sit behind the shell's floating nav pill.
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md + kFloatingNavBarInset,
      ),
      itemCount: words.length,
      itemBuilder: (context, i) {
        final word = words[i];
        return WordTile(word: word, onTap: () => onOpen(word.id));
      },
    );
  }
}
