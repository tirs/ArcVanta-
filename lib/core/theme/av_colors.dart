import 'package:flutter/widgets.dart';

/// ArcVanta AI colour system.
///
/// The palette is built around a warm daylight canvas rather than a near-black
/// surface, so metric colours stay legible in a bright gym and the product does
/// not read as another generic dark utility. Semantic roles are fixed: a colour
/// never means two different things across the product.
abstract final class AvColors {
  // ---------------------------------------------------------------- canvas --
  /// Warm bone canvas. Base of every scrollable surface.
  static const canvas = Color(0xFFF5F2EB);

  /// Slightly deeper canvas used for grouped/sunken regions.
  static const canvasSunken = Color(0xFFEDE8DD);

  /// Card and sheet surface.
  static const surface = Color(0xFFFFFFFF);

  /// Secondary surface for nested content inside a card.
  static const surfaceMuted = Color(0xFFFAF7F1);

  /// Tint used behind selected rows and hovered targets.
  static const surfaceSelected = Color(0xFFF1EDFF);

  // ------------------------------------------------------------------- ink --
  /// Deep midnight indigo. Primary dark panel and the brand anchor.
  static const ink = Color(0xFF17182F);
  static const inkElevated = Color(0xFF21233F);
  static const inkHairline = Color(0xFF2E3152);

  static const textPrimary = Color(0xFF191A26);
  static const textSecondary = Color(0xFF474758);
  static const textMuted = Color(0xFF6E6E82);
  static const textFaint = Color(0xFF9B9BAC);
  static const textOnInk = Color(0xFFF6F5FF);
  static const textOnInkMuted = Color(0xFFA9AAC8);

  static const hairline = Color(0xFFE4DED2);
  static const hairlineStrong = Color(0xFFD5CDBD);
  static const hairlineOnInk = Color(0xFF32355A);

  // ----------------------------------------------------------------- brand --
  /// Flare — the ball, the arc, the primary call to action.
  static const flare = Color(0xFFFF5B29);
  static const flareDeep = Color(0xFFE33F10);
  static const flareSoft = Color(0xFFFFE8DF);
  static const flareTint = Color(0xFFFFF3EE);

  /// Insight — AI coaching, generated explanations, personalisation.
  static const insight = Color(0xFF6C4CF1);
  static const insightDeep = Color(0xFF4C31C4);
  static const insightSoft = Color(0xFFEBE6FF);
  static const insightTint = Color(0xFFF5F2FF);

  /// Court — calibration, geometry, camera and court-line graphics.
  static const court = Color(0xFF00A6C0);
  static const courtDeep = Color(0xFF00788C);
  static const courtSoft = Color(0xFFDDF3F7);
  static const courtTint = Color(0xFFEEF9FB);

  // --------------------------------------------------------------- metrics --
  /// Verified make.
  static const made = Color(0xFF0E9F6E);
  static const madeDeep = Color(0xFF07724E);
  static const madeSoft = Color(0xFFDDF4EA);

  /// Miss.
  static const miss = Color(0xFFD8465C);
  static const missDeep = Color(0xFFA82438);
  static const missSoft = Color(0xFFFBE4E8);

  /// Uncertain result / caution / medium confidence.
  static const caution = Color(0xFFE0940E);
  static const cautionDeep = Color(0xFFA76A00);
  static const cautionSoft = Color(0xFFFCF0D9);

  /// Errors and destructive actions only.
  static const critical = Color(0xFFC42B44);
  static const criticalSoft = Color(0xFFFBE2E6);

  /// Neutral/unavailable metric state.
  static const unavailable = Color(0xFF8E8B9E);
  static const unavailableSoft = Color(0xFFEDEBF0);

  // ------------------------------------------------------- data visualisation
  /// Ordered series colours for charts. Chosen to stay separable for the most
  /// common forms of colour vision deficiency; charts also vary shape/label.
  static const series = <Color>[
    Color(0xFF6C4CF1),
    Color(0xFFFF5B29),
    Color(0xFF00A6C0),
    Color(0xFF0E9F6E),
    Color(0xFFE0940E),
    Color(0xFFD8465C),
  ];

  /// Heat ramp for the court map, cold to hot.
  static const heat = <Color>[
    Color(0xFFE7E3F6),
    Color(0xFFBFD9EC),
    Color(0xFF8FD3D2),
    Color(0xFF9FD98C),
    Color(0xFFF3C64F),
    Color(0xFFF08A3C),
    Color(0xFFE2492F),
  ];

  // ---------------------------------------------------------- camera overlay
  /// Scrim tones used above the live camera feed.
  static const scrimStrong = Color(0xE60E0F1C);
  static const scrimSoft = Color(0x990E0F1C);
  static const scrimHairline = Color(0x33FFFFFF);
  static const overlaySkeleton = Color(0xFF7BE8FF);
  static const overlayJoint = Color(0xFFFFFFFF);
  static const overlayBall = Color(0xFFFF7A3D);
  static const overlayHoop = Color(0xFF56E39F);
  static const overlayTrace = Color(0xFFFFC46B);
}
