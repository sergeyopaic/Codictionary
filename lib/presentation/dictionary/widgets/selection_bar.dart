import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';

/// Floating contextual bar shown while selecting words.
class SelectionBar extends StatelessWidget {
  const SelectionBar({
    super.key,
    required this.visible,
    required this.selectedCount,
    required this.allSelected,
    required this.onClose,
    required this.onToggleAll,
    required this.onDelete,
  });

  final bool visible;
  final int selectedCount;
  final bool allSelected;
  final VoidCallback onClose;
  final VoidCallback onToggleAll;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = scheme.onInverseSurface;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 1.6),
        duration: AppMotion.medium,
        curve: AppMotion.emphasized,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: AppMotion.fast,
          child: Material(
            color: scheme.inverseSurface,
            elevation: 8,
            shadowColor: scheme.shadow.withValues(alpha: 0.4),
            shape: const StadiumBorder(),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm - 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Done (Esc)',
                    color: fg,
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(shape: const CircleBorder()),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Text(
                      '$selectedCount selected',
                      style: theme.textTheme.titleSmall?.copyWith(color: fg),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.inversePrimary,
                    ),
                    onPressed: onToggleAll,
                    child: Text(allSelected ? 'Clear' : 'Select all'),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.error,
                      foregroundColor: scheme.onError,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                    ),
                    onPressed: selectedCount > 0 ? onDelete : null,
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    label: const Text('Delete'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
