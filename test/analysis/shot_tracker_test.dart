import 'dart:math' as math;

import 'package:arcvanta/data/analysis/shot_tracker.dart';
import 'package:arcvanta/data/calibration/calibration_solver.dart';
import 'package:arcvanta/data/calibration/camera_intrinsics.dart';
import 'package:arcvanta/data/calibration/court_dimensions.dart';
import 'package:arcvanta/data/calibration/court_frame.dart';
import 'package:arcvanta/data/capture/capture_protocol.dart';
import 'package:arcvanta/data/capture/model_contract.dart';
import 'package:arcvanta/data/models/pose.dart';
import 'package:arcvanta/data/models/shot.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

const double _g = 9.80665;

final _intrinsics = CameraIntrinsics.fromHorizontalFov(
  fovDegrees: 68,
  widthPx: 1920,
  heightPx: 1080,
);

/// A tripod at about 1.6 m, nine metres back, level. The shooter stands off
/// to one side of the camera's line so the plane of the shot does not pass
/// through the lens, which is the degenerate case the arc metrics exclude.
final _frame = CourtFrame(
  intrinsics: _intrinsics,
  rimCentre: Vector3(0, -1.448, 9.0),
  up: Vector3(0, -1, 0),
  backAxis: Vector3(0, 0, 1),
);

const double _shooterLateralM = 1.5;

/// Body heights for a standing shooter, in metres above the floor.
const _skeleton = <int, (double lateral, double height)>{
  0: (0.0, 1.72), // nose
  1: (-0.03, 1.75), 2: (0.03, 1.75), // eyes
  3: (-0.07, 1.74), 4: (0.07, 1.74), // ears
  5: (-0.20, 1.45), 6: (0.20, 1.45), // shoulders
  7: (-0.24, 1.18), 8: (0.24, 1.18), // elbows
  11: (-0.14, 0.95), 12: (0.14, 0.95), // hips
  13: (-0.15, 0.52), 14: (0.15, 0.52), // knees
  15: (-0.15, 0.06), 16: (0.15, 0.06), // ankles
};

/// Projects a shooter standing at [feet] into a detection, with the shooting
/// wrist placed at [wristHeight].
PersonDetection _person({
  required CourtPosition feet,
  required double wristHeight,
  double score = 0.95,
}) {
  final points = <Vector2>[];
  final scores = <double>[];

  for (var index = 0; index < ModelContract.poseKeypointCount; index++) {
    late final double lateral;
    late final double height;
    if (index == 9) {
      lateral = -0.18;
      height = wristHeight;
    } else if (index == 10) {
      lateral = 0.10;
      height = wristHeight;
    } else {
      final entry = _skeleton[index]!;
      lateral = entry.$1;
      height = entry.$2;
    }

    final world = _frame.fromCourt(
      CourtPosition(
        lateralM: feet.lateralM + lateral,
        depthM: feet.depthM,
        heightM: height,
      ),
    );
    points.add(_intrinsics.projectToPixel(world)!);
    scores.add(score);
  }

  var minX = double.infinity, minY = double.infinity;
  var maxX = -double.infinity, maxY = -double.infinity;
  for (final p in points) {
    minX = math.min(minX, p.x);
    minY = math.min(minY, p.y);
    maxX = math.max(maxX, p.x);
    maxY = math.max(maxY, p.y);
  }
  // The box reaches the floor, which is what the tracker stands the shooter on.
  final floor = _intrinsics.projectToPixel(
    _frame.fromCourt(
      CourtPosition(lateralM: feet.lateralM, depthM: feet.depthM, heightM: 0),
    ),
  )!;

  return PersonDetection(
    box: Detection(
      type: DetectionClass.person,
      left: minX - 8,
      top: minY - 12,
      right: maxX + 8,
      bottom: floor.y,
      score: score,
    ),
    keypoints: points,
    keypointScores: scores,
  );
}

Detection _ballAt(CourtPosition position, {double score = 0.9}) {
  final world = _frame.fromCourt(position);
  final pixel = _intrinsics.projectToPixel(world)!;
  final radius =
      _intrinsics.focalXPx * CourtDimensions.ballRadiusM / world.length;
  return Detection(
    type: DetectionClass.ball,
    left: pixel.x - radius,
    top: pixel.y - radius,
    right: pixel.x + radius,
    bottom: pixel.y + radius,
    score: score,
  );
}

DetectionFrame _detectionFrame({
  required int timeMs,
  PersonDetection? person,
  Detection? ball,
}) {
  return DetectionFrame(
    timestampMs: timeMs,
    people: person == null ? const [] : [person],
    ball: ball,
    rim: null,
    rimEllipse: null,
    backboard: null,
    intrinsics: _intrinsics,
    gravity: Vector3(0, 1, 0),
    conditions: const CaptureConditions(),
    processedFps: 60,
    thermalHeadroom: 1,
    backend: InferenceBackend.cpu,
  );
}

/// Builds a whole attempt: the shooter gathers, releases, and the ball flies.
List<DetectionFrame> _attempt({
  double shooterDepthM = 4.19,
  double lateralAtRimM = 0,
  double releaseAngleDeg = 52,
  double releaseHeightM = 2.30,
  double? speedOverride,
  bool dropBallAfterRelease = false,
}) {
  final frames = <DetectionFrame>[];
  final feet = CourtPosition(
    lateralM: _shooterLateralM,
    depthM: shooterDepthM,
    heightM: 0,
  );

  var time = 0;
  // Gather and dip, ball in the hands.
  for (var i = 0; i < 20; i++) {
    final wrist = 1.30 - 0.10 * math.sin(i / 19 * math.pi);
    final person = _person(feet: feet, wristHeight: wrist);
    frames.add(
      _detectionFrame(
        timeMs: time,
        person: person,
        ball: _ballAt(
          CourtPosition(
            lateralM: feet.lateralM - 0.04,
            depthM: feet.depthM,
            heightM: wrist + 0.10,
          ),
        ),
      ),
    );
    time += 16;
  }

  // Flight. Speed is chosen so the ball arrives at the ring.
  final angle = radians(releaseAngleDeg);
  final drop = CourtDimensions.rimHeightM - releaseHeightM;
  final cos = math.cos(angle);
  final speed = speedOverride ??
      math.sqrt(
        _g *
            shooterDepthM *
            shooterDepthM /
            (2 * cos * cos * (shooterDepthM * math.tan(angle) - drop)),
      );
  final vGround = speed * cos;
  final vUp = speed * math.sin(angle);

  final releasedAt = time;
  for (var i = 0; i <= 90; i++) {
    final t = i / 60;
    final travelled = vGround * t;
    final remaining = shooterDepthM - travelled;
    final height = releaseHeightM + vUp * t - 0.5 * _g * t * t;
    if (height < 1.6) break;

    final progress = (travelled / shooterDepthM).clamp(0.0, 1.0);
    final lateral =
        _shooterLateralM + (lateralAtRimM - _shooterLateralM) * progress;
    final person = _person(feet: feet, wristHeight: 2.05);

    frames.add(
      _detectionFrame(
        timeMs: releasedAt + (t * 1000).round(),
        person: person,
        ball: dropBallAfterRelease && i > 3
            ? null
            : _ballAt(
                CourtPosition(
                  lateralM: lateral,
                  depthM: remaining,
                  heightM: height,
                ),
              ),
      ),
    );
  }

  return frames;
}

TrackedShot? _run(List<DetectionFrame> frames, {CourtFrame? frame}) {
  final tracker = ShotTracker(frame: frame ?? _frame);
  TrackedShot? emitted;
  for (final detection in frames) {
    final shot = tracker.accept(detection);
    if (shot != null) {
      expect(emitted, isNull, reason: 'emitted more than one shot');
      emitted = shot;
    }
  }
  return emitted;
}

void main() {
  group('a made free throw', () {
    late TrackedShot shot;

    setUp(() => shot = _run(_attempt())!);

    test('is detected as one shot', () {
      expect(shot.result, ShotResult.made);
    });

    test('measures the release angle it was generated with', () {
      expect(shot.flight!.releaseAngleDeg, closeTo(52, 2.5));
    });

    test('measures the release height', () {
      expect(shot.flight!.releaseHeightM, closeTo(2.30, 0.10));
    });

    test('reports an entry angle in the coaching range', () {
      expect(shot.flight!.entryAngleDeg, inInclusiveRange(40, 52));
    });

    test('reports the shot distance', () {
      // The shooter stands off to the side, so the ground distance to the ring
      // is longer than their depth out from the backboard.
      final expected = math.sqrt(
        _shooterLateralM * _shooterLateralM + 4.19 * 4.19,
      );
      expect(shot.flight!.releaseDistanceM, closeTo(expected, 0.25));
    });

    test('carries a trajectory for the overlay', () {
      expect(shot.trajectory.length, greaterThan(10));
      for (final point in shot.trajectory) {
        expect(point.dx, inInclusiveRange(-0.5, 1.5));
        expect(point.dy, inInclusiveRange(-0.5, 1.5));
      }
    });

    test('captures the release pose and the deepest load', () {
      expect(shot.releasePose, isNotNull);
      expect(shot.loadPose, isNotNull);
    });

    test('has evidence behind it', () {
      expect(shot.evidence, greaterThan(0.5));
    });

    test('separates the release from the gather', () {
      expect(shot.releaseTimeMs, greaterThan(0));
      expect(shot.releasedAtMs, greaterThan(shot.startedAtMs));
    });
  });

  group('results', () {
    test('a shot through the middle is a swish', () {
      final shot = _run(_attempt())!;
      expect(shot.outcomeDetail, ShotOutcomeDetail.swish);
    });

    test('a shot well left of the ring misses left', () {
      final shot = _run(_attempt(lateralAtRimM: -0.34))!;
      expect(shot.result, ShotResult.missed);
      expect(shot.outcomeDetail, ShotOutcomeDetail.leftRim);
    });

    test('a shot well right of the ring misses right', () {
      final shot = _run(_attempt(lateralAtRimM: 0.34))!;
      expect(shot.result, ShotResult.missed);
      expect(shot.outcomeDetail, ShotOutcomeDetail.rightRim);
    });

    test('a shot that falls short misses short', () {
      // Under-hit: the ball drops through rim height before reaching the ring.
      final shot = _run(_attempt(speedOverride: 6.4))!;
      expect(shot.result, ShotResult.missed);
      expect(
        shot.outcomeDetail,
        anyOf(ShotOutcomeDetail.short, ShotOutcomeDetail.frontRim),
      );
    });
  });

  group('the tracker admits when it does not know', () {
    test('losing the ball mid flight gives an uncertain shot', () {
      final shot = _run(_attempt(dropBallAfterRelease: true));
      // The flight times out and is handed over for the athlete to confirm.
      final tracker = ShotTracker(frame: _frame);
      for (final f in _attempt(dropBallAfterRelease: true)) {
        tracker.accept(f);
      }
      final flushed = shot ?? tracker.flush();
      expect(flushed, isNotNull);
      expect(flushed!.result, ShotResult.uncertain);
      expect(flushed.evidence, 0);
    });

    test('without calibration nothing is measured', () {
      final tracker = ShotTracker(frame: null);
      for (final f in _attempt()) {
        tracker.accept(f);
      }
      final shot = tracker.flush();
      if (shot != null) {
        expect(shot.flight, isNull);
        expect(shot.result, ShotResult.uncertain);
        expect(shot.evidence, 0);
      }
    });

    test('dribbling is not a shot', () {
      final frames = <DetectionFrame>[];
      const feet = CourtPosition(
        lateralM: _shooterLateralM,
        depthM: 5,
        heightM: 0,
      );
      for (var i = 0; i < 60; i++) {
        final height = 0.55 + 0.45 * math.sin(i / 6);
        frames.add(
          _detectionFrame(
            timeMs: i * 16,
            person: _person(feet: feet, wristHeight: 1.05),
            ball: _ballAt(
              CourtPosition(
                lateralM: feet.lateralM - 0.25,
                depthM: feet.depthM,
                heightM: height,
              ),
            ),
          ),
        );
      }

      expect(_run(frames), isNull);
    });

    test('an empty frame does not start anything', () {
      final tracker = ShotTracker(frame: _frame);
      for (var i = 0; i < 30; i++) {
        expect(tracker.accept(_detectionFrame(timeMs: i * 16)), isNull);
      }
      expect(tracker.phase, ShotPhaseKind.idle);
      expect(tracker.flush(), isNull);
    });
  });

  group('phases', () {
    test('runs from idle through possession to flight', () {
      final tracker = ShotTracker(frame: _frame);
      final seen = <ShotPhaseKind>{};
      for (final f in _attempt()) {
        tracker.accept(f);
        seen.add(tracker.phase);
      }
      expect(seen, contains(ShotPhaseKind.possession));
      expect(seen, contains(ShotPhaseKind.flight));
    });
  });

  test('back to back attempts are both reported', () {
    final tracker = ShotTracker(frame: _frame);
    final shots = <TrackedShot>[];
    for (var round = 0; round < 2; round++) {
      for (final f in _attempt()) {
        final shot = tracker.accept(
          DetectionFrame(
            timestampMs: f.timestampMs + round * 100000,
            people: f.people,
            ball: f.ball,
            rim: f.rim,
            rimEllipse: f.rimEllipse,
            backboard: f.backboard,
            intrinsics: f.intrinsics,
            gravity: f.gravity,
            conditions: f.conditions,
            processedFps: f.processedFps,
            thermalHeadroom: f.thermalHeadroom,
            backend: f.backend,
          ),
        );
        if (shot != null) shots.add(shot);
      }
    }
    expect(shots.length, 2);
    expect(shots.every((s) => s.result == ShotResult.made), isTrue);
  });

  test('landmarks map onto the fourteen joints the product draws', () {
    final person = _person(
      feet: const CourtPosition(
        lateralM: _shooterLateralM,
        depthM: 5,
        heightM: 0,
      ),
      wristHeight: 1.4,
    );
    final pose = ShotTracker.poseFromDetection(person, 1920, 1080);

    expect(pose.landmarks.length, 14);
    // The neck is derived from the shoulders, not predicted.
    final neck = pose.landmarks[PoseJoint.neck]!;
    final left = pose.landmarks[PoseJoint.leftShoulder]!;
    final right = pose.landmarks[PoseJoint.rightShoulder]!;
    expect(neck.dx, closeTo((left.dx + right.dx) / 2, 1e-12));
    expect(neck.dy, closeTo((left.dy + right.dy) / 2, 1e-12));
  });
}
