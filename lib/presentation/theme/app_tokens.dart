import 'package:flutter/widgets.dart';

/// Spacing scale used across the app. Keep layouts on this 4pt grid.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner radii. Larger surfaces get larger radii.
abstract final class AppRadius {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
}

/// Motion durations and curves.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Curve emphasized = Curves.easeOutCubic;
}

/// Layout breakpoints.
abstract final class AppBreakpoints {
  /// From this width the app shows a persistent sidebar instead of a bottom bar.
  static const double wide = 900;

  /// Content never stretches wider than this.
  static const double maxContentWidth = 1400;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wide;
}

/// Asset paths for the Cody mascot illustrations.
abstract final class CodyArt {
  static const String standing = 'assets/media/CODY.png';
  static const String reading = 'assets/media/cody_info.png';
  static const String delete = 'assets/media/cody_delete.png';
  static const String clap = 'assets/media/clap_up.gif';

  // Geometry of [standing] as fractions of the image size. The figure is not
  // centered in the PNG (wide transparent margin on the right and bottom), so
  // layouts use these to align him precisely.
  static const double standingAspect = 2 / 3;
  static const double standingCenterX = 0.43;
  static const double standingBottomMargin = 0.115;
  static const double standingHeadCenterX = 0.475;
  static const double standingHeadTop = 0.07;

  /// Fraction of the image height from [standingHeadTop] to the shoulders.
  static const double standingBustHeight = 0.48;
}
