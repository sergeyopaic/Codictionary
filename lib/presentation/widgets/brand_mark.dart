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
    final imageHeight = size / CodyArt.standingBustHeight;
    final imageWidth = imageHeight * CodyArt.standingAspect;
    // The figure is not centered in the PNG; move the head to the middle.
    final shiftX = (0.5 - CodyArt.standingHeadCenterX) * imageWidth;
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
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Frame the head and shoulders: the visible window spans from just
          // above the ears to the top of the shirt.
          Positioned(
            left: (size - imageWidth) / 2 + shiftX,
            top: -CodyArt.standingHeadTop * imageHeight,
            width: imageWidth,
            height: imageHeight,
            child: Image.asset(
              // Decorative: a text next to it says the same.
              excludeFromSemantics: true,

              CodyArt.standing,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.high,
            ),
          ),
        ],
      ),
    );
  }
}
