import 'package:flutter/material.dart';

/// A simple pop-up dialog for creating a new vocabulary.
/// No persistence logic is included; caller may read the result and act later.
class CreateVocabularyDialog extends StatefulWidget {
  const CreateVocabularyDialog({super.key});

  @override
  State<CreateVocabularyDialog> createState() => _CreateVocabularyDialogState();
}

class _CreateVocabularyDialogState extends State<CreateVocabularyDialog> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  int selectedIcon = 1;
  final LayerLink _iconLink = LayerLink();
  OverlayEntry? _iconPickerEntry;

  Widget _iconImage(String path, double logicalWidth) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final px = (logicalWidth * dpr).round();

    return Image.asset(
      path,
      width: logicalWidth,
      height: logicalWidth,
      fit: BoxFit.contain,
      cacheWidth: px,
      cacheHeight: px,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported),
    );
  }

  void _showIconPickerOverlay() {
    if (_iconPickerEntry != null) return;
    final paths = List.generate(
      14,
      (i) => 'assets/media/icons/new_dictionary/3.0x/${i + 1}.png',
    );
    final overlay = Overlay.of(context);
    _iconPickerEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Tap outside to dismiss
            Positioned.fill(
              child: GestureDetector(
                onTap: _hideIconPicker,
                behavior: HitTestBehavior.translucent,
              ),
            ),
            CompositedTransformFollower(
              link: _iconLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 100),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  padding: const EdgeInsets.all(10),
                  constraints: const BoxConstraints(
                    maxWidth: 520,
                    maxHeight: 360,
                  ),
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                    itemCount: paths.length,
                    itemBuilder: (context, i) {
                      final isSel = selectedIcon == (i + 1);
                      return InkWell(
                        onTap: () {
                          setState(() => selectedIcon = i + 1);
                          _hideIconPicker();
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSel
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).dividerColor,
                              width: isSel ? 2 : 1,
                            ),
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                          ),
                          padding: const EdgeInsets.all(6),
                          child: _iconImage(paths[i], 44),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    overlay.insert(_iconPickerEntry!);
  }

  void _hideIconPicker() {
    _iconPickerEntry?.remove();
    _iconPickerEntry = null;
  }

  @override
  void dispose() {
    nameController.dispose();
    descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Vocabulary'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
                minLines: 1,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Icon',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  CompositedTransformTarget(
                    link: _iconLink,
                    child: InkWell(
                      onTap: _showIconPickerOverlay,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: _iconImage(
                            'assets/media/icons/new_dictionary/2.0x/$selectedIcon.png',
                            76,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tap the icon to choose',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop({
              'name': nameController.text.trim(),
              'description': descController.text.trim(),
              'icon':
                  'assets/media/icons/new_dictionary/${selectedIcon.toString()}.png',
            });
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _IconChip extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final Widget child;
  const _IconChip({
    required this.isSelected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).dividerColor,
              width: isSelected ? 2 : 1,
            ),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          padding: const EdgeInsets.all(3),
          child: Center(child: child),
        ),
      ),
    );
  }
}

Future<Map<String, String>?> showCreateVocabularyDialog(BuildContext context) {
  return showDialog<Map<String, String>?>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const CreateVocabularyDialog(),
  );
}
