import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

/// Cody avatar + "Codictionary" wordmark.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40});

  /// Diameter of the avatar; the wordmark scales with it.
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CodyAvatar(size: size),
        SizedBox(width: size * 0.3),
        Flexible(
          child: Text(
            'Codictionary',
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: TextStyle(
              fontFamily: AppTheme.brandFont,
              fontSize: size * 0.5,
              height: 1.1,
              letterSpacing: 0.6,
              color: scheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Circular badge with Cody's head peeking out.
class CodyAvatar extends StatelessWidget {
  const CodyAvatar({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.secondaryContainer, scheme.primaryContainer],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: OverflowBox(
        maxHeight: size * 1.9,
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: size * 0.1),
          child: Image.asset(
            CodyArt.standing,
            height: size * 1.9,
            fit: BoxFit.fitHeight,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
