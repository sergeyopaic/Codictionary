import 'package:flutter/material.dart';

/// Shows a transient, animated toast with clap GIF after adding a word.
Future<void> showWordAddedPopup(BuildContext context) async {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  late OverlayEntry entry;

  entry = OverlayEntry(builder: (context) => const _AddedWordToast());

  overlay.insert(entry);

  await Future<void>.delayed(const Duration(milliseconds: 3500));
  try {
    entry.remove();
  } catch (_) {}
}

class _AddedWordToast extends StatefulWidget {
  const _AddedWordToast();

  @override
  State<_AddedWordToast> createState() => _AddedWordToastState();
}

class _AddedWordToastState extends State<_AddedWordToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      reverseDuration: const Duration(milliseconds: 400),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 16, bottom: 84),
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                alignment: Alignment.bottomRight,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 260,
                    maxWidth: 360,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F9FA),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 14,
                        offset: Offset(0, 8),
                      ),
                    ],
                    border: Border.all(color: Colors.black12, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ClapUp GIF on the left
                      Image.asset(
                        'assets/media/clap_up.gif',
                        width: 64,
                        height: 64,
                        filterQuality: FilterQuality.high,
                      ),
                      const SizedBox(width: 12),
                      // Texts on the right
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Word added!',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'CodictionaryCartoon',
                                fontSize: 22,
                                height: 1.0,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Saved to your dictionary',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
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
