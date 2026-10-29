import 'package:flutter/material.dart';

import '../../domain/entities/vocabulary.dart';
import '../../domain/entities/word_entity.dart';
import '../../domain/exceptions/storage_exceptions.dart';
import '../theme/app_tokens.dart';
import '../widgets/empty_state.dart';
import 'create_vocabulary_dialog.dart';
import 'vocabs_view_model.dart';
import 'word_picker_dialog.dart';
import '../l10n/app_strings.dart';

/// The words of one collection. Removing a word here only takes it out of
/// the collection; it stays in the dictionary.
class VocabularyWordsView extends StatelessWidget {
  const VocabularyWordsView({
    super.key,
    required this.vm,
    required this.vocabularyId,
  });

  final VocabsViewModel vm;
  final String vocabularyId;

  Future<void> _addWords(BuildContext context, Vocabulary v) async {
    final messenger = ScaffoldMessenger.of(context);
    final s = context.s;
    final candidates = vm.words.where((w) => !v.contains(w.id)).toList();
    final picked = await showWordPickerDialog(
      context,
      words: candidates,
      dictionaryEmpty: vm.words.isEmpty,
    );
    if (picked == null || picked.isEmpty) return;
    try {
      await vm.addWords(v.id, picked);
    } on StorageException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(s.notSaved(s.storageError(e)))),
      );
    }
  }

  Future<void> _remove(BuildContext context, WordEntity word) async {
    final messenger = ScaffoldMessenger.of(context);
    final s = context.s;
    Future<void> set(bool member) async {
      try {
        await vm.setMembership(vocabularyId, word.id, member: member);
      } on StorageException catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text(s.notSaved(s.storageError(e)))),
        );
        rethrow;
      }
    }

    try {
      await set(false);
    } on StorageException {
      return;
    }
    messenger.hideCurrentSnackBar(); // Undo must not wait in the queue
    messenger.showSnackBar(
      SnackBar(
        content: Text(s.removedFromVocab(word.source)),
        action: SnackBarAction(
          label: s.undo,
          onPressed: () => set(true).catchError((_) {}),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final v = vm.byId(vocabularyId);
        if (v == null) {
          // Deleted meanwhile.
          return Scaffold(
            appBar: AppBar(),
            body: EmptyState(
              image: CodyArt.reading,
              title: context.s.vocabGoneTitle,
              message: context.s.vocabGoneMessage,
            ),
          );
        }
        final words = vm.wordsOf(v);
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                SizedBox.square(
                  dimension: 32,
                  child: Image.asset(
                    // Decorative: a text next to it says the same.
                    excludeFromSemantics: true,

                    vocabIconHiRes(v.iconPath),
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.menu_book_rounded),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    v.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    child: Text(
                      [
                        context.s.wordCount(words.length),
                        if (v.description.isNotEmpty) v.description,
                      ].join(' · '),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: words.isEmpty
                        ? EmptyState(
                            image: CodyArt.reading,
                            title: context.s.noWordsHereTitle,
                            message: context.s.noWordsHereMessage,
                            action: FilledButton.icon(
                              onPressed: () => _addWords(context, v),
                              icon: const Icon(Icons.playlist_add_rounded),
                              label: Text(context.s.addWords),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              0,
                              AppSpacing.lg,
                              120,
                            ),
                            itemCount: words.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (context, i) {
                              final w = words[i];
                              return Card(
                                child: ListTile(
                                  title: Text(
                                    w.source,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  subtitle: Text(
                                    w.target.isEmpty ? '—' : w.target,
                                    style: TextStyle(color: scheme.secondary),
                                  ),
                                  trailing: IconButton(
                                    tooltip: context.s.removeFromVocab,
                                    icon: const Icon(
                                      Icons.remove_circle_outline_rounded,
                                    ),
                                    onPressed: () => _remove(context, w),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: words.isEmpty
              ? null
              : FloatingActionButton.extended(
                  // Tabs stay alive in an IndexedStack, so several FABs coexist;
                  // without distinct tags opening a page crashes the hero animation.
                  heroTag: null,
                  onPressed: () => _addWords(context, v),
                  icon: const Icon(Icons.playlist_add_rounded),
                  label: Text(context.s.addWords),
                ),
        );
      },
    );
  }
}
