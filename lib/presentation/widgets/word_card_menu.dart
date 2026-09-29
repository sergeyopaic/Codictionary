import 'package:flutter/material.dart';

/// Overflow menu (three dots) for card actions: explain, edit, delete.
class WordCardMenu extends StatelessWidget {
  const WordCardMenu({
    super.key,
    required this.onExplain,
    required this.onEdit,
    required this.onDelete,
  });

  final VoidCallback onExplain;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MenuAnchor(
      alignmentOffset: const Offset(-160, 4),
      menuChildren: [
        MenuItemButton(
          leadingIcon: Icon(Icons.auto_awesome_rounded, color: scheme.tertiary),
          onPressed: onExplain,
          child: const Text('Explain'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.edit_outlined),
          onPressed: onEdit,
          child: const Text('Edit word'),
        ),
        const Divider(height: 9),
        MenuItemButton(
          leadingIcon: Icon(Icons.delete_outline_rounded, color: scheme.error),
          onPressed: onDelete,
          child: Text('Delete', style: TextStyle(color: scheme.error)),
        ),
      ],
      builder: (context, controller, _) => IconButton(
        tooltip: 'More options',
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.more_horiz_rounded),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}
