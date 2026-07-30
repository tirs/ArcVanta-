import 'package:flutter/material.dart';

import '../../core/theme/av_colors.dart';

/// Final reliability level attached to every measurement and event.
///
/// The scope requires that low-confidence values never drive authoritative
/// coaching, never enter verified leaderboards and never render with misleading
/// decimal precision. Those rules are enforced through this type rather than at
/// each call site.
enum ConfidenceLevel {
  high,
  medium,
  low,
  unavailable;

  String get label => switch (this) {
        ConfidenceLevel.high => 'High confidence',
        ConfidenceLevel.medium => 'Medium confidence',
        ConfidenceLevel.low => 'Low confidence',
        ConfidenceLevel.unavailable => 'Not available',
      };

  String get shortLabel => switch (this) {
        ConfidenceLevel.high => 'High',
        ConfidenceLevel.medium => 'Medium',
        ConfidenceLevel.low => 'Low',
        ConfidenceLevel.unavailable => 'Unavailable',
      };

  /// Shape and glyph differ per level so the state is never carried by colour
  /// alone, as required by the accessibility specification.
  IconData get icon => switch (this) {
        ConfidenceLevel.high => Icons.verified_rounded,
        ConfidenceLevel.medium => Icons.change_history_rounded,
        ConfidenceLevel.low => Icons.error_outline_rounded,
        ConfidenceLevel.unavailable => Icons.remove_circle_outline_rounded,
      };

  Color get color => switch (this) {
        ConfidenceLevel.high => AvColors.made,
        ConfidenceLevel.medium => AvColors.caution,
        ConfidenceLevel.low => AvColors.miss,
        ConfidenceLevel.unavailable => AvColors.unavailable,
      };

  Color get softColor => switch (this) {
        ConfidenceLevel.high => AvColors.madeSoft,
        ConfidenceLevel.medium => AvColors.cautionSoft,
        ConfidenceLevel.low => AvColors.missSoft,
        ConfidenceLevel.unavailable => AvColors.unavailableSoft,
      };

  /// Whether the value may be presented as an authoritative measurement.
  bool get isAuthoritative =>
      this == ConfidenceLevel.high || this == ConfidenceLevel.medium;

  /// Number of decimals a value at this level may be rendered with.
  int get allowedDecimals => switch (this) {
        ConfidenceLevel.high => 1,
        ConfidenceLevel.medium => 0,
        ConfidenceLevel.low => 0,
        ConfidenceLevel.unavailable => 0,
      };

  String get explanation => switch (this) {
        ConfidenceLevel.high =>
          'Detection, tracking and calibration all met their thresholds for this measurement.',
        ConfidenceLevel.medium =>
          'The measurement is usable but one input was weaker than target. Treat small changes with care.',
        ConfidenceLevel.low =>
          'Tracking or calibration was insufficient. This value is shown for reference and is excluded from coaching and trends.',
        ConfidenceLevel.unavailable =>
          'This metric cannot be calculated from the current camera placement or calibration.',
      };

  static ConfidenceLevel fromScore(double score) {
    if (score >= 0.82) return ConfidenceLevel.high;
    if (score >= 0.62) return ConfidenceLevel.medium;
    if (score > 0) return ConfidenceLevel.low;
    return ConfidenceLevel.unavailable;
  }
}

/// Camera placements the analysis pipeline supports. Metric eligibility is a
/// function of placement, so it travels with every measurement definition.
enum CameraAngle {
  front,
  side,
  rear,
  diagonal;

  String get label => switch (this) {
        CameraAngle.front => 'Front',
        CameraAngle.side => 'Side',
        CameraAngle.rear => 'Rear',
        CameraAngle.diagonal => 'Diagonal',
      };

  String get description => switch (this) {
        CameraAngle.front =>
          'Facing the shooter from under the rim. Best for alignment, elbow flare and left-right deviation.',
        CameraAngle.side =>
          'Perpendicular to the shooting line. Best for release angle, arc, set point and knee flexion.',
        CameraAngle.rear =>
          'Behind the shooter toward the rim. Best for depth, entry angle and guide-hand separation.',
        CameraAngle.diagonal =>
          'Forty-five degrees off the shooting line. Balanced coverage with reduced precision on angle metrics.',
      };

  IconData get icon => switch (this) {
        CameraAngle.front => Icons.crop_portrait_rounded,
        CameraAngle.side => Icons.crop_16_9_rounded,
        CameraAngle.rear => Icons.flip_to_back_rounded,
        CameraAngle.diagonal => Icons.crop_rotate_rounded,
      };
}
