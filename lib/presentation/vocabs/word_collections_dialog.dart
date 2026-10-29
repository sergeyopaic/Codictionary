import 'package:flutter/material.dart';

import '../../domain/entities/vocabulary.dart';
import '../../domain/exceptions/storage_exceptions.dart';
import '../app_scope.dart';
import '../theme/app_tokens.dart';

/// Shows which collections a word belongs to; each checkbox saves at once.
Future<void> showWordCollectionsDialog(
  BuildContext context, {
  required String wordId,
  required String word,
}) => showDialog<void>(
  context: context,
  builder: (_) => _WordCollectionsDialog(wordId: wordId, word: word),
);

class _WordCollectionsDialog extends StatefulWidget {
  const _WordCollectionsDialog({required this.wordId, required this.word});

  final String wordId;
  final String word;

  @override
  State<_WordCollectionsDialog> createState() => _WordCollectionsDialogState();
}

class _WordCollectionsDialogState extends State<_WordCollectionsDialog> {
  late final AppUseCases _useCases = AppScope.read(context);
  List<Vocabulary>? _vocabularies;
  String? _error;
  final Set<String> _saving = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final loaded = await _useCases.getVocabularies();
      if (mounted) setState(() => _vocabularies = List.of(loaded));
    } on StorageException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _toggle(Vocabulary v, bool member) async {
    final i = _vocabularies!.indexWhere((e) => e.id == v.id);
    setState(() {
      _error = null;
      _saving.add(v.id);
      _vocabularies![i] = v.copyWith(
        wordIds: member
            ? [...v.wordIds, widget.wordId]
            : v.wordIds.where((id) => id != widget.wordId).toList(),
      );
    });
    try {
      await _useCases.setWordInVocabulary(
        vocabularyId: v.id,
        wordId: widget.wordId,
        member: member,
      );
    } on StorageException catch (e) {
      if (mounted) {
        setState(() {
          _vocabularies![i] = v; // roll back the checkbox
          _error = 'Not saved: ${e.message}';
        });
      }
    } finally {
      if (mounted) setState(() => _saving.remove(v.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vocabularies = _vocabularies;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Vocabularies', style: theme.textTheme.headlineSmall),
              Text(
                'Choose where "${widget.word}" belongs.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Flexible(
                child: vocabularies == null && _error == null
                    ? const Center(child: CircularProgressIndicator())
                    : vocabularies == null || vocabularies.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.lg,
                        ),
                        child: Text(
                          vocabularies == null
                              ? ''
                              : 'No vocabularies yet. Create one on the '
                                    'Vocabularies tab.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final v in vocabularies)
                            CheckboxListTile(
                              value: v.contains(widget.wordId),
                              onChanged: _saving.contains(v.id)
                                  ? null
                                  : (on) => _toggle(v, on ?? false),
                              title: Text(v.name),
                              subtitle: v.description.isEmpty
                                  ? null
                                  : Text(
                                      v.description,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                            ),
                        ],
                      ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
