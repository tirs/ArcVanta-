import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'camera_intrinsics.dart';
import 'conic.dart';
import 'court_dimensions.dart';
import 'court_frame.dart';
import 'rim_pose.dart';

/// How the rim outline reached the solver.
enum RimObservationSource {
  /// From the detector, with no help from the athlete.
  detector,

  /// The athlete dragged across the ring because the detector could not find
  /// it. Trusted slightly less than a confident detection, but far more than
  /// no calibration at all.
  manual,
}

/// The ring as seen in one frame.
class RimObservation {
  const RimObservation({
    required this.ellipse,
    required this.source,
    this.detectorConfidence = 1,
    this.outlinePoints = const [],
  });

  /// Pixel-space ellipse of the ring.
  final EllipseParams ellipse;
  final RimObservationSource source;

  /// The detector's own score, 0 to 1. Manual marks pass 1.
  final double detectorConfidence;

  /// Points the ellipse was fitted from, when there were any. Used to measure
  /// how well the solved circle reprojects.
  final List<Vector2> outlinePoints;
}

/// The backboard as seen in one frame. Optional: without it the solver falls
/// back to assuming the board sits directly beyond the ring.
class BackboardObservation {
  const BackboardObservation({
    required this.centre,
    required this.widthPx,
    required this.heightPx,
    this.detectorConfidence = 1,
  });

  final Vector2 centre;
  final double widthPx;
  final double heightPx;
  final double detectorConfidence;
}

/// Per-frame telemetry the native layer measures but the geometry cannot.
class CaptureConditions {
  const CaptureConditions({
    this.meanLuma = 0.55,
    this.lumaClippedFraction = 0.02,
    this.motionPixelsPerFrame = 0.4,
    this.frameRate = 60,
    this.hasTripod = true,
  });

  /// Average scene brightness, 0 to 1.
  final double meanLuma;

  /// Fraction of pixels blown out or crushed, which is what actually ruins
  /// tracking under gym lighting.
  final double lumaClippedFraction;

  /// How far static scene features drift between frames. A tripod is near
  /// zero; a propped phone is not.
  final double motionPixelsPerFrame;

  final int frameRate;
  final bool hasTripod;
}

/// One named component of the calibration score.
class CalibrationFactor {
  const CalibrationFactor({
    required this.label,
    required this.score,
    required this.detail,
  });

  final String label;

  /// 0 to 1.
  final double score;

  /// Shown to the athlete. Says what was measured, not what was assumed.
  final String detail;
}

/// Why a solve failed, in terms the calibration screen can act on.
enum CalibrationFailure {
  noRim,
  rimTooSmall,
  degenerateEllipse,
  poseUnsolvable,
  implausibleGeometry,
}

/// The result of calibrating: either a usable frame or a reason it is not.
class CalibrationSolution {
  const CalibrationSolution.success({
    required this.frame,
    required this.factors,
    required this.reprojectionErrorPx,
    required this.rimHeightAssumed,
  }) : failure = null;

  const CalibrationSolution.failed(this.failure)
    : frame = null,
      factors = const [],
      reprojectionErrorPx = double.nan,
      rimHeightAssumed = true;

  final CourtFrame? frame;
  final List<CalibrationFactor> factors;

  /// RMS distance, in pixels, between the observed ring outline and the solved
  /// circle projected back into the image. The honest measure of whether the
  /// geometry actually explains what the camera saw.
  final double reprojectionErrorPx;

  /// True when the rim height came from the regulation constant rather than
  /// from a measurement. It always does today; the flag exists so the UI never
  /// claims otherwise.
  final bool rimHeightAssumed;

  final CalibrationFailure? failure;

  bool get isUsable => frame != null;

  /// Geometric mean of the factors, so one bad component drags the total down
  /// instead of being averaged away by four good ones.
  double get overall {
    if (factors.isEmpty) return 0;
    var product = 1.0;
    for (final factor in factors) {
      product *= factor.score.clamp(0.01, 1.0);
    }
    return math.pow(product, 1 / factors.length).toDouble();
  }
}

/// Turns what the camera saw into a measurement frame, and scores how much the
/// result should be trusted.
abstract final class CalibrationSolver {
  /// Below this the ring is too few pixels across for the ellipse fit to carry
  /// usable geometry.
  static const double _minRimSemiMajorPx = 12;

  static CalibrationSolution solve({
    required RimObservation? rim,
    required CameraIntrinsics intrinsics,
    BackboardObservation? backboard,
    CaptureConditions conditions = const CaptureConditions(),
    Vector3? gravity,
    double rimHeightM = CourtDimensions.rimHeightM,
  }) {
    if (rim == null) {
      return const CalibrationSolution.failed(CalibrationFailure.noRim);
    }
    if (rim.ellipse.semiMajor < _minRimSemiMajorPx) {
      return const CalibrationSolution.failed(CalibrationFailure.rimTooSmall);
    }
    if (rim.ellipse.semiMinor <= 0 || rim.ellipse.eccentricity > 0.995) {
      return const CalibrationSolution.failed(
        CalibrationFailure.degenerateEllipse,
      );
    }

    final pose = RimPoseSolver.solve(
      imageConic: Conic.fromEllipse(rim.ellipse),
      radiusM: CourtDimensions.rimRadiusM,
      intrinsics: intrinsics,
      // Gravity points down, so up is its negation.
      cameraUp: gravity == null ? null : -gravity,
    );
    if (pose == null) {
      return const CalibrationSolution.failed(
        CalibrationFailure.poseUnsolvable,
      );
    }

    final chosen = pose.chosen;
    if (chosen.centre.z < 1.0 || chosen.centre.z > 25.0) {
      return const CalibrationSolution.failed(
        CalibrationFailure.implausibleGeometry,
      );
    }

    final frame = CourtFrame(
      intrinsics: intrinsics,
      rimCentre: chosen.centre,
      up: chosen.normal,
      backAxis: _backAxis(
        rimCentre: chosen.centre,
        up: chosen.normal,
        intrinsics: intrinsics,
        backboard: backboard,
      ),
      rimHeightM: rimHeightM,
    );

    final reprojection = _reprojectionErrorPx(frame, rim);

    return CalibrationSolution.success(
      frame: frame,
      reprojectionErrorPx: reprojection,
      rimHeightAssumed: true,
      factors: [
        _courtPlaneFactor(pose, intrinsics, gravity),
        _rimFactor(rim, reprojection),
        _lightingFactor(conditions),
        _stabilityFactor(conditions),
        _framingFactor(frame, intrinsics),
      ],
    );
  }

  /// Direction from the ring towards the backboard, in the floor plane.
  ///
  /// With the board detected this comes from where it actually is. Without it,
  /// the board is assumed to lie directly away from the camera, which is true
  /// whenever the athlete is shooting towards it and is the only sane guess.
  static Vector3 _backAxis({
    required Vector3 rimCentre,
    required Vector3 up,
    required CameraIntrinsics intrinsics,
    BackboardObservation? backboard,
  }) {
    Vector3 flatten(Vector3 v) => v - up * up.dot(v);

    if (backboard != null) {
      // The board is above and behind the ring; its bearing from the camera is
      // enough to fix the horizontal direction.
      final bearing = intrinsics.rayThroughPixel(backboard.centre);
      final projected = flatten(bearing);
      if (projected.length > 1e-6) return projected.normalized();
    }

    final away = flatten(rimCentre);
    if (away.length > 1e-6) return away.normalized();
    return flatten(Vector3(0, 0, 1)).normalized();
  }

  static double _reprojectionErrorPx(CourtFrame frame, RimObservation rim) {
    final observed = rim.outlinePoints.isNotEmpty
        ? rim.outlinePoints
        : _sampleEllipse(rim.ellipse, 32);
    final projected = frame.projectRimOutline(samples: 96);
    if (projected.isEmpty || observed.isEmpty) return double.nan;

    var sum = 0.0;
    for (final point in observed) {
      var nearest = double.infinity;
      for (final candidate in projected) {
        final d = (candidate - point).length2;
        if (d < nearest) nearest = d;
      }
      sum += nearest;
    }
    return math.sqrt(sum / observed.length);
  }

  static List<Vector2> _sampleEllipse(EllipseParams e, int count) {
    final cos = math.cos(e.rotation);
    final sin = math.sin(e.rotation);
    return [
      for (var i = 0; i < count; i++)
        () {
          final t = 2 * math.pi * i / count;
          final x = e.semiMajor * math.cos(t);
          final y = e.semiMinor * math.sin(t);
          return Vector2(
            e.centre.x + x * cos - y * sin,
            e.centre.y + x * sin + y * cos,
          );
        }(),
    ];
  }

  static CalibrationFactor _courtPlaneFactor(
    RimPoseSolution pose,
    CameraIntrinsics intrinsics,
    Vector3? gravity,
  ) {
    // The two mirror solutions are told apart by gravity. Without it the
    // choice is a guess, and the wider they are apart the worse that guess is.
    var score = 1.0;
    if (gravity == null) {
      score *= (1 - pose.tiltSeparationDegrees / 90).clamp(0.45, 1.0);
    }
    if (!intrinsics.fromDevice) score *= 0.82;

    final detail = gravity == null
        ? 'Plane from rim ellipse, no gravity reference'
        : 'Plane locked to rim and gravity, '
              '${pose.chosen.distanceM.toStringAsFixed(1)} m out';

    return CalibrationFactor(
      label: 'Court plane',
      score: score.clamp(0.0, 1.0),
      detail: detail,
    );
  }

  static CalibrationFactor _rimFactor(
    RimObservation rim,
    double reprojectionPx,
  ) {
    // A bigger ring in the frame means a better conditioned solve.
    final sizeScore = (rim.ellipse.semiMajor / 60).clamp(0.35, 1.0);
    final fitScore = reprojectionPx.isNaN
        ? 0.6
        : (1 - reprojectionPx / 12).clamp(0.2, 1.0);
    final sourceScore = switch (rim.source) {
      RimObservationSource.detector => rim.detectorConfidence.clamp(0.3, 1.0),
      RimObservationSource.manual => 0.88,
    };

    final detail = switch (rim.source) {
      RimObservationSource.detector =>
        'Ring detected, reprojects to '
            '${reprojectionPx.toStringAsFixed(1)} px',
      RimObservationSource.manual => 'Ring marked by hand, reprojects to '
          '${reprojectionPx.toStringAsFixed(1)} px',
    };

    return CalibrationFactor(
      label: 'Rim reference',
      score: sizeScore * fitScore * sourceScore,
      detail: detail,
    );
  }

  static CalibrationFactor _lightingFactor(CaptureConditions conditions) {
    // Mid-grey is ideal; both ends of the range cost tracking.
    final exposure = 1 - ((conditions.meanLuma - 0.52).abs() / 0.45);
    final clipping = 1 - conditions.lumaClippedFraction * 4;
    final score = (exposure * clipping).clamp(0.0, 1.0);

    return CalibrationFactor(
      label: 'Lighting',
      score: score,
      detail: conditions.lumaClippedFraction > 0.08
          ? 'Strong highlights, some detail is clipped'
          : 'Exposure even across the shooting area',
    );
  }

  static CalibrationFactor _stabilityFactor(CaptureConditions conditions) {
    final drift = (1 - conditions.motionPixelsPerFrame / 6).clamp(0.0, 1.0);
    final rate = (conditions.frameRate / 60).clamp(0.4, 1.0);
    final mount = conditions.hasTripod ? 1.0 : 0.72;

    return CalibrationFactor(
      label: 'Stability',
      score: drift * rate * mount,
      detail: conditions.hasTripod
          ? 'Mount steady at ${conditions.frameRate} fps'
          : 'Handheld or propped, release height will be held back',
    );
  }

  static CalibrationFactor _framingFactor(
    CourtFrame frame,
    CameraIntrinsics intrinsics,
  ) {
    // The band worth checking is where the athlete will actually stand, which
    // depends on where the phone was put: probes at fixed distances would sit
    // behind the camera for a close placement.
    final cameraDepth = frame.toCourt(Vector3.zero()).depthM;
    final reach = cameraDepth.clamp(2.5, 8.0);

    final probes = <CourtPosition>[
      // Feet and head at the near and far ends of the shooting band.
      CourtPosition(lateralM: 0, depthM: reach * 0.35, heightM: 0),
      CourtPosition(lateralM: 0, depthM: reach * 0.35, heightM: 2.1),
      CourtPosition(lateralM: 0, depthM: reach * 0.65, heightM: 0),
      // Stepping across, at mid-body height.
      CourtPosition(lateralM: -1.6, depthM: reach * 0.5, heightM: 1.0),
      CourtPosition(lateralM: 1.6, depthM: reach * 0.5, heightM: 1.0),
      // Where the ball peaks over the ring.
      const CourtPosition(lateralM: 0, depthM: 0, heightM: 4.2),
    ];

    var inside = 0;
    for (final probe in probes) {
      final pixel = intrinsics.projectToPixel(frame.fromCourt(probe));
      if (pixel == null) continue;
      if (pixel.x >= 0 &&
          pixel.x < intrinsics.widthPx &&
          pixel.y >= 0 &&
          pixel.y < intrinsics.heightPx) {
        inside++;
      }
    }

    final score = inside / probes.length;
    return CalibrationFactor(
      label: 'Framing',
      score: score,
      detail: score >= 0.99
          ? 'Shooting area and rim both fit the frame'
          : 'Part of the shooting area falls outside the frame',
    );
  }
}
