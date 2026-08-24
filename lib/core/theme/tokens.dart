/// Crux design tokens — "Night Gym".
///
/// This file is the single source of truth for the visual language: colors,
/// type scale, spacing, radii, motion, shadows and haptics. Nothing here bakes
/// in theme-specific colors except the raw palette; theme-aware semantic colors
/// live in [CxColorsExt] (see `app_theme.dart`).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ---------------------------------------------------------------------------
// Fonts
// ---------------------------------------------------------------------------

/// Bundled font families (see `pubspec.yaml`).
abstract final class CxFonts {
  /// Display / hero face — General Sans (Fontshare) for modern and minimalist headings.
  static const String display = 'GeneralSans';

  /// Body & UI face — General Sans (Fontshare).
  static const String body = 'GeneralSans';

  /// Tabular-figure mono — JetBrains Mono. Used for every changing number so
  /// digits never jitter.
  static const String mono = 'JetBrainsMono';
}

// ---------------------------------------------------------------------------
// Raw palette
// ---------------------------------------------------------------------------

/// Raw, theme-agnostic brand colors. Prefer reading semantic colors from
/// [CxColorsExt] in widgets; use these only to build themes or for fixed brand
/// moments (e.g. the ember CTA, the PR celebration).
abstract final class CxColors {
  // -- Accents (shared across light + dark) --------------------------------

  /// Ember — CTAs, PRs, celebration. Warm, energetic, never alarming.
  static const Color ember = Color(0xFFFF5C39);
  static const Color emberBright = Color(0xFFFF7A5C);
  static const Color emberDim = Color(0xFFC9482B);

  /// Ultraviolet — progress, analytics, XP.
  static const Color ultraviolet = Color(0xFF9A8CFF);
  static const Color ultravioletBright = Color(0xFFB6ABFF);
  static const Color ultravioletDim = Color(0xFF6F62D6);

  // -- Pastel content cards (float on the dark canvas) ---------------------

  static const Color lilac = Color(0xFFD9CFF5);
  static const Color cream = Color(0xFFF3EDDF);
  static const Color mint = Color(0xFFCFE8D8);

  /// Ink used for text/icons on pastel cards.
  static const Color pastelInk = Color(0xFF1B1720);
  static const Color pastelInkSoft = Color(0xCC1B1720);

  // -- Dark theme ----------------------------------------------------------

  static const Color darkCanvas = Color(0xFF121114);
  static const Color darkSurface = Color(0xFF1C1B1F);
  static const Color darkSurfaceHigh = Color(0xFF26242B);
  static const Color darkSurfaceHighest = Color(0xFF322F38);
  static const Color darkBorder = Color(0xFF35323C);
  static const Color darkTextPrimary = Color(0xFFF4F1F7);
  static const Color darkTextSecondary = Color(0xFFB6B1C2);
  static const Color darkTextTertiary = Color(0xFF7E7A8A);

  // -- Light theme (derived from the same tokens) --------------------------

  static const Color lightCanvas = Color(0xFFF6F4F1);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceHigh = Color(0xFFEFEAF6);
  static const Color lightSurfaceHighest = Color(0xFFE6E0F0);
  static const Color lightBorder = Color(0xFFDBD5E2);
  static const Color lightTextPrimary = Color(0xFF1B1720);
  static const Color lightTextSecondary = Color(0xFF56515F);
  static const Color lightTextTertiary = Color(0xFF8A8494);

  // -- Semantic status (always paired with an icon/label in UI) ------------

  /// Positive / success. Distinct from a raw green — reads on both themes.
  static const Color success = Color(0xFF52C793);
  static const Color successDim = Color(0xFF2E8C63);

  /// Caution. Amber, never used as the sole signal.
  static const Color warning = Color(0xFFE8B84B);
  static const Color warningDim = Color(0xFFB88C22);

  /// Danger / destructive. Always accompanied by an icon and text.
  static const Color danger = Color(0xFFE5555B);
  static const Color dangerDim = Color(0xFFB23A40);
}

// ---------------------------------------------------------------------------
// Type scale
// ---------------------------------------------------------------------------

/// The Crux type scale. Styles are colorless by design — color is applied
/// by the active theme's [TextTheme] / [DefaultTextStyle], so the same tokens
/// work in light and dark.
abstract final class CxType {
  // Display face — Clash Display.
  static const TextStyle displayXL = TextStyle(
    fontFamily: CxFonts.display,
    fontWeight: FontWeight.w700,
    fontSize: 44,
    height: 1.04,
    letterSpacing: -0.5,
  );
  static const TextStyle displayL = TextStyle(
    fontFamily: CxFonts.display,
    fontWeight: FontWeight.w600,
    fontSize: 34,
    height: 1.06,
    letterSpacing: -0.3,
  );
  static const TextStyle headline = TextStyle(
    fontFamily: CxFonts.display,
    fontWeight: FontWeight.w600,
    fontSize: 26,
    height: 1.12,
    letterSpacing: -0.2,
  );

  // Body & UI face — General Sans.
  static const TextStyle title = TextStyle(
    fontFamily: CxFonts.body,
    fontWeight: FontWeight.w600,
    fontSize: 20,
    height: 1.25,
  );
  static const TextStyle titleSmall = TextStyle(
    fontFamily: CxFonts.body,
    fontWeight: FontWeight.w600,
    fontSize: 16,
    height: 1.3,
  );
  static const TextStyle body = TextStyle(
    fontFamily: CxFonts.body,
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 1.45,
  );
  static const TextStyle bodySmall = TextStyle(
    fontFamily: CxFonts.body,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 1.45,
  );
  static const TextStyle label = TextStyle(
    fontFamily: CxFonts.body,
    fontWeight: FontWeight.w500,
    fontSize: 14,
    height: 1.2,
  );
  static const TextStyle caption = TextStyle(
    fontFamily: CxFonts.body,
    fontWeight: FontWeight.w500,
    fontSize: 12,
    height: 1.25,
  );

  /// Uppercase eyebrow / section marker.
  static const TextStyle overline = TextStyle(
    fontFamily: CxFonts.body,
    fontWeight: FontWeight.w600,
    fontSize: 11,
    height: 1.2,
    letterSpacing: 1.4,
  );

  // Numerals — JetBrains Mono, tabular figures.
  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  /// Weight numerals on the logging screen (64–96pt range).
  static const TextStyle numHero = TextStyle(
    fontFamily: CxFonts.mono,
    fontWeight: FontWeight.w700,
    fontSize: 80,
    height: 1.0,
    letterSpacing: -2,
    fontFeatures: _tabular,
  );
  static const TextStyle numXL = TextStyle(
    fontFamily: CxFonts.mono,
    fontWeight: FontWeight.w500,
    fontSize: 48,
    height: 1.0,
    letterSpacing: -1,
    fontFeatures: _tabular,
  );
  static const TextStyle numL = TextStyle(
    fontFamily: CxFonts.mono,
    fontWeight: FontWeight.w500,
    fontSize: 32,
    height: 1.0,
    fontFeatures: _tabular,
  );

  /// Rest-timer readout.
  static const TextStyle timer = TextStyle(
    fontFamily: CxFonts.mono,
    fontWeight: FontWeight.w500,
    fontSize: 40,
    height: 1.0,
    fontFeatures: _tabular,
  );
  static const TextStyle numM = TextStyle(
    fontFamily: CxFonts.mono,
    fontWeight: FontWeight.w500,
    fontSize: 20,
    height: 1.1,
    fontFeatures: _tabular,
  );
  static const TextStyle numS = TextStyle(
    fontFamily: CxFonts.mono,
    fontWeight: FontWeight.w500,
    fontSize: 14,
    height: 1.1,
    fontFeatures: _tabular,
  );
}

// ---------------------------------------------------------------------------
// Spacing (4pt base)
// ---------------------------------------------------------------------------

/// Spacing scale on a 4pt grid. Generous by default.
abstract final class CxSpace {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double x2l = 24;
  static const double x3l = 32;
  static const double x4l = 40;
  static const double x5l = 56;
  static const double x6l = 72;

  /// Standard screen edge padding.
  static const double screen = 20;

  /// Minimum tap target (accessibility).
  static const double minTap = 56;
}

// ---------------------------------------------------------------------------
// Radii
// ---------------------------------------------------------------------------

/// Chunky corner radii — 20–24px on primary surfaces.
abstract final class CxRadii {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double x2l = 32;
  static const double pill = 999;

  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius brPill = BorderRadius.all(Radius.circular(pill));
}

// ---------------------------------------------------------------------------
// Motion
// ---------------------------------------------------------------------------

/// Durations. Transitions stay ≤250ms; the PR celebration is the sole
/// theatrical exception.
abstract final class CxDuration {
  static const Duration instant = Duration.zero;
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 180);
  static const Duration slow = Duration(milliseconds: 240);
  static const Duration counterRoll = Duration(milliseconds: 650);
  static const Duration celebration = Duration(milliseconds: 1800);
}

/// Purposeful curves with a subtle spring feel.
abstract final class CxCurves {
  /// Default for most transitions.
  static const Curve standard = Curves.easeOutCubic;

  /// Emphasized entrance (material-3 emphasized decelerate).
  static const Curve emphasized = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Springy overshoot for tactile selections & counter rolls.
  static const Curve spring = Curves.easeOutBack;

  /// Symmetric breathing (rest timer bar).
  static const Curve breathe = Curves.easeInOut;
}

// ---------------------------------------------------------------------------
// Shadows / elevation
// ---------------------------------------------------------------------------

/// Soft, low-contrast shadows. On dark, pastel cards get a warm ambient lift;
/// on light, a neutral drop shadow.
abstract final class CxShadows {
  static const List<BoxShadow> none = [];

  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 24,
      offset: Offset(0, 10),
      spreadRadius: -6,
    ),
  ];

  static const List<BoxShadow> floating = [
    BoxShadow(
      color: Color(0x4D000000),
      blurRadius: 40,
      offset: Offset(0, 18),
      spreadRadius: -8,
    ),
  ];
}

// ---------------------------------------------------------------------------
// Haptics
// ---------------------------------------------------------------------------

/// Named haptic events mapped to platform feedback. A single map so the whole
/// app speaks one tactile language; the PR celebration uses [prSlam] (bass).
enum CxHaptic {
  /// Discrete choice / stepper tick.
  selection,

  /// A set was logged — the core loop confirmation.
  logSet,

  /// Positive confirmation (quest claimed, weigh-in saved).
  success,

  /// Something needs attention (missed target, validation).
  warning,

  /// The PR celebration bass hit.
  prSlam,
}

/// Fires platform haptics for a named [CxHaptic] event.
abstract final class CxHaptics {
  static Future<void> fire(CxHaptic event) {
    switch (event) {
      case CxHaptic.selection:
        return HapticFeedback.selectionClick();
      case CxHaptic.logSet:
        return HapticFeedback.mediumImpact();
      case CxHaptic.success:
        return HapticFeedback.lightImpact();
      case CxHaptic.warning:
        return HapticFeedback.vibrate();
      case CxHaptic.prSlam:
        return HapticFeedback.heavyImpact();
    }
  }
}
