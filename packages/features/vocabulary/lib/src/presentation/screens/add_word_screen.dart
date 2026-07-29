import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:localization/localization.dart';

import '../../locator.dart';
import '../bloc/add_word/add_word_cubit.dart';
import '../bloc/add_word/add_word_state.dart';

/// Capture a word by hand.
///
/// The sentence field is optional but pushed hard in the copy: a word saved
/// with the sentence it was met in is the whole premise of the app, and the
/// cloze drill has nothing to blank out without one.
class AddWordScreen extends StatelessWidget {
  const AddWordScreen({
    super.key,
    required this.onSaved,
    this.initialWord,
    this.initialSentence,
  });

  final VoidCallback onSaved;

  /// Filled in when the screen was opened from a share.
  final String? initialWord;
  final String? initialSentence;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          getIt<AddWordCubit>()
            ..prefill(word: initialWord, sentence: initialSentence),
      child: AddWordView(
        onSaved: onSaved,
        initialWord: initialWord,
        initialSentence: initialSentence,
      ),
    );
  }
}

@visibleForTesting
class AddWordView extends StatelessWidget {
  const AddWordView({
    super.key,
    required this.onSaved,
    this.initialWord,
    this.initialSentence,
  });

  final VoidCallback onSaved;

  /// Seed values for the fields. Read once, on the first build: the cubit is
  /// the source of truth afterwards, and feeding state back in on every
  /// rebuild would fight the learner's cursor.
  final String? initialWord;
  final String? initialSentence;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AddWordCubit>();

    return BlocConsumer<AddWordCubit, AddWordState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == AddWordStatus.success) onSaved();
      },
      builder: (context, state) {
        return AppScaffold(
          title: context.l10n.vocabularyAddTitle,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg + kFloatingNavBarInset,
          ),
          body: ListView(
            children: [
              AppTextField(
                label: context.l10n.vocabularyWordLabel,
                hint: context.l10n.vocabularyWordHint,
                initialValue: initialWord,
                // A shared sentence leaves the word blank and the cursor
                // waiting in it, which is exactly the one thing still needed.
                autofocus: initialWord == null,
                errorText: state.status == AddWordStatus.failure
                    ? state.failureMessage
                    : null,
                onChanged: cubit.displayChanged,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: context.l10n.vocabularySentenceLabel,
                hint: context.l10n.vocabularySentenceHint,
                helperText: context.l10n.vocabularySentenceHelper,
                initialValue: initialSentence,
                maxLines: 3,
                onChanged: cubit.sentenceChanged,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: context.l10n.vocabularyMeaningLabel,
                hint: context.l10n.vocabularyMeaningHint,
                onChanged: cubit.meaningChanged,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: context.l10n.vocabularySave,
                expand: true,
                isLoading: state.status == AddWordStatus.submitting,
                onPressed: state.canSubmit ? cubit.submit : null,
              ),
            ],
          ),
        );
      },
    );
  }
}
