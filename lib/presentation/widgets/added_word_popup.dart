import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Shows a transient, animated toast with a clapping Cody after adding a word.
Future<void> showWordAddedPopup(BuildContext context, {String? word}) async {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  final visible = ValueNotifier<bool>(true);
  final entry = OverlayEntry(
    builder: (context) => _AddedWordToast(visible: visible, word: word),
  );
  overlay.insert(entry);

  await Future<void>.delayed(const Duration(milliseconds: 3000));
  visible.value = false;
  await Future<void>.delayed(AppMotion.slow);
  try {
    entry.remove();
  } catch (_) {}
  visible.dispose();
}

class _AddedWordToast extends StatelessWidget {
  const _AddedWordToast({required this.visible, this.word});

  final ValueNotifier<bool> visible;
  final String? word;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final wide = AppBreakpoints.isWide(context);
    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: wide ? Alignment.bottomRight : Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.xl,
              bottom: wide ? 100 : 170,
            ),
            child: ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (context, shown, child) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: shown ? 1 : 0),
                  duration: AppMotion.slow,
                  curve: shown ? Curves.easeOutBack : Curves.easeInCubic,
                  builder: (context, t, child) => Opacity(
                    opacity: t.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, 24 * (1 - t)),
                      child: child,
                    ),
                  ),
                  child: child,
                );
              },
              child: Material(
                color: scheme.surfaceContainerLowest,
                elevation: 8,
                shadowColor: scheme.shadow.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  side: BorderSide(color: scheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.xl,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        child: Image.asset(
                          CodyArt.clap,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 240),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Word added!',
                              style: theme.textTheme.titleMedium,
                            ),
                            Text(
                              word == null
                                  ? 'Saved to your dictionary'
                                  : '"$word" is in your dictionary',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
