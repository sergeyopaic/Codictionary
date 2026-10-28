import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../dictionary_view_model.dart';

/// Opens the add/edit word dialog. Returns true when the word was saved.
Future<bool> showWordEditorDialog(
  BuildContext context, {
  required DictionaryViewModel vm,
  String? wordId,
  String? initialEng,
}) async {
  return (await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (_) =>
            WordEditorDialog(vm: vm, wordId: wordId, initialEng: initialEng),
      )) ??
      false;
}

class WordEditorDialog extends StatefulWidget {
  const WordEditorDialog({
    super.key,
    required this.vm,
    this.wordId,
    this.initialEng,
  });

  final DictionaryViewModel vm;

  /// Id of the word to edit; null to add a new word.
  final String? wordId;

  /// Prefills the English field when adding a new word.
  final String? initialEng;

  @override
  State<WordEditorDialog> createState() => _WordEditorDialogState();
}

class _WordEditorDialogState extends State<WordEditorDialog> {
  late final TextEditingController _eng;
  late final TextEditingController _rus;
  Timer? _debounce;
  bool _autoTranslate = true;
  bool _translating = false;
  bool _saving = false;
  bool _rusTouched = false;
  String? _engError;

  bool get _isEdit => widget.wordId != null;

  @override
  void initState() {
    super.initState();
    final word = _isEdit ? widget.vm.wordById(widget.wordId!) : null;
    _eng = TextEditingController(text: word?.source ?? widget.initialEng ?? '');
    _rus = TextEditingController(text: word?.target ?? '');
    // When editing, an existing translation counts as user-provided.
    _rusTouched = _isEdit && _rus.text.isNotEmpty;
    if (!_isEdit && _eng.text.isNotEmpty) _onEngChanged(_eng.text);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _eng.dispose();
    _rus.dispose();
    super.dispose();
  }

  void _onEngChanged(String text) {
    if (_engError != null) setState(() => _engError = null);
    _debounce?.cancel();
    final trimmed = text.trim();
    if (!_autoTranslate || _rusTouched || trimmed.isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _translating = true);
      try {
        final translated = await widget.vm.translateToRu(trimmed);
        if (!mounted || _rusTouched || _eng.text.trim() != trimmed) return;
        _rus.value = TextEditingValue(
          text: translated,
          selection: TextSelection.collapsed(offset: translated.length),
        );
      } catch (_) {
      } finally {
        if (mounted) setState(() => _translating = false);
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final eng = _eng.text.trim();
    var rus = _rus.text.trim();
    if (eng.isEmpty) {
      setState(() => _engError = 'Enter a word first');
      return;
    }
    setState(() => _saving = true);
    if (_autoTranslate && rus.isEmpty) {
      try {
        rus = await widget.vm.translateToRu(eng);
      } catch (_) {}
    }
    final ok = _isEdit
        ? await widget.vm.editWord(widget.wordId!, eng: eng, rus: rus)
        : await widget.vm.addWord(eng: eng, rus: rus);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else if (_isEdit && widget.vm.wordById(widget.wordId!) == null) {
      // The word was deleted while the dialog was saving.
      Navigator.of(context).pop(false);
    } else {
      setState(() {
        _saving = false;
        _engError = 'This word already exists in this vocabulary';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      _isEdit ? Icons.edit_rounded : Icons.translate_rounded,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEdit ? 'Edit word' : 'Add a word',
                          style: theme.textTheme.headlineSmall,
                        ),
                        Text(
                          'Cody will translate and explain it for you.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: _eng,
                autofocus: true,
                enabled: !_saving,
                textInputAction: TextInputAction.next,
                style: theme.textTheme.titleMedium,
                decoration: InputDecoration(
                  labelText: 'English',
                  hintText: 'e.g. serendipity',
                  errorText: _engError,
                  prefixIcon: const _LangBadge('EN'),
                ),
                onChanged: _onEngChanged,
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _rus,
                enabled: !_saving,
                textInputAction: TextInputAction.done,
                style: theme.textTheme.titleMedium,
                decoration: InputDecoration(
                  labelText: 'Russian',
                  hintText: _autoTranslate
                      ? 'Filled in automatically'
                      : 'Type a translation',
                  prefixIcon: const _LangBadge('RU'),
                  suffixIcon: _translating
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                onChanged: (text) => _rusTouched = text.trim().isNotEmpty,
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                ),
                value: _autoTranslate,
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _autoTranslate = v),
                title: Text(
                  'Auto-translate',
                  style: theme.textTheme.titleSmall,
                ),
                subtitle: Text(
                  'Translate with DeepL as you type',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.onSurfaceVariant,
                            ),
                          )
                        : Icon(
                            _isEdit ? Icons.check_rounded : Icons.add_rounded,
                          ),
                    label: Text(
                      _saving
                          ? 'Cody is thinking…'
                          : _isEdit
                          ? 'Save changes'
                          : 'Add word',
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

class _LangBadge extends StatelessWidget {
  const _LangBadge(this.code);

  final String code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.sm),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: _badge(theme, scheme),
      ),
    );
  }

  Widget _badge(ThemeData theme, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        code,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
