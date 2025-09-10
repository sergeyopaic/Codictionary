import 'package:flutter/material.dart';

/// Overflow menu (three dots) for card actions: explain, edit, delete.
class WordCardMenu extends StatefulWidget {
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
  State<WordCardMenu> createState() => _WordCardMenuState();
}

class _WordCardMenuState extends State<WordCardMenu>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _entry;
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  static const double _menuWidth = 220;
  static const double _menuHeightEstimate = 180;
  static const double _screenPadding = 8;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.02),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _removeEntry(immediate: true);
    _controller.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    if (_entry != null) {
      _removeEntry();
    } else {
      _showEntry();
    }
  }

  void _showEntry() {
    final overlay =
        Overlay.of(context, rootOverlay: true) ?? Overlay.of(context);
    if (overlay == null) return;

    final overlaySize = MediaQuery.of(context).size;
    final targetBox = context.findRenderObject() as RenderBox?;
    if (targetBox == null) return;
    final targetTopLeft = targetBox.localToGlobal(Offset.zero);
    final targetBottomRight = targetBox.localToGlobal(
      targetBox.size.bottomRight(Offset.zero),
    );

    double dx =
        targetBottomRight.dx - _menuWidth; // right-align to button right
    double dy = targetBottomRight.dy + 8; // show below by default

    if (dx < _screenPadding) dx = _screenPadding;
    if (dx + _menuWidth > overlaySize.width - _screenPadding) {
      dx = overlaySize.width - _screenPadding - _menuWidth;
    }

    // Prevent bottom overflow using height estimate; if overflow, shift up.
    final overflowBottom =
        (dy + _menuHeightEstimate) - (overlaySize.height - _screenPadding);
    if (overflowBottom > 0) {
      dy -= overflowBottom;
    }
    if (dy < _screenPadding) dy = _screenPadding;

    final entry = OverlayEntry(
      builder: (context) {
        return SizedBox.expand(
          child: Stack(
            children: [
              // Barrier to close on outside tap
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _removeEntry,
                ),
              ),
              Positioned(
                left: dx,
                top: dy,
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: ScaleTransition(
                      scale: _scale,
                      alignment: Alignment.topRight,
                      child: _MenuCard(
                        width: _menuWidth,
                        onExplain: () {
                          _removeEntry();
                          widget.onExplain();
                        },
                        onEdit: () {
                          _removeEntry();
                          widget.onEdit();
                        },
                        onDelete: () {
                          _removeEntry();
                          widget.onDelete();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    _entry = entry;
    try {
      overlay.insert(entry);
    } catch (_) {
      // If insertion fails due to timing, drop the entry safely
      _entry = null;
      return;
    }
    _controller.forward();
  }

  void _removeEntry({bool immediate = false}) async {
    final entry = _entry;
    if (entry == null) return;
    _entry = null;
    if (immediate) {
      entry.remove();
      return;
    }
    try {
      await _controller.reverse();
    } finally {
      entry.remove();
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'More options',
      icon: const Icon(Icons.more_vert),
      onPressed: _toggleMenu,
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.width,
    required this.onExplain,
    required this.onEdit,
    required this.onDelete,
  });

  final double width;
  final VoidCallback onExplain;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MenuItem(
              icon: Icons.remove_red_eye,
              color: theme.colorScheme.primary,
              text: 'Extended info',
              onTap: onExplain,
            ),
            const Divider(height: 1),
            _MenuItem(
              icon: Icons.edit,
              color: theme.colorScheme.secondary,
              text: 'Edit word',
              onTap: onEdit,
            ),
            const Divider(height: 1),
            _MenuItem(
              icon: Icons.delete,
              color: theme.colorScheme.error,
              text: 'Delete',
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.color,
    required this.text,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
