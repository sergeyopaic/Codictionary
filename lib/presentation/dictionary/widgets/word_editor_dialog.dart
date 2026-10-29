import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/exceptions/service_exceptions.dart';
import '../../../domain/exceptions/storage_exceptions.dart';
import '../../theme/app_tokens.dart';
import '../dictionary_view_model.dart';
import '../../l10n/app_strings.dart';

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
  late bool _autoTranslate = widget.vm.translationAvailable;
  bool _translating = false;
  bool _saving = false;
  bool _rusTouched = false;
  String? _engError;
  String? _saveError;

  /// Why the last automatic translation failed; shown under the RU field.
  String? _translateError;

  /// After a failed translation on save, the next save goes ahead without
  /// one instead of failing again.
  bool _skipTranslation = false;

  /// Number of the latest translation request. A response is used only if it
  /// answers the latest request, so a slow answer for "ca" can never replace
  /// the one for "cat".
  int _translation = 0;

  bool get _isEdit => widget.wordId != null;

  @override
  void initState() {
    super.initState();
    final word = _isEdit ? widget.vm.wordById(widget.wordId!) : null;
    _eng = TextEditingController(text: word?.source ?? widget.initialEng ?? '');
    _rus = TextEditingController(text: word?.target ?? '');
    // When editing, an existing translation counts as user-provided.
    _rusTouched = _isEdit && _rus.text.isNotEmpty;
    if (!_isEdit && _eng.text.isNotEmpty) _scheduleTranslation();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _eng.dispose();
    _rus.dispose();
    super.dispose();
  }

  /// Drops the pending and the in-flight translation.
  void _cancelTranslation() {
    _debounce?.cancel();
    _translation++;
    _translating = false;
  }

  void _scheduleTranslation() {
    final text = _eng.text.trim();
    if (!_autoTranslate || _rusTouched || text.isEmpty) return;
    _debounce = Timer(
      const Duration(milliseconds: 500),
      () => _translate(text),
    );
  }

  void _onEngChanged(String _) {
    setState(() {
      _engError = null;
      _translateError = null;
      _skipTranslation = false;
      _cancelTranslation();
    });
    _scheduleTranslation();
  }

  void _onRusChanged(String text) {
    final touched = text.trim().isNotEmpty;
    if (touched == _rusTouched && !touched) return;
    setState(() {
      _rusTouched = touched;
      // A typed translation wins over any answer still on its way.
      if (touched) {
        _cancelTranslation();
        _translateError = null;
      }
    });
  }

  void _onAutoTranslateChanged(bool on) {
    setState(() {
      _autoTranslate = on;
      _cancelTranslation();
      _translateError = null;
      _skipTranslation = false;
    });
    if (on) _scheduleTranslation();
  }

  bool _stillWanted(int request, String eng) =>
      mounted &&
      request == _translation &&
      _autoTranslate &&
      !_rusTouched &&
      _eng.text.trim() == eng;

  /// Translates [eng] into the RU field. Returns the translation, or null if
  /// it failed (the reason is shown) or is no longer wanted.
  Future<String?> _translate(String eng) async {
    final request = ++_translation;
    setState(() {
      _translating = true;
      _translateError = null;
    });
    try {
      final translated = await widget.vm.translateToRu(eng);
      if (!_stillWanted(request, eng)) return null;
      _rus.value = TextEditingValue(
        text: translated,
        selection: TextSelection.collapsed(offset: translated.length),
      );
      return translated;
    } catch (e) {
      if (_stillWanted(request, eng)) {
        setState(
          () => _translateError = context.s.notTranslated(
            e is ServiceException
                ? context.s.serviceError(e)
                : context.s.failureShortReason(e),
          ),
        );
      }
      return null;
    } finally {
      if (mounted && request == _translation) {
        setState(() => _translating = false);
      }
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final eng = _eng.text.trim();
    var rus = _rus.text.trim();
    if (eng.isEmpty) {
      setState(() => _engError = context.s.enterWordFirst);
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    if (_autoTranslate && rus.isEmpty && !_skipTranslation) {
      _debounce?.cancel();
      final translated = await _translate(eng);
      if (!mounted) return;
      if (translated == null) {
        // Keep the dialog open: the user can type a translation, or press
        // save again to keep the word without one.
        setState(() {
          _saving = false;
          _skipTranslation = true;
        });
        return;
      }
      rus = translated;
    }
    final bool ok;
    try {
      ok = _isEdit
          ? await widget.vm.editWord(widget.wordId!, eng: eng, rus: rus)
          : await widget.vm.addWord(eng: eng, rus: rus);
    } on StorageException catch (e) {
      // Keep the dialog and the typed text so the user can retry.
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = context.s.notSaved(context.s.storageError(e));
        });
      }
      return;
    }
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else if (_isEdit && widget.vm.wordById(widget.wordId!) == null) {
      // The word was deleted while the dialog was saving.
      Navigator.of(context).pop(false);
    } else {
      setState(() {
        _saving = false;
        _engError = context.s.wordExists;
      });
    }
  }

  String get _subtitle =>
      switch ((widget.vm.translationAvailable, widget.vm.aiAvailable)) {
        (final translation, final ai) => context.s.editorSubtitle(
          translation: translation,
          ai: ai,
        ),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        // Only the fields scroll; the buttons stay visible even with large
        // text or a small screen.
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: SingleChildScrollView(
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
                              _isEdit
                                  ? Icons.edit_rounded
                                  : Icons.translate_rounded,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isEdit
                                      ? context.s.editWord
                                      : context.s.addAWord,
                                  style: theme.textTheme.headlineSmall,
                                ),
                                Text(
                                  _subtitle,
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
                          labelText: context.s.english,
                          hintText: context.s.englishHint,
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
                          labelText: context.s.russian,
                          hintText: _autoTranslate
                              ? context.s.russianAutoHint
                              : context.s.russianTypeHint,
                          prefixIcon: const _LangBadge('RU'),
                          helperText: _translateError,
                          helperMaxLines: 3,
                          helperStyle: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.error,
                          ),
                          suffixIcon: _translating
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        onChanged: _onRusChanged,
                        onSubmitted: (_) => _save(),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                        ),
                        value: _autoTranslate,
                        onChanged: _saving || !widget.vm.translationAvailable
                            ? null
                            : _onAutoTranslateChanged,
                        title: Text(
                          context.s.autoTranslate,
                          style: theme.textTheme.titleSmall,
                        ),
                        subtitle: Text(
                          widget.vm.translationAvailable
                              ? context.s.autoTranslateOn
                              : context.s.autoTranslateUnavailable,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (_saveError != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _saveError!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Stacks the buttons when a long label does not fit.
              OverflowBar(
                alignment: MainAxisAlignment.end,
                overflowAlignment: OverflowBarAlignment.end,
                spacing: AppSpacing.sm,
                overflowSpacing: AppSpacing.sm,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: Text(context.s.cancel),
                  ),
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
                      _saving && _translating
                          ? context.s.translating
                          : _saving
                          ? context.s.saving
                          : _skipTranslation && _rus.text.trim().isEmpty
                          ? context.s.saveWithoutTranslation
                          : _isEdit
                          ? context.s.saveChanges
                          : context.s.addWord,
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
