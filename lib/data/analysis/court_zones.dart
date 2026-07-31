import 'dart:math' as math;

import '../calibration/court_dimensions.dart';
import '../calibration/court_frame.dart';
import '../models/shot.dart';

/// Places a measured court position into one of the reporting zones.
///
/// Positions come from the calibration in metres from the point under the
/// ring, so the boundaries here are the real ones rather than fractions of a
/// diagram. Distances are measured to the centre of the ring, which is how the
/// three-point line is defined.
abstract final class CourtZones {
  /// Inside this of the ring, a shot is at the rim.
  static const double _restrictedRadiusM = 1.25;

  /// The lane is 4.9 m wide, so half of it either side of centre.
  static const double _laneHalfWidthM = 2.45;

  /// A corner three is one taken from below the break, near the baseline.
  static const double _cornerDepthM = 2.8;

  /// Either side of the free-throw line counts as being on it.
  static const double _freeThrowBandM = 0.9;

  static CourtZone fromPosition(
    CourtPosition position, {
    bool nbaLine = false,
  }) {
    final lateral = position.lateralM;
    final depth = position.depthM;
    final distance = math.sqrt(lateral * lateral + depth * depth);
    final threeRadius = nbaLine
        ? CourtDimensions.threePointRadiusNbaM
        : CourtDimensions.threePointRadiusFibaM;

    if (distance >= threeRadius) {
      if (depth <= _cornerDepthM) {
        return lateral < 0 ? CourtZone.leftCorner3 : CourtZone.rightCorner3;
      }
      // The top of the key is the band where the shot is more square than wide.
      if (lateral.abs() < depth * 0.55) return CourtZone.topKey3;
      return lateral < 0 ? CourtZone.leftWing3 : CourtZone.rightWing3;
    }

    if (distance <= _restrictedRadiusM) return CourtZone.restrictedArea;

    final freeThrowDepth = CourtDimensions.freeThrowToBackboardM -
        CourtDimensions.rimRadiusM -
        CourtDimensions.rimOffsetFromBackboardM;

    if (lateral.abs() <= _laneHalfWidthM) {
      if ((depth - freeThrowDepth).abs() <= _freeThrowBandM) {
        return CourtZone.freeThrow;
      }
      if (depth < freeThrowDepth) return CourtZone.paint;
      // Beyond the line but still square on: the closest zone is the elbow.
      return lateral < 0 ? CourtZone.leftElbow : CourtZone.rightElbow;
    }

    if (depth <= _cornerDepthM) {
      return lateral < 0
          ? CourtZone.leftBaselineMid
          : CourtZone.rightBaselineMid;
    }
    return lateral < 0 ? CourtZone.leftElbow : CourtZone.rightElbow;
  }
}
