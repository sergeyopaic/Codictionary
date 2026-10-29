import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../l10n/app_strings.dart';

/// Centered confirmation dialog with a Cody illustration.
/// Returns true if the user confirms, false otherwise.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  IconData confirmIcon = Icons.delete_outline_rounded,
  String image = CodyArt.delete,
  bool destructive = true,
}) async {
  return (await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (context) => _ConfirmDialog(
          title: title,
          message: message,
          confirmLabel: confirmLabel ?? context.s.delete,
          confirmIcon: confirmIcon,
          image: image,
          destructive: destructive,
        ),
      )) ??
      false;
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmIcon,
    required this.image,
    required this.destructive,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final IconData confirmIcon;
  final String image;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = destructive
        ? scheme.errorContainer
        : scheme.primaryContainer;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.6),
                ),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Image.asset(
                  // Decorative: a text next to it says the same.
                  excludeFromSemantics: true,
                  image,
                  filterQuality: FilterQuality.high,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(context.s.cancel),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton.icon(
                      autofocus: true,
                      icon: Icon(confirmIcon, size: 20),
                      label: Text(confirmLabel),
                      style: destructive
                          ? FilledButton.styleFrom(
                              backgroundColor: scheme.error,
                              foregroundColor: scheme.onError,
                            )
                          : null,
                      onPressed: () => Navigator.of(context).pop(true),
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
