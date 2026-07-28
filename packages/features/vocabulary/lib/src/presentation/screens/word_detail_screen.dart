import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:localization/localization.dart';

import '../../domain/entities/word.dart';
import '../../locator.dart';
import '../bloc/word_detail/word_detail_cubit.dart';
import '../bloc/word_detail/word_detail_state.dart';

class WordDetailScreen extends StatelessWidget {
  const WordDetailScreen({super.key, required this.wordId});

  final int wordId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<WordDetailCubit>()..load(wordId),
      child: const WordDetailView(),
    );
  }
}

@visibleForTesting
class WordDetailView extends StatelessWidget {
  const WordDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WordDetailCubit, WordDetailState>(
      builder: (context, state) {
        final word = state.word;
        return AppScaffold(
          title: word?.display ?? '',
          isLoading: state.status == WordDetailStatus.loading,
          body: switch (state.status) {
            WordDetailStatus.failure => AppErrorView(
              message: state.failureMessage ?? context.l10n.commonErrorGeneric,
            ),
            WordDetailStatus.loading => const SizedBox.shrink(),
            WordDetailStatus.ready => _WordDetailBody(word: word!),
          },
        );
      },
    );
  }
}

class _WordDetailBody extends StatelessWidget {
  const _WordDetailBody({required this.word});

  final Word word;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        Text(word.display, style: theme.textTheme.headlineSmall),
        if (word.phonetic != null)
          Text(
            word.phonetic!,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        if (word.collocation != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(word.collocation!, style: theme.textTheme.titleSmall),
        ],
        for (final meaning in [word.meaningVi, word.meaningEn])
          if (meaning != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(meaning, style: theme.textTheme.bodyLarge),
          ],
        if (word.examples.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Text(
            context.l10n.vocabularyExamples,
            style: theme.textTheme.titleMedium,
          ),
          for (final example in word.examples) ...[
            const SizedBox(height: AppSpacing.md),
            Text(example.sentence, style: theme.textTheme.bodyLarge),
            if (example.isFromLife)
              Text(
                context.l10n.vocabularyFromYourReading,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
          ],
        ],
      ],
    );
  }
}
