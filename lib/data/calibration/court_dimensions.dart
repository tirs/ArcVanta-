/// Fixed real-world dimensions the calibration solves against.
///
/// Every metric the product reports in centimetres or metres traces back to
/// one of these. The rim is the anchor: it is the only object in a gym that is
/// a known size, a known height and a circle, which is what makes a single
/// camera enough to recover scale.
///
/// Values are the FIBA and NBA figures, which agree on rim and backboard.
abstract final class CourtDimensions {
  /// Inner diameter of the ring, 18 inches.
  static const double rimDiameterM = 0.4572;

  static const double rimRadiusM = rimDiameterM / 2;

  /// Top of the ring above the floor, 10 feet.
  static const double rimHeightM = 3.048;

  /// The ring is mounted this far out from the face of the backboard,
  /// measured to the near edge of the ring.
  static const double rimOffsetFromBackboardM = 0.151;

  /// Backboard face, 72 by 42 inches.
  static const double backboardWidthM = 1.8288;
  static const double backboardHeightM = 1.0668;

  /// Bottom edge of the backboard above the floor.
  static const double backboardBottomHeightM = 2.9083;

  /// The painted inner rectangle, 24 by 18 inches.
  static const double backboardInnerWidthM = 0.6096;
  static const double backboardInnerHeightM = 0.4572;

  /// Free-throw line to the face of the backboard.
  static const double freeThrowToBackboardM = 4.572;

  /// Three-point arc radius, measured from the centre of the ring.
  static const double threePointRadiusFibaM = 6.75;
  static const double threePointRadiusNbaM = 7.239;

  /// A regulation ball, size 7. Used as a secondary scale check and to convert
  /// ball centre travel into metres near the rim plane.
  static const double ballDiameterM = 0.2429;

  static const double ballRadiusM = ballDiameterM / 2;

  /// How far the solved rim height may drift from [rimHeightM] before the
  /// solve is treated as wrong rather than merely noisy. Portable and
  /// driveway hoops are genuinely set low, so this is a plausibility band and
  /// not a tolerance on the measurement.
  static const double rimHeightToleranceM = 0.35;
}
