import 'package:flutter/material.dart';

import 'tokens.dart';

/// Theme-aware semantic colors, exposed as a [ThemeExtension] so widgets read
/// one set of names (`context.cx.surface`, `context.cx.ember`, …) and get the
/// right value in light or dark automatically.
@immutable
class CxColorsExt extends ThemeExtension<CxColorsExt> {
  const CxColorsExt({
    required this.canvas,
    required this.surface,
    required this.surfaceHigh,
    required this.surfaceHighest,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.ember,
    required this.onEmber,
    required this.ultraviolet,
    required this.onUltraviolet,
    required this.lilac,
    required this.cream,
    required this.mint,
    required this.onPastel,
    required this.success,
    required this.warning,
    required this.danger,
    required this.onStatus,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceHigh;
  final Color surfaceHighest;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  final Color ember;
  final Color onEmber;
  final Color ultraviolet;
  final Color onUltraviolet;

  final Color lilac;
  final Color cream;
  final Color mint;
  final Color onPastel;

  final Color success;
  final Color warning;
  final Color danger;
  final Color onStatus;

  static const CxColorsExt dark = CxColorsExt(
    canvas: CxColors.darkCanvas,
    surface: CxColors.darkSurface,
    surfaceHigh: CxColors.darkSurfaceHigh,
    surfaceHighest: CxColors.darkSurfaceHighest,
    border: CxColors.darkBorder,
    textPrimary: CxColors.darkTextPrimary,
    textSecondary: CxColors.darkTextSecondary,
    textTertiary: CxColors.darkTextTertiary,
    ember: CxColors.ember,
    onEmber: Color(0xFF1B0E09),
    ultraviolet: CxColors.ultraviolet,
    onUltraviolet: Color(0xFF14102E),
    lilac: CxColors.lilac,
    cream: CxColors.cream,
    mint: CxColors.mint,
    onPastel: CxColors.pastelInk,
    success: CxColors.success,
    warning: CxColors.warning,
    danger: CxColors.danger,
    onStatus: Color(0xFF121114),
  );

  static const CxColorsExt light = CxColorsExt(
    canvas: CxColors.lightCanvas,
    surface: CxColors.lightSurface,
    surfaceHigh: CxColors.lightSurfaceHigh,
    surfaceHighest: CxColors.lightSurfaceHighest,
    border: CxColors.lightBorder,
    textPrimary: CxColors.lightTextPrimary,
    textSecondary: CxColors.lightTextSecondary,
    textTertiary: CxColors.lightTextTertiary,
    ember: CxColors.ember,
    onEmber: Color(0xFFFFFFFF),
    ultraviolet: CxColors.ultravioletDim,
    onUltraviolet: Color(0xFFFFFFFF),
    lilac: CxColors.lilac,
    cream: CxColors.cream,
    mint: CxColors.mint,
    onPastel: CxColors.pastelInk,
    success: CxColors.successDim,
    warning: CxColors.warningDim,
    danger: CxColors.dangerDim,
    onStatus: Color(0xFFFFFFFF),
  );

  @override
  CxColorsExt copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceHigh,
    Color? surfaceHighest,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? ember,
    Color? onEmber,
    Color? ultraviolet,
    Color? onUltraviolet,
    Color? lilac,
    Color? cream,
    Color? mint,
    Color? onPastel,
    Color? success,
    Color? warning,
    Color? danger,
    Color? onStatus,
  }) {
    return CxColorsExt(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      surfaceHighest: surfaceHighest ?? this.surfaceHighest,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      ember: ember ?? this.ember,
      onEmber: onEmber ?? this.onEmber,
      ultraviolet: ultraviolet ?? this.ultraviolet,
      onUltraviolet: onUltraviolet ?? this.onUltraviolet,
      lilac: lilac ?? this.lilac,
      cream: cream ?? this.cream,
      mint: mint ?? this.mint,
      onPastel: onPastel ?? this.onPastel,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      onStatus: onStatus ?? this.onStatus,
    );
  }

  @override
  CxColorsExt lerp(ThemeExtension<CxColorsExt>? other, double t) {
    if (other is! CxColorsExt) return this;
    return CxColorsExt(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      surfaceHighest: Color.lerp(surfaceHighest, other.surfaceHighest, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      ember: Color.lerp(ember, other.ember, t)!,
      onEmber: Color.lerp(onEmber, other.onEmber, t)!,
      ultraviolet: Color.lerp(ultraviolet, other.ultraviolet, t)!,
      onUltraviolet: Color.lerp(onUltraviolet, other.onUltraviolet, t)!,
      lilac: Color.lerp(lilac, other.lilac, t)!,
      cream: Color.lerp(cream, other.cream, t)!,
      mint: Color.lerp(mint, other.mint, t)!,
      onPastel: Color.lerp(onPastel, other.onPastel, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      onStatus: Color.lerp(onStatus, other.onStatus, t)!,
    );
  }
}

/// Convenient access to Crux semantic colors from a [BuildContext].
extension CxThemeContext on BuildContext {
  CxColorsExt get cx =>
      Theme.of(this).extension<CxColorsExt>() ?? CxColorsExt.dark;
}

/// Builds the light and dark [ThemeData] from the shared tokens.
abstract final class CxTheme {
  static ThemeData get dark => _build(Brightness.dark, CxColorsExt.dark);
  static ThemeData get light => _build(Brightness.light, CxColorsExt.light);

  static ThemeData _build(Brightness brightness, CxColorsExt c) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: c.ember,
      onPrimary: c.onEmber,
      secondary: c.ultraviolet,
      onSecondary: c.onUltraviolet,
      error: c.danger,
      onError: c.onStatus,
      surface: c.surface,
      onSurface: c.textPrimary,
      surfaceContainerHighest: c.surfaceHighest,
      outline: c.border,
    );

    final textTheme = _textTheme(c.textPrimary);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: c.canvas,
      canvasColor: c.canvas,
      fontFamily: CxFonts.body,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      extensions: <ThemeExtension<dynamic>>[c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: CxType.headline.copyWith(color: c.textPrimary),
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      dividerTheme: DividerThemeData(
        color: c.border,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: c.textSecondary),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surfaceHighest,
        contentTextStyle: CxType.bodySmall.copyWith(color: c.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: CxRadii.brMd),
      ),
    );
  }

  static TextTheme _textTheme(Color color) {
    TextStyle s(TextStyle t) => t.copyWith(color: color);
    return TextTheme(
      displayLarge: s(CxType.displayXL),
      displayMedium: s(CxType.displayL),
      headlineMedium: s(CxType.headline),
      titleLarge: s(CxType.title),
      titleMedium: s(CxType.titleSmall),
      bodyLarge: s(CxType.body),
      bodyMedium: s(CxType.bodySmall),
      labelLarge: s(CxType.label),
      labelMedium: s(CxType.caption),
      labelSmall: s(CxType.overline),
    );
  }
}
