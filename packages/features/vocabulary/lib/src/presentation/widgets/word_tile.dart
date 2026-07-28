import 'package:app_ui/app_ui.dart';
import 'package:database/database.dart' show EnrichmentStatus;
import 'package:flutter/material.dart';
import 'package:localization/localization.dart';

import '../../domain/entities/word.dart';

/// One word in the list: the word itself, and the most useful thing known
/// about it so far.
class WordTile extends StatelessWidget {
  const WordTile({super.key, required this.word, required this.onTap});

  final Word word;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending = word.enrichmentStatus == EnrichmentStatus.pending;
    final subtitle =
        word.meaningVi ?? word.meaningEn ?? word.bestExample?.sentence;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      word.display,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (word.phonetic != null)
                    Text(
                      word.phonetic!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (pending) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  context.l10n.vocabularyPendingEnrichment,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
