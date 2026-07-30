import 'package:flutter/material.dart' show TextTheme;
import 'package:flutter/widgets.dart';

import 'av_colors.dart';

/// Type system.
///
/// Archivo carries display and heading weight because its sturdy, slightly
/// condensed forms suit large numerals on a scoreboard-style layout. Inter
/// handles everything conversational. Numeric readouts always use tabular
/// figures so values do not shift width while a session is running.
abstract final class AvType {
  static const display = 'Archivo';
  static const text = 'Inter';

  static const _tabular = <FontFeature>[
    FontFeature.tabularFigures(),
    FontFeature.slashedZero(),
  ];

  static const heroMetric = TextStyle(
    fontFamily: display,
    fontSize: 52,
    height: 1.0,
    fontWeight: FontWeight.w800,
    letterSpacing: -2.2,
    fontFeatures: _tabular,
  );

  static const displayLarge = TextStyle(
    fontFamily: display,
    fontSize: 38,
    height: 1.04,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.4,
  );

  static const displayMedium = TextStyle(
    fontFamily: display,
    fontSize: 30,
    height: 1.08,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
  );

  static const headingLarge = TextStyle(
    fontFamily: display,
    fontSize: 24,
    height: 1.16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
  );

  static const headingMedium = TextStyle(
    fontFamily: display,
    fontSize: 19,
    height: 1.22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.35,
  );

  static const headingSmall = TextStyle(
    fontFamily: display,
    fontSize: 16,
    height: 1.28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  static const titleMedium = TextStyle(
    fontFamily: text,
    fontSize: 15,
    height: 1.32,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
  );

  static const titleSmall = TextStyle(
    fontFamily: text,
    fontSize: 13.5,
    height: 1.32,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.05,
  );

  static const body = TextStyle(
    fontFamily: text,
    fontSize: 15,
    height: 1.5,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.05,
  );

  static const bodySmall = TextStyle(
    fontFamily: text,
    fontSize: 13.5,
    height: 1.48,
    fontWeight: FontWeight.w400,
  );

  static const caption = TextStyle(
    fontFamily: text,
    fontSize: 12,
    height: 1.38,
    fontWeight: FontWeight.w500,
  );

  static const label = TextStyle(
    fontFamily: text,
    fontSize: 12.5,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  static const overline = TextStyle(
    fontFamily: text,
    fontSize: 10.5,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
  );

  /// Large scoreboard figure.
  static const metricLarge = TextStyle(
    fontFamily: display,
    fontSize: 32,
    height: 1.0,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.2,
    fontFeatures: _tabular,
  );

  static const metricMedium = TextStyle(
    fontFamily: display,
    fontSize: 22,
    height: 1.0,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.7,
    fontFeatures: _tabular,
  );

  static const metricSmall = TextStyle(
    fontFamily: text,
    fontSize: 14,
    height: 1.1,
    fontWeight: FontWeight.w600,
    fontFeatures: _tabular,
  );

  /// Applies tabular figures to any style carrying numbers in a table.
  static TextStyle tabular(TextStyle base) =>
      base.copyWith(fontFeatures: _tabular);

  static const TextTheme textTheme = TextTheme(
    displayLarge: displayLarge,
    displayMedium: displayMedium,
    displaySmall: headingLarge,
    headlineLarge: headingLarge,
    headlineMedium: headingMedium,
    headlineSmall: headingSmall,
    titleLarge: headingSmall,
    titleMedium: titleMedium,
    titleSmall: titleSmall,
    bodyLarge: body,
    bodyMedium: bodySmall,
    bodySmall: caption,
    labelLarge: label,
    labelMedium: label,
    labelSmall: overline,
  );
}

/// Convenience colour helpers so screens read as `AvType.body.on(...)`.
extension AvTextStyleX on TextStyle {
  TextStyle on(Color color) => copyWith(color: color);
  TextStyle get primary => copyWith(color: AvColors.textPrimary);
  TextStyle get secondary => copyWith(color: AvColors.textSecondary);
  TextStyle get muted => copyWith(color: AvColors.textMuted);
  TextStyle get faint => copyWith(color: AvColors.textFaint);
  TextStyle get onInk => copyWith(color: AvColors.textOnInk);
  TextStyle get onInkMuted => copyWith(color: AvColors.textOnInkMuted);
}
