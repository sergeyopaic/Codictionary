import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../l10n/app_strings.dart';

const int _iconCount = 14;

String vocabIconPath(int i) => 'assets/media/icons/new_dictionary/$i.png';

/// Higher-resolution variant of a stored vocabulary icon path.
String vocabIconHiRes(String path) =>
    path.replaceFirst('/new_dictionary/', '/new_dictionary/3.0x/');

/// Dialog for creating or editing a vocabulary.
/// No persistence logic is included; caller reads the result and acts.
class CreateVocabularyDialog extends StatefulWidget {
  const CreateVocabularyDialog({
    super.key,
    this.initialName,
    this.initialDescription,
    this.initialIcon,
  });

  final String? initialName;
  final String? initialDescription;
  final String? initialIcon;

  @override
  State<CreateVocabularyDialog> createState() => _CreateVocabularyDialogState();
}

class _CreateVocabularyDialogState extends State<CreateVocabularyDialog> {
  late final TextEditingController nameController = TextEditingController(
    text: widget.initialName,
  );
  late final TextEditingController descController = TextEditingController(
    text: widget.initialDescription,
  );
  final _formKey = GlobalKey<FormState>();
  late int selectedIcon = _indexOf(widget.initialIcon);

  bool get _isEdit => widget.initialName != null;

  static int _indexOf(String? path) {
    if (path == null) return 1;
    final match = RegExp(r'(\d+)\.png$').firstMatch(path);
    final i = int.tryParse(match?.group(1) ?? '') ?? 1;
    return i.clamp(1, _iconCount);
  }

  @override
  void dispose() {
    nameController.dispose();
    descController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop({
      'name': nameController.text.trim(),
      'description': descController.text.trim(),
      'icon': vocabIconPath(selectedIcon),
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    AnimatedSwitcher(
                      duration: AppMotion.medium,
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: Container(
                        key: ValueKey(selectedIcon),
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Image.asset(
                          // Decorative: a text next to it says the same.
                          excludeFromSemantics: true,

                          vocabIconHiRes(vocabIconPath(selectedIcon)),
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEdit
                                ? context.s.editVocabulary
                                : context.s.newVocabulary,
                            style: theme.textTheme.headlineSmall,
                          ),
                          Text(
                            context.s.vocabDialogSubtitle,
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
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: context.s.name,
                    hintText: context.s.nameHint,
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return context.s.nameRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: descController,
                  decoration: InputDecoration(
                    labelText: context.s.descriptionOptional,
                  ),
                  minLines: 1,
                  maxLines: 3,
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(context.s.icon, style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (var i = 1; i <= _iconCount; i++)
                      _IconOption(
                        path: vocabIconHiRes(vocabIconPath(i)),
                        selected: i == selectedIcon,
                        onTap: () => setState(() => selectedIcon = i),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      child: Text(context.s.cancel),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    FilledButton(
                      onPressed: _submit,
                      child: Text(_isEdit ? context.s.save : context.s.create),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconOption extends StatelessWidget {
  const _IconOption({
    required this.path,
    required this.selected,
    required this.onTap,
  });

  final String path;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        width: 52,
        height: 52,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerHigh.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? scheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Image.asset(
          // Decorative: a text next to it says the same.
          excludeFromSemantics: true,

          path,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, _, _) =>
              const Icon(Icons.image_not_supported_outlined),
        ),
      ),
    );
  }
}

Future<Map<String, String>?> showCreateVocabularyDialog(
  BuildContext context, {
  String? initialName,
  String? initialDescription,
  String? initialIcon,
}) {
  return showDialog<Map<String, String>?>(
    context: context,
    barrierDismissible: true,
    builder: (_) => CreateVocabularyDialog(
      initialName: initialName,
      initialDescription: initialDescription,
      initialIcon: initialIcon,
    ),
  );
}
