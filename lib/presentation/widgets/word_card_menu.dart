import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';

/// Overflow menu (three dots) for card actions: explain, edit, delete.
class WordCardMenu extends StatelessWidget {
  const WordCardMenu({
    super.key,
    required this.onExplain,
    required this.onEdit,
    required this.onDelete,
    this.onCollections,
  });

  final VoidCallback onExplain;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onCollections;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MenuAnchor(
      alignmentOffset: const Offset(-160, 4),
      menuChildren: [
        MenuItemButton(
          leadingIcon: Icon(Icons.auto_awesome_rounded, color: scheme.tertiary),
          onPressed: onExplain,
          child: Text(context.s.explain),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.edit_outlined),
          onPressed: onEdit,
          child: Text(context.s.editWord),
        ),
        if (onCollections != null)
          MenuItemButton(
            leadingIcon: const Icon(Icons.collections_bookmark_outlined),
            onPressed: onCollections,
            child: Text(context.s.vocabulariesMenu),
          ),
        const Divider(height: 9),
        MenuItemButton(
          leadingIcon: Icon(Icons.delete_outline_rounded, color: scheme.error),
          onPressed: onDelete,
          child: Text(context.s.delete, style: TextStyle(color: scheme.error)),
        ),
      ],
      builder: (context, controller, _) => IconButton(
        tooltip: context.s.moreOptions,
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.more_horiz_rounded),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}
