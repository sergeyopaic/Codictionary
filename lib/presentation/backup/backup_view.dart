import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/dictionary_snapshot.dart';
import '../../domain/exceptions/backup_exceptions.dart';
import '../../domain/exceptions/storage_exceptions.dart';
import '../../domain/services/backup_files.dart';
import '../app_scope.dart';
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
  String? _currentError;
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
    String? error;
    var files = const <BackupFile>[];
    try {
      current = await _useCases.exportDictionary.snapshot();
    } on StorageException catch (e) {
      error = e.message;
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

  Future<void> _saveFile() => _run(() async {
    try {
      final location = await _useCases.saveBackupFile();
      _show('Backup saved: $location');
      await _refresh();
    } on StorageException catch (e) {
      _show('Not saved: ${e.message}', error: true);
    }
  });

  Future<void> _copy() => _run(() async {
    try {
      await Clipboard.setData(
        ClipboardData(text: await _useCases.exportDictionary()),
      );
      _show(
        'Backup copied. Paste it somewhere safe, or into Codictionary on '
        'another device.',
      );
    } on StorageException catch (e) {
      _show('Not copied: ${e.message}', error: true);
    }
  });

  // ---------------------------------------------------------------------------
  // Restore

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      _show('The clipboard is empty. Copy a backup first.', error: true);
      return;
    }
    await _restore(text);
  }

  Future<void> _pick() async {
    final text = await _useCases.backupFiles.pick();
    if (text != null) await _restore(text);
  }

  Future<void> _restoreFile(BackupFile file) async {
    try {
      await _restore(await _useCases.backupFiles.read(file));
    } on StorageException catch (e) {
      _show('Could not read ${file.name}: ${e.message}', error: true);
    }
  }

  Future<void> _restore(String text) async {
    final DictionarySnapshot backup;
    try {
      backup = _useCases.parseBackup(text);
    } on BackupFormatException catch (e) {
      _show(
        'This is not a valid backup: ${e.message} Nothing was changed.',
        error: true,
      );
      return;
    }
    final current = _current;
    if (current == null) {
      _show(
        'Your current data cannot be read, so it cannot be backed up before '
        'restoring. Use the recovery options on the Dictionary tab first.',
        error: true,
      );
      return;
    }
    if (!mounted) return;
    final ok = await showConfirmDialog(
      context,
      title: 'Replace your dictionary?',
      message:
          'Backup from ${_date(backup.createdAt)}: ${_count(backup)}.\n'
          'It replaces your current ${_count(current)}. A safety copy of the '
          'current data is saved first.',
      confirmLabel: 'Replace',
      confirmIcon: Icons.settings_backup_restore_rounded,
    );
    if (!ok) return;
    await _run(() async {
      try {
        final safetyCopy = await _useCases.replaceDictionary(backup);
        _show('Restored ${_count(backup)}. Safety copy: $safetyCopy');
        widget.onRestored?.call();
        await _refresh();
      } on StorageException catch (e) {
        _show('Not restored: ${e.message}', error: true);
      }
    });
  }

  static String _count(DictionarySnapshot s) {
    final w = s.words.length;
    final v = s.vocabularies.length;
    return '${w == 1 ? '1 word' : '$w words'} and '
        '${v == 1 ? '1 vocabulary' : '$v vocabularies'}';
  }

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
                const PageHeader(
                  title: 'Backup',
                  subtitle: 'Save your words or move them to another device',
                ),
                const SizedBox(height: AppSpacing.xl),
                _Section(
                  icon: Icons.download_rounded,
                  title: 'Back up your dictionary',
                  text: current != null
                      ? '${_count(current)}, with explanations, dates and '
                            'your own order.'
                      : _currentError ?? 'Reading your data…',
                  actions: [
                    FilledButton.icon(
                      onPressed: _busy || current == null ? null : _saveFile,
                      icon: const Icon(Icons.save_alt_rounded),
                      label: const Text('Save backup file'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy || current == null ? null : _copy,
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copy to clipboard'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _Section(
                  icon: Icons.settings_backup_restore_rounded,
                  title: 'Restore from a backup',
                  text:
                      'Restoring replaces your current dictionary and '
                      'vocabularies. A safety copy of the current data is '
                      'saved first.',
                  actions: [
                    FilledButton.tonalIcon(
                      onPressed: _busy ? null : _paste,
                      icon: const Icon(Icons.content_paste_rounded),
                      label: const Text('Paste from clipboard'),
                    ),
                    if (_useCases.backupFiles.canPick)
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _pick,
                        icon: const Icon(Icons.folder_open_rounded),
                        label: const Text('Open file…'),
                      ),
                  ],
                  footer: _files.isEmpty
                      ? null
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Backups on this device',
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
                                  child: const Text('Restore'),
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
