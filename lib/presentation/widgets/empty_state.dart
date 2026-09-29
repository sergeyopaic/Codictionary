import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Centered illustration + message used when a list has nothing to show.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.image,
    required this.title,
    required this.message,
    this.action,
  });

  final String image;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 168,
                height: 168,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primaryContainer.withValues(alpha: 0.45),
                ),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: FractionalTranslation(
                  // The standing pose sits left of center in its PNG.
                  translation: image == CodyArt.standing
                      ? const Offset(
                          (0.5 - CodyArt.standingCenterX) *
                              CodyArt.standingAspect,
                          0,
                        )
                      : Offset.zero,
                  child: Image.asset(image, filterQuality: FilterQuality.high),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
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
              if (action != null) ...[
                const SizedBox(height: AppSpacing.xl),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
