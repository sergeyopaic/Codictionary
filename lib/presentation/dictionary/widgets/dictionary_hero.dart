import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';

/// Brand banner at the top of the dictionary with Cody and quick stats.
class DictionaryHero extends StatelessWidget {
  const DictionaryHero({
    super.key,
    required this.total,
    required this.explained,
    required this.compact,
  });

  final int total;
  final int explained;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // In dark mode the bright primary would look washed out; use the deeper
    // container tones instead.
    final dark = theme.brightness == Brightness.dark;
    final fg = dark ? scheme.onPrimaryContainer : scheme.onPrimary;
    final start = dark ? scheme.primaryContainer : scheme.primary;
    final end = dark
        ? Color.lerp(scheme.primaryContainer, scheme.secondaryContainer, 0.6)!
        : Color.lerp(scheme.primary, scheme.secondary, 0.45)!;
    final height = compact ? 148.0 : 176.0;
    final codyHeight = compact ? 158.0 : 190.0;
    // Gap between Cody's feet and the bottom edge of the banner.
    final feetGap = compact ? 10.0 : 12.0;

    final title = total == 0
        ? 'Let\'s build your dictionary'
        : total == 1
        ? '1 word and counting'
        : '$total words and counting';

    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [start, end],
        ),
      ),
      child: Stack(
        children: [
          // Soft decorative shapes for depth.
          Positioned(
            right: -60,
            top: -80,
            child: _Blob(size: 260, color: fg.withValues(alpha: 0.08)),
          ),
          Positioned(
            right: compact ? 40 : 140,
            bottom: -90,
            child: _Blob(size: 180, color: fg.withValues(alpha: 0.06)),
          ),
          Positioned(
            right: compact ? 4 : AppSpacing.xxl,
            bottom: feetGap - codyHeight * CodyArt.standingBottomMargin,
            child: Image.asset(
              CodyArt.standing,
              height: codyHeight,
              filterQuality: FilterQuality.high,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? AppSpacing.xl - 4 : AppSpacing.xxl,
              AppSpacing.lg,
              compact ? 120 : 220,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'YOUR DICTIONARY',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: fg.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      (compact
                              ? theme.textTheme.titleLarge
                              : theme.textTheme.headlineMedium)
                          ?.copyWith(color: fg, height: 1.15),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _StatPill(
                      icon: Icons.auto_awesome_rounded,
                      label: '$explained explained by AI',
                      color: fg,
                    ),
                    if (!compact)
                      _StatPill(
                        icon: Icons.translate_rounded,
                        label: 'English → Russian',
                        color: fg,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
