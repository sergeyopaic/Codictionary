import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Codictionary design system.
///
/// The palette is derived from the Cody mascot: forest green (his shirt) as
/// the primary brand color, acorn amber (his fur) as the secondary accent, and
/// a soft violet tertiary reserved for AI-generated content.
abstract final class AppTheme {
  static const String brandFont = 'CodictionaryCartoon';

  static const ColorScheme _light = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF2E7D4F),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFCDEBD6),
    onPrimaryContainer: Color(0xFF0B3A1F),
    secondary: Color(0xFFB85A24),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFFFE0CC),
    onSecondaryContainer: Color(0xFF4A1D05),
    tertiary: Color(0xFF6B58B5),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFE7E0FF),
    onTertiaryContainer: Color(0xFF22135C),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: Color(0xFFFBF8F4),
    onSurface: Color(0xFF1D1B18),
    onSurfaceVariant: Color(0xFF5E5A53),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF6F2EC),
    surfaceContainer: Color(0xFFF1ECE5),
    surfaceContainerHigh: Color(0xFFEBE5DD),
    surfaceContainerHighest: Color(0xFFE5DED5),
    outline: Color(0xFF857F75),
    outlineVariant: Color(0xFFE2DBD1),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF32302C),
    onInverseSurface: Color(0xFFF5F0E9),
    inversePrimary: Color(0xFF8AD5A3),
  );

  static const ColorScheme _dark = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF8AD5A3),
    onPrimary: Color(0xFF003919),
    primaryContainer: Color(0xFF1C5635),
    onPrimaryContainer: Color(0xFFC7F0D3),
    secondary: Color(0xFFFFB68C),
    onSecondary: Color(0xFF562000),
    secondaryContainer: Color(0xFF6E3413),
    onSecondaryContainer: Color(0xFFFFDBC8),
    tertiary: Color(0xFFCBBEFF),
    onTertiary: Color(0xFF33237A),
    tertiaryContainer: Color(0xFF4A3C92),
    onTertiaryContainer: Color(0xFFE7E0FF),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF141311),
    onSurface: Color(0xFFEAE5DE),
    onSurfaceVariant: Color(0xFFBDB6AB),
    surfaceContainerLowest: Color(0xFF0F0E0C),
    surfaceContainerLow: Color(0xFF1C1A17),
    surfaceContainer: Color(0xFF211F1C),
    surfaceContainerHigh: Color(0xFF2B2926),
    surfaceContainerHighest: Color(0xFF363330),
    outline: Color(0xFF8C857A),
    outlineVariant: Color(0xFF3D3A35),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFEAE5DE),
    onInverseSurface: Color(0xFF32302C),
    inversePrimary: Color(0xFF2E7D4F),
  );

  static ThemeData get light => _build(_light);
  static ThemeData get dark => _build(_dark);

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      brightness: scheme.brightness,
    );
    final text = _textTheme(base.textTheme, scheme);

    final roundedMd = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
    const buttonPadding = EdgeInsets.symmetric(
      horizontal: AppSpacing.xl,
      vertical: AppSpacing.lg,
    );
    final buttonText = text.labelLarge?.copyWith(fontWeight: FontWeight.w600);

    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        hintStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: buttonPadding,
          shape: const StadiumBorder(),
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: buttonPadding,
          shape: const StadiumBorder(),
          textStyle: buttonText,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: const StadiumBorder(),
          textStyle: buttonText,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(shape: roundedMd),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        focusElevation: 3,
        hoverElevation: 4,
        highlightElevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        extendedTextStyle: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
        extendedPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: scheme.primaryContainer,
          selectedForegroundColor: scheme.onPrimaryContainer,
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          visualDensity: VisualDensity.standard,
        ),
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerLowest),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        side: WidgetStateProperty.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.focused)
                ? scheme.primary
                : scheme.outlineVariant,
            width: states.contains(WidgetState.focused) ? 2 : 1,
          ),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        ),
        constraints: const BoxConstraints(minHeight: 52),
        hintStyle: WidgetStatePropertyAll(
          text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
        textStyle: WidgetStatePropertyAll(text.bodyLarge),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: text.labelLarge,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle: text.headlineSmall,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        shape: roundedMd,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        width: null,
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerLow),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(8),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: AppSpacing.sm),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              side: BorderSide(color: scheme.outlineVariant),
            ),
          ),
        ),
      ),
      menuButtonTheme: MenuButtonThemeData(
        style: MenuItemButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          minimumSize: const Size(200, 44),
          textStyle: text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: text.bodySmall?.copyWith(color: scheme.onInverseSurface),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      switchTheme: SwitchThemeData(
        thumbIcon: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const Icon(Icons.check_rounded)
              : null,
        ),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, ColorScheme scheme) {
    final t = base.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    return t.copyWith(
      displaySmall: t.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
      ),
      headlineLarge: t.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
      ),
      headlineMedium: t.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
      ),
      headlineSmall: t.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleLarge: t.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: t.labelLarge?.copyWith(letterSpacing: 0.1),
      bodyLarge: t.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: t.bodyMedium?.copyWith(height: 1.45),
    );
  }
}
