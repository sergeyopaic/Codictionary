import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'brand_mark.dart';

/// Top-of-page header: title, subtitle and optional trailing actions.
///
/// On narrow layouts (no sidebar) the brand mark is shown above the title so
/// the app keeps its identity.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wide = AppBreakpoints.isWide(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!wide) ...[
          const BrandMark(size: 36),
          const SizedBox(height: AppSpacing.lg),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: wide
                        ? theme.textTheme.headlineLarge
                        : theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.lg),
              trailing!,
            ],
          ],
        ),
      ],
    );
  }
}
