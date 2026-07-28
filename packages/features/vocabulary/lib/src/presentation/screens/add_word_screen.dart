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
  const AddWordScreen({super.key, required this.onSaved});

  final VoidCallback onSaved;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<AddWordCubit>(),
      child: AddWordView(onSaved: onSaved),
    );
  }
}

@visibleForTesting
class AddWordView extends StatelessWidget {
  const AddWordView({super.key, required this.onSaved});

  final VoidCallback onSaved;

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
                autofocus: true,
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
