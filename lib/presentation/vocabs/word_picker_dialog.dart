import 'package:flutter/material.dart';

import '../../domain/entities/word_entity.dart';
import '../theme/app_tokens.dart';

/// Lets the user pick dictionary words to add to a collection. Returns the
/// chosen ids, or null if cancelled.
Future<List<String>?> showWordPickerDialog(
  BuildContext context, {
  required List<WordEntity> words,
  required bool dictionaryEmpty,
}) => showDialog<List<String>>(
  context: context,
  builder: (_) =>
      _WordPickerDialog(words: words, dictionaryEmpty: dictionaryEmpty),
);

class _WordPickerDialog extends StatefulWidget {
  const _WordPickerDialog({required this.words, required this.dictionaryEmpty});

  final List<WordEntity> words;
  final bool dictionaryEmpty;

  @override
  State<_WordPickerDialog> createState() => _WordPickerDialogState();
}

class _WordPickerDialogState extends State<_WordPickerDialog> {
  final Set<String> _picked = {};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? widget.words
        : widget.words
              .where(
                (w) =>
                    w.source.toLowerCase().contains(q) ||
                    w.target.toLowerCase().contains(q),
              )
              .toList();

    final String? emptyText = widget.dictionaryEmpty
        ? 'Your dictionary is empty. Add words in the Dictionary first.'
        : widget.words.isEmpty
        ? 'Every dictionary word is already in this vocabulary.'
        : shown.isEmpty
        ? 'No words match "$_query".'
        : null;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add words', style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.lg),
              if (widget.words.isNotEmpty) ...[
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search words',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Flexible(
                child: emptyText != null
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xl,
                        ),
                        child: Text(
                          emptyText,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: shown.length,
                        itemBuilder: (context, i) {
                          final w = shown[i];
                          return CheckboxListTile(
                            value: _picked.contains(w.id),
                            onChanged: (on) => setState(
                              () => on == true
                                  ? _picked.add(w.id)
                                  : _picked.remove(w.id),
                            ),
                            title: Text(w.source),
                            subtitle: w.target.isEmpty ? null : Text(w.target),
                          );
                        },
                      ),
              ),
              const SizedBox(height: AppSpacing.lg),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: AppSpacing.sm,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: _picked.isEmpty
                        ? null
                        : () => Navigator.of(context).pop([
                            // Keep the dictionary order.
                            for (final w in widget.words)
                              if (_picked.contains(w.id)) w.id,
                          ]),
                    child: Text(
                      _picked.length <= 1
                          ? 'Add word'
                          : 'Add ${_picked.length} words',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
