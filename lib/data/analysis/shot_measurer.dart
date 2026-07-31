import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import '../calibration/court_dimensions.dart';
import '../calibration/court_frame.dart';
import '../models/pose.dart';

/// Standard gravity. The flight fit holds this fixed rather than solving for
/// it, which turns a three-parameter curve fit into a two-parameter one and
/// makes short, noisy trajectories usable.
const double _g = 9.80665;

/// One observation of the ball, already lifted into court coordinates.
class BallSample {
  const BallSample({
    required this.timeMs,
    required this.position,
    this.confidence = 1,
  });

  final int timeMs;
  final CourtPosition position;
  final double confidence;
}

/// What a single flight measures out to.
class FlightMeasurement {
  const FlightMeasurement({
    required this.releaseAngleDeg,
    required this.entryAngleDeg,
    required this.releaseHeightM,
    required this.apexHeightM,
    required this.releaseSpeedMs,
    required this.flightTimeMs,
    required this.releaseDistanceM,
    required this.residualM,
    required this.sampleCount,
  });

  final double releaseAngleDeg;

  /// Angle below horizontal as the ball crosses the ring. The single number
  /// most correlated with whether a shot goes in; the coaching range is 43 to
  /// 50 degrees.
  final double entryAngleDeg;

  final double releaseHeightM;
  final double apexHeightM;
  final double releaseSpeedMs;
  final int flightTimeMs;

  /// Ground distance from the shooter's release point to the ring.
  final double releaseDistanceM;

  /// RMS distance between the observed ball positions and the fitted
  /// trajectory. The evidence for how much any of the above is worth.
  final double residualM;

  final int sampleCount;

  /// Turns fit quality into the 0-to-1 score the confidence grading consumes.
  ///
  /// Two centimetres of residual over a dozen samples is a clean flight; ten
  /// is a trajectory the fit does not explain, and nothing derived from it
  /// should be shown at full precision.
  double get evidence {
    final fit = (1 - (residualM - 0.02) / 0.10).clamp(0.0, 1.0);
    final coverage = (sampleCount / 12).clamp(0.0, 1.0);
    return fit * coverage;
  }
}

/// Turns tracked geometry into the numbers the product reports.
///
/// Everything here is ordinary projectile motion and planar trigonometry. It
/// lives in Dart rather than in either native bridge so there is one
/// implementation to be right, and so it can be tested against synthetic
/// flights where the answer is known.
abstract final class ShotMeasurer {
  /// Fewer than this and the fit is interpolation dressed up as measurement.
  static const int minimumSamples = 5;

  /// Fits a flight to ball samples taken between release and the ring.
  ///
  /// Returns null when there is not enough of the flight to say anything,
  /// which is a better answer than a number with no support behind it.
  static FlightMeasurement? measureFlight(List<BallSample> samples) {
    if (samples.length < minimumSamples) return null;

    final ordered = [...samples]..sort((a, b) => a.timeMs.compareTo(b.timeMs));
    final t0 = ordered.first.timeMs;

    // Horizontal distance travelled from the release point, which is what the
    // ball's speed acts along.
    final origin = ordered.first.position;
    final heading = Vector2(
      ordered.last.position.lateralM - origin.lateralM,
      ordered.last.position.depthM - origin.depthM,
    );
    if (heading.length < 0.5) return null;
    final unit = heading.normalized();

    final times = <double>[];
    final grounds = <double>[];
    final heights = <double>[];
    for (final sample in ordered) {
      times.add((sample.timeMs - t0) / 1000);
      grounds.add(
        (sample.position.lateralM - origin.lateralM) * unit.x +
            (sample.position.depthM - origin.depthM) * unit.y,
      );
      heights.add(sample.position.heightM);
    }

    // Horizontal motion is uniform.
    final horizontal = _fitLine(times, grounds);
    if (horizontal == null) return null;
    final speedGround = horizontal.slope;
    if (speedGround <= 0.1) return null;

    // Vertical motion is uniform once the known gravity term is subtracted,
    // so the same linear fit does both.
    final lifted = [
      for (var i = 0; i < times.length; i++)
        heights[i] + 0.5 * _g * times[i] * times[i],
    ];
    final vertical = _fitLine(times, lifted);
    if (vertical == null) return null;

    final h0 = vertical.intercept;
    final vz = vertical.slope;

    var squared = 0.0;
    for (var i = 0; i < times.length; i++) {
      final t = times[i];
      final modelGround = horizontal.intercept + speedGround * t;
      final modelHeight = h0 + vz * t - 0.5 * _g * t * t;
      squared +=
          math.pow(modelGround - grounds[i], 2) +
          math.pow(modelHeight - heights[i], 2);
    }
    final residual = math.sqrt(squared / times.length);

    // Distance from the release point to the ring, along the ground.
    final releaseDistance = math.sqrt(
      origin.lateralM * origin.lateralM + origin.depthM * origin.depthM,
    );

    final timeToRim = releaseDistance / speedGround;
    final vzAtRim = vz - _g * timeToRim;

    final apex = vz > 0
        ? h0 + vz * vz / (2 * _g)
        : math.max(h0, h0 + vz * timeToRim - 0.5 * _g * timeToRim * timeToRim);

    return FlightMeasurement(
      releaseAngleDeg: degrees(math.atan2(vz, speedGround)),
      // Reported as a positive angle below horizontal, which is the convention
      // every coaching reference uses.
      entryAngleDeg: degrees(math.atan2(-vzAtRim, speedGround)),
      releaseHeightM: h0,
      apexHeightM: apex,
      releaseSpeedMs: math.sqrt(vz * vz + speedGround * speedGround),
      flightTimeMs: (timeToRim * 1000).round(),
      releaseDistanceM: releaseDistance,
      residualM: residual,
      sampleCount: ordered.length,
    );
  }

  /// Where the ball crossed the ring plane, in centimetres from centre.
  ///
  /// Interpolates between the samples that straddle rim height rather than
  /// taking the nearest one, because at eight metres a second the nearest
  /// sample can be fifteen centimetres out on its own.
  static ({double lateralCm, double depthCm})? missAtRim(
    List<BallSample> samples, {
    double rimHeightM = CourtDimensions.rimHeightM,
  }) {
    if (samples.length < 2) return null;
    final ordered = [...samples]..sort((a, b) => a.timeMs.compareTo(b.timeMs));

    for (var i = 1; i < ordered.length; i++) {
      final above = ordered[i - 1].position;
      final below = ordered[i].position;
      if (above.heightM >= rimHeightM && below.heightM <= rimHeightM) {
        final span = above.heightM - below.heightM;
        final t = span.abs() < 1e-9 ? 0.0 : (above.heightM - rimHeightM) / span;
        return (
          lateralCm:
              (above.lateralM + (below.lateralM - above.lateralM) * t) * 100,
          depthCm: (above.depthM + (below.depthM - above.depthM) * t) * 100,
        );
      }
    }
    return null;
  }

  /// Angle at [vertex] between the two limbs, degrees.
  ///
  /// Measured in the image plane, so it is only meaningful when the joint is
  /// roughly side-on to the camera. That restriction is why the metric
  /// catalogue offers elbow and knee from some placements and not others,
  /// rather than reporting a number that quietly depends on where the phone
  /// was put.
  static double? jointAngle(
    PoseFrame pose,
    PoseJoint from,
    PoseJoint vertex,
    PoseJoint to,
  ) {
    final a = pose.landmarks[from];
    final b = pose.landmarks[vertex];
    final c = pose.landmarks[to];
    if (a == null || b == null || c == null) return null;

    final ba = Vector2(a.dx - b.dx, a.dy - b.dy);
    final bc = Vector2(c.dx - b.dx, c.dy - b.dy);
    if (ba.length < 1e-6 || bc.length < 1e-6) return null;

    final cosine = (ba.dot(bc) / (ba.length * bc.length)).clamp(-1.0, 1.0);
    return degrees(math.acos(cosine));
  }

  /// Elbow angle on the shooting side.
  static double? elbowAngle(PoseFrame pose, {required bool rightHanded}) =>
      jointAngle(
        pose,
        rightHanded ? PoseJoint.rightShoulder : PoseJoint.leftShoulder,
        rightHanded ? PoseJoint.rightElbow : PoseJoint.leftElbow,
        rightHanded ? PoseJoint.rightWrist : PoseJoint.leftWrist,
      );

  /// Deepest knee bend across the load, which is the number that matters
  /// rather than the angle at any one instant.
  static double? deepestKneeFlexion(
    Iterable<PoseFrame> poses, {
    required bool rightHanded,
  }) {
    double? deepest;
    for (final pose in poses) {
      final angle = jointAngle(
        pose,
        rightHanded ? PoseJoint.rightHip : PoseJoint.leftHip,
        rightHanded ? PoseJoint.rightKnee : PoseJoint.leftKnee,
        rightHanded ? PoseJoint.rightAnkle : PoseJoint.leftAnkle,
      );
      if (angle == null) continue;
      if (deepest == null || angle < deepest) deepest = angle;
    }
    return deepest;
  }

  /// How far the shooter's feet finished from where they started, in
  /// centimetres. Measured on the floor, so it needs the calibration.
  static double? landingDriftCm({
    required CourtFrame frame,
    required Vector2 startFootPixel,
    required Vector2 endFootPixel,
  }) {
    final start = frame.shooterPosition(startFootPixel);
    final end = frame.shooterPosition(endFootPixel);
    if (start == null || end == null) return null;

    final dx = end.lateralM - start.lateralM;
    final dy = end.depthM - start.depthM;
    return math.sqrt(dx * dx + dy * dy) * 100;
  }

  static _Line? _fitLine(List<double> xs, List<double> ys) {
    final n = xs.length;
    if (n < 2) return null;

    var sumX = 0.0;
    var sumY = 0.0;
    for (var i = 0; i < n; i++) {
      sumX += xs[i];
      sumY += ys[i];
    }
    final meanX = sumX / n;
    final meanY = sumY / n;

    var covariance = 0.0;
    var variance = 0.0;
    for (var i = 0; i < n; i++) {
      final dx = xs[i] - meanX;
      covariance += dx * (ys[i] - meanY);
      variance += dx * dx;
    }
    if (variance < 1e-12) return null;

    final slope = covariance / variance;
    return _Line(slope: slope, intercept: meanY - slope * meanX);
  }
}

class _Line {
  const _Line({required this.slope, required this.intercept});

  final double slope;
  final double intercept;
}
