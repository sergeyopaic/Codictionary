import 'package:flutter/material.dart';

import '../../../domain/entities/word_entity.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/word_card_menu.dart';

/// A single dictionary entry in the grid.
class WordCard extends StatefulWidget {
  const WordCard({
    super.key,
    required this.word,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onToggleSelect,
    required this.onExplain,
    required this.onEdit,
    required this.onDelete,
  });

  final WordEntity word;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onToggleSelect;
  final VoidCallback onExplain;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<WordCard> createState() => _WordCardState();
}

class _WordCardState extends State<WordCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final word = widget.word;
    final selected = widget.selectionMode && widget.selected;
    final lifted = _hovered && !widget.selectionMode;

    final borderColor = selected
        ? scheme.primary
        : lifted
        ? scheme.primary.withValues(alpha: 0.4)
        : scheme.outlineVariant;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppMotion.medium,
        curve: AppMotion.emphasized,
        transform: Matrix4.translationValues(0, lifted ? -3 : 0, 0),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer.withValues(alpha: 0.45)
              : scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: borderColor, width: selected ? 2 : 1),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: lifted ? 0.10 : 0.03),
              blurRadius: lifted ? 24 : 8,
              offset: Offset(0, lifted ? 10 : 2),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: widget.selectionMode ? widget.onToggleSelect : widget.onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg + 2,
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          word.source,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      _buildTrailing(scheme),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.md),
                    child: Text(
                      word.target.isEmpty ? '—' : word.target,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: scheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.md),
                    child: _DescriptionPreview(desc: word.shortExplanation),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrailing(ColorScheme scheme) {
    if (widget.selectionMode) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.selected ? scheme.primary : Colors.transparent,
            border: Border.all(
              color: widget.selected ? scheme.primary : scheme.outline,
              width: 2,
            ),
          ),
          child: widget.selected
              ? Icon(Icons.check_rounded, size: 16, color: scheme.onPrimary)
              : null,
        ),
      );
    }
    return WordCardMenu(
      onExplain: widget.onExplain,
      onEdit: widget.onEdit,
      onDelete: widget.onDelete,
    );
  }
}

class _DescriptionPreview extends StatelessWidget {
  const _DescriptionPreview({required this.desc});

  final String? desc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasDesc = desc != null && desc!.trim().isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            Icons.auto_awesome_rounded,
            size: 14,
            color: hasDesc ? scheme.tertiary : scheme.outline,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            hasDesc ? desc!.trim() : 'No explanation yet — tap to generate',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
              fontStyle: hasDesc ? null : FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }
}
