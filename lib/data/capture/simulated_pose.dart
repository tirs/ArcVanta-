import 'dart:math' as math;
import 'dart:ui' show Offset;

import '../models/pose.dart';
import 'live_scene.dart';
import 'shot_cycle.dart';

/// Produces the landmark set the live overlay draws for a given point in the
/// shot cycle.
///
/// Keyframes describe a right-handed jump shot captured from a side placement.
/// The animator interpolates between them and applies a small amount of
/// confidence-aware jitter so the overlay reads as tracked output rather than a
/// looping illustration.
abstract final class PoseAnimator {
  static const Map<PoseJoint, Offset> _ready = {
    PoseJoint.head: Offset(0.404, 0.296),
    PoseJoint.neck: Offset(0.404, 0.352),
    PoseJoint.leftShoulder: Offset(0.366, 0.372),
    PoseJoint.rightShoulder: Offset(0.446, 0.372),
    PoseJoint.leftElbow: Offset(0.340, 0.456),
    PoseJoint.rightElbow: Offset(0.472, 0.456),
    PoseJoint.leftWrist: Offset(0.372, 0.514),
    PoseJoint.rightWrist: Offset(0.438, 0.516),
    PoseJoint.leftHip: Offset(0.380, 0.548),
    PoseJoint.rightHip: Offset(0.436, 0.548),
    PoseJoint.leftKnee: Offset(0.372, 0.688),
    PoseJoint.rightKnee: Offset(0.440, 0.688),
    PoseJoint.leftAnkle: Offset(0.366, 0.828),
    PoseJoint.rightAnkle: Offset(0.444, 0.828),
  };

  static const Map<PoseJoint, Offset> _dip = {
    PoseJoint.head: Offset(0.404, 0.334),
    PoseJoint.neck: Offset(0.404, 0.390),
    PoseJoint.leftShoulder: Offset(0.366, 0.410),
    PoseJoint.rightShoulder: Offset(0.446, 0.410),
    PoseJoint.leftElbow: Offset(0.336, 0.488),
    PoseJoint.rightElbow: Offset(0.476, 0.488),
    PoseJoint.leftWrist: Offset(0.374, 0.552),
    PoseJoint.rightWrist: Offset(0.436, 0.554),
    PoseJoint.leftHip: Offset(0.378, 0.586),
    PoseJoint.rightHip: Offset(0.438, 0.586),
    PoseJoint.leftKnee: Offset(0.358, 0.702),
    PoseJoint.rightKnee: Offset(0.452, 0.702),
    PoseJoint.leftAnkle: Offset(0.366, 0.828),
    PoseJoint.rightAnkle: Offset(0.444, 0.828),
  };

  static const Map<PoseJoint, Offset> _load = {
    PoseJoint.head: Offset(0.406, 0.356),
    PoseJoint.neck: Offset(0.406, 0.412),
    PoseJoint.leftShoulder: Offset(0.368, 0.432),
    PoseJoint.rightShoulder: Offset(0.448, 0.432),
    PoseJoint.leftElbow: Offset(0.338, 0.502),
    PoseJoint.rightElbow: Offset(0.478, 0.500),
    PoseJoint.leftWrist: Offset(0.378, 0.548),
    PoseJoint.rightWrist: Offset(0.440, 0.550),
    PoseJoint.leftHip: Offset(0.378, 0.606),
    PoseJoint.rightHip: Offset(0.440, 0.606),
    PoseJoint.leftKnee: Offset(0.352, 0.712),
    PoseJoint.rightKnee: Offset(0.458, 0.712),
    PoseJoint.leftAnkle: Offset(0.366, 0.828),
    PoseJoint.rightAnkle: Offset(0.444, 0.828),
  };

  static const Map<PoseJoint, Offset> _setPoint = {
    PoseJoint.head: Offset(0.404, 0.284),
    PoseJoint.neck: Offset(0.404, 0.338),
    PoseJoint.leftShoulder: Offset(0.368, 0.356),
    PoseJoint.rightShoulder: Offset(0.446, 0.356),
    PoseJoint.leftElbow: Offset(0.348, 0.360),
    PoseJoint.rightElbow: Offset(0.454, 0.334),
    PoseJoint.leftWrist: Offset(0.396, 0.262),
    PoseJoint.rightWrist: Offset(0.444, 0.244),
    PoseJoint.leftHip: Offset(0.380, 0.522),
    PoseJoint.rightHip: Offset(0.436, 0.522),
    PoseJoint.leftKnee: Offset(0.368, 0.652),
    PoseJoint.rightKnee: Offset(0.442, 0.652),
    PoseJoint.leftAnkle: Offset(0.366, 0.816),
    PoseJoint.rightAnkle: Offset(0.444, 0.816),
  };

  static const Map<PoseJoint, Offset> _release = {
    PoseJoint.head: Offset(0.404, 0.252),
    PoseJoint.neck: Offset(0.404, 0.306),
    PoseJoint.leftShoulder: Offset(0.368, 0.324),
    PoseJoint.rightShoulder: Offset(0.446, 0.324),
    PoseJoint.leftElbow: Offset(0.348, 0.328),
    PoseJoint.rightElbow: Offset(0.450, 0.274),
    PoseJoint.leftWrist: Offset(0.394, 0.226),
    PoseJoint.rightWrist: Offset(0.456, 0.174),
    PoseJoint.leftHip: Offset(0.380, 0.488),
    PoseJoint.rightHip: Offset(0.436, 0.488),
    PoseJoint.leftKnee: Offset(0.370, 0.616),
    PoseJoint.rightKnee: Offset(0.442, 0.616),
    PoseJoint.leftAnkle: Offset(0.368, 0.788),
    PoseJoint.rightAnkle: Offset(0.446, 0.788),
  };

  static const Map<PoseJoint, Offset> _followThrough = {
    PoseJoint.head: Offset(0.404, 0.236),
    PoseJoint.neck: Offset(0.404, 0.290),
    PoseJoint.leftShoulder: Offset(0.368, 0.308),
    PoseJoint.rightShoulder: Offset(0.446, 0.308),
    PoseJoint.leftElbow: Offset(0.350, 0.316),
    PoseJoint.rightElbow: Offset(0.452, 0.258),
    PoseJoint.leftWrist: Offset(0.392, 0.216),
    PoseJoint.rightWrist: Offset(0.466, 0.156),
    PoseJoint.leftHip: Offset(0.380, 0.470),
    PoseJoint.rightHip: Offset(0.436, 0.470),
    PoseJoint.leftKnee: Offset(0.372, 0.600),
    PoseJoint.rightKnee: Offset(0.440, 0.600),
    PoseJoint.leftAnkle: Offset(0.370, 0.772),
    PoseJoint.rightAnkle: Offset(0.448, 0.772),
  };

  static const Map<PoseJoint, Offset> _landing = {
    PoseJoint.head: Offset(0.404, 0.318),
    PoseJoint.neck: Offset(0.404, 0.374),
    PoseJoint.leftShoulder: Offset(0.366, 0.394),
    PoseJoint.rightShoulder: Offset(0.446, 0.394),
    PoseJoint.leftElbow: Offset(0.340, 0.446),
    PoseJoint.rightElbow: Offset(0.464, 0.412),
    PoseJoint.leftWrist: Offset(0.368, 0.396),
    PoseJoint.rightWrist: Offset(0.470, 0.318),
    PoseJoint.leftHip: Offset(0.378, 0.574),
    PoseJoint.rightHip: Offset(0.438, 0.574),
    PoseJoint.leftKnee: Offset(0.360, 0.698),
    PoseJoint.rightKnee: Offset(0.450, 0.698),
    PoseJoint.leftAnkle: Offset(0.366, 0.828),
    PoseJoint.rightAnkle: Offset(0.444, 0.828),
  };

  static PoseFrame _frame(Map<PoseJoint, Offset> pose, double confidence) =>
      PoseFrame(landmarks: pose, confidence: confidence);

  /// Landmarks for the given millisecond offset inside the shot cycle.
  static PoseFrame at(int cycleMs, {double trackingConfidence = 0.94}) {
    final phase = ShotCycle.phaseAt(cycleMs);
    var cursor = 0;
    double span(int duration) {
      final t = ((cycleMs - cursor) / duration).clamp(0.0, 1.0);
      cursor += duration;
      return t;
    }

    PoseFrame result;
    switch (phase) {
      case ShotPhaseKind.possession:
        final t = span(ShotCycle.approach);
        result = PoseFrame.lerp(
          _frame(_landing, 0.9),
          _frame(_ready, 0.95),
          _ease(t),
        );
      case ShotPhaseKind.ready:
        cursor = ShotCycle.approach;
        span(ShotCycle.ready);
        result = _frame(_ready, 0.96);
      case ShotPhaseKind.dip:
        cursor = ShotCycle.approach + ShotCycle.ready;
        result = PoseFrame.lerp(
          _frame(_ready, 0.96),
          _frame(_dip, 0.95),
          _ease(span(ShotCycle.dip)),
        );
      case ShotPhaseKind.load:
        cursor = ShotCycle.approach + ShotCycle.ready + ShotCycle.dip;
        result = PoseFrame.lerp(
          _frame(_dip, 0.95),
          _frame(_load, 0.94),
          _ease(span(ShotCycle.load)),
        );
      case ShotPhaseKind.upward:
        cursor =
            ShotCycle.approach +
            ShotCycle.ready +
            ShotCycle.dip +
            ShotCycle.load;
        result = PoseFrame.lerp(
          _frame(_load, 0.94),
          _frame(_setPoint, 0.93),
          _ease(span(ShotCycle.upward)),
        );
      case ShotPhaseKind.setPoint:
        cursor =
            ShotCycle.approach +
            ShotCycle.ready +
            ShotCycle.dip +
            ShotCycle.load +
            ShotCycle.upward;
        result = PoseFrame.lerp(
          _frame(_setPoint, 0.93),
          _frame(_release, 0.92),
          _ease(span(ShotCycle.setPoint)) * 0.35,
        );
      case ShotPhaseKind.release:
        cursor =
            ShotCycle.approach +
            ShotCycle.ready +
            ShotCycle.dip +
            ShotCycle.load +
            ShotCycle.upward +
            ShotCycle.setPoint;
        result = PoseFrame.lerp(
          _frame(_setPoint, 0.93),
          _frame(_release, 0.92),
          0.35 + _ease(span(ShotCycle.release)) * 0.65,
        );
      case ShotPhaseKind.flight:
      case ShotPhaseKind.rimInteraction:
        cursor =
            ShotCycle.approach +
            ShotCycle.ready +
            ShotCycle.dip +
            ShotCycle.load +
            ShotCycle.upward +
            ShotCycle.setPoint +
            ShotCycle.release;
        final t = _ease(span(ShotCycle.flight + ShotCycle.rim));
        result = t < 0.32
            ? PoseFrame.lerp(
                _frame(_release, 0.92),
                _frame(_followThrough, 0.93),
                t / 0.32,
              )
            : PoseFrame.lerp(
                _frame(_followThrough, 0.93),
                _frame(_landing, 0.9),
                (t - 0.32) / 0.68,
              );
      case ShotPhaseKind.landing:
        result = _frame(_landing, 0.9);
      case ShotPhaseKind.recovery:
        cursor = ShotCycle.total - ShotCycle.recovery;
        result = PoseFrame.lerp(
          _frame(_landing, 0.9),
          _frame(_ready, 0.95),
          _ease(span(ShotCycle.recovery)),
        );
      case ShotPhaseKind.idle:
      case ShotPhaseKind.followThrough:
        result = _frame(_ready, 0.95);
    }

    return _jitter(result, cycleMs, trackingConfidence);
  }

  /// Ball centre for the given cycle position. Follows the shooting hand while
  /// in possession, then a ballistic path to the rim.
  static Offset ballAt(int cycleMs, {bool willMiss = false}) {
    final flight = ShotCycle.flightProgress(cycleMs);
    final pose = at(cycleMs);

    if (flight == null) {
      final wrist = pose[PoseJoint.rightWrist];
      final guide = pose[PoseJoint.leftWrist];
      return Offset(
        (wrist.dx + guide.dx) / 2 + 0.012,
        (wrist.dy + guide.dy) / 2 - 0.026,
      );
    }

    final start = const Offset(0.470, 0.150);
    final target = LiveScene.rimCentre;
    final lateral = willMiss ? 0.018 : 0.0;
    final x = start.dx + (target.dx - start.dx) * flight + lateral * flight;
    final apex = 0.062;
    final y =
        start.dy +
        (target.dy - start.dy) * flight -
        4 * apex * flight * (1 - flight);
    return Offset(x, y);
  }

  static double _ease(double t) =>
      t <= 0 ? 0 : (t >= 1 ? 1 : 1 - math.pow(1 - t, 3).toDouble());

  static PoseFrame _jitter(PoseFrame frame, int ms, double confidence) {
    final amplitude = (1 - confidence) * 0.0065;
    if (amplitude <= 0) return frame;
    final result = <PoseJoint, Offset>{};
    var i = 0;
    for (final entry in frame.landmarks.entries) {
      final phase = ms / 90.0 + i * 1.7;
      result[entry.key] =
          entry.value +
          Offset(
            math.sin(phase) * amplitude,
            math.cos(phase * 1.3) * amplitude,
          );
      i++;
    }
    return PoseFrame(landmarks: result, confidence: frame.confidence);
  }
}
