import 'package:flutter/material.dart';

import '../../../domain/exceptions/storage_exceptions.dart';
import '../../dialogs/confirm_dialog.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/empty_state.dart';

/// Shown instead of the dictionary when stored words could not be loaded.
/// Offers only actions that keep the damaged data.
class StorageErrorView extends StatefulWidget {
  const StorageErrorView({
    super.key,
    required this.error,
    required this.onRetry,
    required this.onRecover,
  });

  final StorageException error;
  final Future<void> Function() onRetry;
  final Future<void> Function(StorageRecovery action) onRecover;

  @override
  State<StorageErrorView> createState() => _StorageErrorViewState();
}

class _StorageErrorViewState extends State<StorageErrorView> {
  bool _busy = false;
  String? _actionError;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      await action();
    } on StorageException catch (e) {
      _actionError = e.message;
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _startEmpty() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Start with an empty dictionary?',
      message:
          'The damaged data is kept in a separate copy next to your '
          'dictionary, so nothing is deleted.',
      confirmLabel: 'Start empty',
      confirmIcon: Icons.restart_alt_rounded,
      destructive: false,
    );
    if (ok) await _run(() => widget.onRecover(StorageRecovery.startEmpty));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = widget.error;
    final corrupted = error is StorageCorruptedException ? error : null;

    final String title;
    final String message;
    if (corrupted == null) {
      title = 'Can\'t open your dictionary';
      message = '${error.message} Your words were not changed.';
    } else if (corrupted.hasBackup) {
      title = 'Your dictionary file is damaged';
      message =
          '${error.message} You can restore the last good copy. The damaged '
          'data is kept aside, nothing is deleted.';
    } else {
      title = 'Your dictionary file is damaged';
      message =
          '${error.message} No backup is available. The damaged data has '
          'not been changed.';
    }

    final actions = <Widget>[
      if (corrupted != null && corrupted.hasBackup)
        FilledButton.icon(
          onPressed: _busy
              ? null
              : () =>
                    _run(() => widget.onRecover(StorageRecovery.restoreBackup)),
          icon: const Icon(Icons.history_rounded),
          label: const Text('Restore last good copy'),
        ),
      if (corrupted != null)
        OutlinedButton.icon(
          onPressed: _busy ? null : _startEmpty,
          icon: const Icon(Icons.restart_alt_rounded),
          label: const Text('Start empty'),
        ),
      if (corrupted == null)
        FilledButton.icon(
          onPressed: _busy ? null : () => _run(widget.onRetry),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        )
      else if (!corrupted.hasBackup)
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _run(widget.onRetry),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
    ];

    return EmptyState(
      image: CodyArt.delete,
      title: title,
      message: message,
      action: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: actions,
          ),
          if (_busy) ...[
            const SizedBox(height: AppSpacing.lg),
            const LinearProgressIndicator(),
          ],
          if (_actionError != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              _actionError!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          if (corrupted != null) ...[
            const SizedBox(height: AppSpacing.lg),
            SelectableText(
              corrupted.location,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
