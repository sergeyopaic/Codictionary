import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/dictionary_snapshot.dart';
import '../../domain/exceptions/backup_exceptions.dart';
import '../../domain/exceptions/storage_exceptions.dart';
import '../../domain/services/backup_files.dart';
import '../app_scope.dart';
import '../l10n/app_strings.dart';
import '../dialogs/confirm_dialog.dart';
import '../theme/app_tokens.dart';
import '../widgets/page_header.dart';

/// Export the whole dictionary and restore it, e.g. on a new device.
/// Restoring replaces everything (no merge), after a confirmation and a
/// safety copy of the current data.
class BackupView extends StatefulWidget {
  const BackupView({super.key, this.isActive = true, this.onRestored});

  final bool isActive;

  /// Called after a successful restore so other screens reload.
  final VoidCallback? onRestored;

  @override
  State<BackupView> createState() => _BackupViewState();
}

class _BackupViewState extends State<BackupView> {
  late final AppUseCases _useCases = AppScope.read(context);

  DictionarySnapshot? _current;

  /// Why the current data could not be read; worded at build time.
  StorageException? _currentError;
  List<BackupFile> _files = const [];
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(BackupView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _refresh();
  }

  Future<void> _refresh() async {
    DictionarySnapshot? current;
    StorageException? error;
    var files = const <BackupFile>[];
    try {
      current = await _useCases.exportDictionary.snapshot();
    } on StorageException catch (e) {
      error = e;
    }
    try {
      files = await _useCases.backupFiles.list();
    } on StorageException {
      // The list is a convenience; paste and file chooser still work.
    }
    if (!mounted) return;
    setState(() {
      _current = current;
      _currentError = error;
      _files = files;
    });
  }

  void _show(String message, {bool error = false}) => setState(() {
    _message = message;
    _messageIsError = error;
  });

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Export

  // Strings are taken before the first await of each action: the widget
  // may rebuild (or go away) while it waits.

  Future<void> _saveFile() => _run(() async {
    final s = context.s;
    try {
      final location = await _useCases.saveBackupFile();
      _show(s.backupSaved(location));
      await _refresh();
    } on StorageException catch (e) {
      _show(s.notSaved(s.storageError(e)), error: true);
    }
  });

  Future<void> _copy() => _run(() async {
    final s = context.s;
    try {
      await Clipboard.setData(
        ClipboardData(text: await _useCases.exportDictionary()),
      );
      _show(s.backupCopied);
    } on StorageException catch (e) {
      _show(s.notCopied(s.storageError(e)), error: true);
    }
  });

  // ---------------------------------------------------------------------------
  // Restore

  Future<void> _paste() async {
    final s = context.s;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      _show(s.clipboardEmpty, error: true);
      return;
    }
    await _restore(text, s);
  }

  Future<void> _pick() async {
    final s = context.s;
    final text = await _useCases.backupFiles.pick();
    if (text != null) await _restore(text, s);
  }

  Future<void> _restoreFile(BackupFile file) async {
    final s = context.s;
    try {
      await _restore(await _useCases.backupFiles.read(file), s);
    } on StorageException catch (e) {
      _show(s.couldNotRead(file.name, s.storageError(e)), error: true);
    }
  }

  Future<void> _restore(String text, AppStrings s) async {
    final DictionarySnapshot backup;
    try {
      backup = _useCases.parseBackup(text);
    } on BackupFormatException catch (e) {
      _show(s.invalidBackup(s.backupProblem(e)), error: true);
      return;
    }
    final current = _current;
    if (current == null) {
      _show(s.currentUnreadable, error: true);
      return;
    }
    if (!mounted) return;
    final ok = await showConfirmDialog(
      context,
      title: s.replaceTitle,
      message: s.replaceMessage(
        _date(backup.createdAt),
        _count(s, backup),
        _count(s, current),
      ),
      confirmLabel: s.replace,
      confirmIcon: Icons.settings_backup_restore_rounded,
    );
    if (!ok) return;
    await _run(() async {
      try {
        final safetyCopy = await _useCases.replaceDictionary(backup);
        _show(s.restored(_count(s, backup), safetyCopy));
        widget.onRestored?.call();
        await _refresh();
      } on StorageException catch (e) {
        _show(s.notRestored(s.storageError(e)), error: true);
      }
    });
  }

  static String _count(AppStrings s, DictionarySnapshot snapshot) =>
      s.snapshotCount(snapshot.words.length, snapshot.vocabularies.length);

  static String _date(DateTime d) {
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)} '
        '${two(l.hour)}:${two(l.minute)}';
  }

  // ---------------------------------------------------------------------------
  // Build

  @override
  Widget build(BuildContext context) {
    final wide = AppBreakpoints.isWide(context);
    final pad = wide ? AppSpacing.xxl : AppSpacing.lg;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final current = _current;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: EdgeInsets.fromLTRB(pad, pad, pad, 120),
              children: [
                PageHeader(
                  title: context.s.backupTitle,
                  subtitle: context.s.backupSubtitle,
                ),
                const SizedBox(height: AppSpacing.xl),
                _Section(
                  icon: Icons.download_rounded,
                  title: context.s.backUpTitle,
                  text: current != null
                      ? context.s.backUpText(_count(context.s, current))
                      : _currentError != null
                      ? context.s.storageError(_currentError!)
                      : context.s.readingData,
                  actions: [
                    FilledButton.icon(
                      onPressed: _busy || current == null ? null : _saveFile,
                      icon: const Icon(Icons.save_alt_rounded),
                      label: Text(context.s.saveBackupFile),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy || current == null ? null : _copy,
                      icon: const Icon(Icons.copy_rounded),
                      label: Text(context.s.copyToClipboard),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _Section(
                  icon: Icons.settings_backup_restore_rounded,
                  title: context.s.restoreTitle,
                  text: context.s.restoreText,
                  actions: [
                    FilledButton.tonalIcon(
                      onPressed: _busy ? null : _paste,
                      icon: const Icon(Icons.content_paste_rounded),
                      label: Text(context.s.pasteFromClipboard),
                    ),
                    if (_useCases.backupFiles.canPick)
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _pick,
                        icon: const Icon(Icons.folder_open_rounded),
                        label: Text(context.s.openFile),
                      ),
                  ],
                  footer: _files.isEmpty
                      ? null
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              context.s.backupsOnDevice,
                              style: theme.textTheme.titleSmall,
                            ),
                            for (final f in _files)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.description_outlined),
                                title: Text(f.name),
                                subtitle: Text(
                                  _date(f.modified),
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                trailing: TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _restoreFile(f),
                                  child: Text(context.s.restore),
                                ),
                              ),
                          ],
                        ),
                ),
                if (_busy) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const LinearProgressIndicator(),
                ],
                if (_message != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  SelectableText(
                    _message!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _messageIsError ? scheme.error : scheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.text,
    required this.actions,
    this.footer,
  });

  final IconData icon;
  final String title;
  final String text;
  final List<Widget> actions;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(icon, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: actions,
            ),
            ?footer,
          ],
        ),
      ),
    );
  }
}
