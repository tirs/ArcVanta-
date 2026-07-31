import 'dart:math' as math;

import '../calibration/court_frame.dart';
import '../models/confidence.dart';
import '../models/drill.dart';
import '../models/pose.dart';
import '../models/shot.dart';
import 'court_zones.dart';
import 'shot_measurer.dart';
import 'shot_tracker.dart';

/// Builds the shot record the product stores from what the tracker measured.
///
/// Every field either comes from a measurement or is left at a value the
/// confidence grading will mark unavailable. Nothing is invented to fill a
/// gap: a shot the pipeline could not measure arrives with low confidence and
/// the screens already know to hide precision it has not earned.
abstract final class ShotAssembler {
  static Shot assemble({
    required TrackedShot tracked,
    required int index,
    required Duration offsetFromStart,
    required CourtFrame? frame,
    required double calibrationQuality,
    required Drill drill,
    bool rightHanded = true,
  }) {
    final flight = tracked.flight;
    final release = tracked.releasePose;

    final shooter = tracked.shooter;
    final zone = shooter == null
        ? CourtZone.freeThrow
        : CourtZones.fromPosition(shooter);

    // Calibration bounds everything measured in metres, so it caps the
    // evidence rather than being averaged with it.
    final evidence = tracked.evidence * calibrationQuality;

    return Shot(
      id: 'shot-${tracked.releasedAtMs}-$index',
      index: index,
      offsetFromStart: offsetFromStart,
      result: tracked.result,
      outcomeDetail: tracked.outcomeDetail,
      zone: zone,
      type: _typeFor(drill, zone),
      confidence: ConfidenceLevel.fromScore(evidence),
      releaseAngle: flight?.releaseAngleDeg ?? 0,
      entryAngle: flight?.entryAngleDeg ?? 0,
      apexHeightM: flight?.apexHeightM ?? 0,
      releaseHeightM: flight?.releaseHeightM ?? 0,
      ballSpeedMs: flight?.releaseSpeedMs ?? 0,
      flightTimeMs: flight?.flightTimeMs ?? 0,
      lateralDeviationCm: tracked.miss?.lateralCm ?? 0,
      depthCm: tracked.miss?.depthCm ?? 0,
      elbowAngle: release == null
          ? 0
          : ShotMeasurer.elbowAngle(release, rightHanded: rightHanded) ?? 0,
      kneeFlexion:
          ShotMeasurer.deepestKneeFlexion(
            tracked.poses,
            rightHanded: rightHanded,
          ) ??
          0,
      guideHandSeparationCm: _guideHandSeparationCm(release, frame) ?? 0,
      releaseTimeMs: tracked.releaseTimeMs,
      followThroughMs: tracked.followThroughMs,
      landingDriftCm: 0,
      balanceScore: _balanceScore(tracked, rightHanded: rightHanded),
      mechanicsScore: _mechanicsScore(tracked, rightHanded: rightHanded),
      trajectory: tracked.trajectory,
      phases: _phases(tracked),
    );
  }

  static ShotType _typeFor(Drill drill, CourtZone zone) {
    if (zone == CourtZone.freeThrow) return ShotType.freeThrow;
    if (zone == CourtZone.restrictedArea) return ShotType.layup;
    return drill.shotType;
  }

  /// How far the guide hand finished from the shooting hand, in centimetres.
  /// A clean release leaves it under about six.
  static double? _guideHandSeparationCm(PoseFrame? pose, CourtFrame? frame) {
    if (pose == null || frame == null) return null;
    final left = pose.landmarks[PoseJoint.leftWrist];
    final right = pose.landmarks[PoseJoint.rightWrist];
    final leftShoulder = pose.landmarks[PoseJoint.leftShoulder];
    final rightShoulder = pose.landmarks[PoseJoint.rightShoulder];
    if (left == null ||
        right == null ||
        leftShoulder == null ||
        rightShoulder == null) {
      return null;
    }

    // Scaled against shoulder width, which is the one body measurement that is
    // stable across athletes and does not need depth to be known.
    final shoulderSpan = (leftShoulder - rightShoulder).distance;
    if (shoulderSpan < 1e-6) return null;
    const assumedShoulderWidthM = 0.40;
    return (left - right).distance / shoulderSpan * assumedShoulderWidthM * 100;
  }

  static double _balanceScore(TrackedShot tracked, {required bool rightHanded}) {
    final pose = tracked.releasePose;
    if (pose == null) return 0;

    final leftAnkle = pose.landmarks[PoseJoint.leftAnkle];
    final rightAnkle = pose.landmarks[PoseJoint.rightAnkle];
    final neck = pose.landmarks[PoseJoint.neck];
    if (leftAnkle == null || rightAnkle == null || neck == null) return 0;

    // Trunk lean: how far the neck sits from above the midpoint of the feet,
    // as a share of the stance width.
    final baseX = (leftAnkle.dx + rightAnkle.dx) / 2;
    final stance = (leftAnkle.dx - rightAnkle.dx).abs();
    if (stance < 1e-6) return 0;

    final lean = (neck.dx - baseX).abs() / stance;
    return (100 - lean * 60).clamp(0.0, 100.0);
  }

  static double _mechanicsScore(
    TrackedShot tracked, {
    required bool rightHanded,
  }) {
    final scores = <double>[];

    final elbow = tracked.releasePose == null
        ? null
        : ShotMeasurer.elbowAngle(
            tracked.releasePose!,
            rightHanded: rightHanded,
          );
    if (elbow != null) scores.add(_bandScore(elbow, 84, 96));

    final knee = ShotMeasurer.deepestKneeFlexion(
      tracked.poses,
      rightHanded: rightHanded,
    );
    if (knee != null) scores.add(_bandScore(knee, 118, 138));

    final flight = tracked.flight;
    if (flight != null) {
      scores.add(_bandScore(flight.releaseAngleDeg, 48, 55));
      scores.add(_bandScore(flight.entryAngleDeg, 43, 50));
    }

    if (scores.isEmpty) return 0;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  /// 100 inside the coaching band, falling away outside it.
  static double _bandScore(double value, double low, double high) {
    if (value >= low && value <= high) return 100;
    final width = high - low;
    final distance = value < low ? low - value : value - high;
    return (100 - distance / width * 55).clamp(0.0, 100.0);
  }

  static List<ShotPhase> _phases(TrackedShot tracked) {
    final gather = math.max(0, tracked.releasedAtMs - tracked.startedAtMs);
    final follow = math.max(0, tracked.endedAtMs - tracked.releasedAtMs);
    return [
      ShotPhase(name: 'Gather', startMs: 0, durationMs: gather),
      ShotPhase(name: 'Release', startMs: gather, durationMs: 60),
      ShotPhase(name: 'Flight', startMs: gather + 60, durationMs: follow),
    ];
  }
}
