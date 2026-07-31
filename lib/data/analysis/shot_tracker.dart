import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:vector_math/vector_math_64.dart';

import '../calibration/court_dimensions.dart';
import '../calibration/court_frame.dart';
import '../capture/capture_protocol.dart';
import '../capture/model_contract.dart';
import '../models/pose.dart';
import '../models/shot.dart';
import 'shot_measurer.dart';

/// A completed flight with everything the shot record needs.
class TrackedShot {
  const TrackedShot({
    required this.startedAtMs,
    required this.releasedAtMs,
    required this.endedAtMs,
    required this.flight,
    required this.miss,
    required this.result,
    required this.outcomeDetail,
    required this.trajectory,
    required this.poses,
    required this.releasePose,
    required this.loadPose,
    required this.shooter,
    required this.evidence,
  });

  final int startedAtMs;
  final int releasedAtMs;
  final int endedAtMs;

  final FlightMeasurement? flight;
  final ({double lateralCm, double depthCm})? miss;

  final ShotResult result;
  final ShotOutcomeDetail outcomeDetail;

  /// Ball path in normalised preview coordinates, for the overlay.
  final List<Offset> trajectory;

  final List<PoseFrame> poses;
  final PoseFrame? releasePose;
  final PoseFrame? loadPose;

  /// Where the shooter was standing when they let go, in court metres. Null
  /// without a calibration, which is also when nothing else is measured.
  final CourtPosition? shooter;

  /// 0 to 1, folding flight fit, calibration and tracking together.
  final double evidence;

  int get releaseTimeMs => releasedAtMs - startedAtMs;
  int get followThroughMs => endedAtMs - releasedAtMs;
}

/// Segments a stream of detections into shots, and measures each one.
///
/// Deliberately in Dart rather than in either native bridge. Shot boundaries
/// are the part of the pipeline most likely to need tuning against real
/// footage, and having one implementation that can be driven from a test
/// beats two that have to be kept in step.
class ShotTracker {
  ShotTracker({required this.frame, this.rightHanded = true});

  /// The solved scene. Without it the tracker still finds shots but cannot
  /// measure them, and everything it emits is marked unavailable.
  final CourtFrame? frame;
  final bool rightHanded;

  /// How close the ball has to be to a wrist, relative to the shooter's
  /// shoulder width, to count as held.
  ///
  /// Roughly a ball's radius plus a hand. Anything looser keeps reporting
  /// possession for the first few frames of the flight, which drags the fitted
  /// release point up the arc and flattens every release angle.
  static const double _possessionRatio = 0.55;

  /// Ball must clear this above the shooter's head before a rising ball is
  /// treated as a release rather than a dribble or a pass.
  static const double _releaseClearanceM = 0.15;

  /// A flight is abandoned after this long without the ball reaching the ring.
  static const int _flightTimeoutMs = 3000;

  /// The ball is still within arm's reach for a moment after it leaves the
  /// hand, so re-possession is not considered until it has had time to get
  /// clear. Without this every shot would be cancelled on the frame after it
  /// started.
  static const int _repossessionGraceMs = 400;

  final List<BallSample> _samples = [];

  /// Ball centres in analysis pixels, parallel to [_samples]. Kept because the
  /// crossing at the ring is measured by intersecting the ray with the rim
  /// plane, which needs the pixel rather than the shot-plane position.
  final List<Vector2> _ballPixels = [];

  /// Ball height from its apparent size, parallel to [_samples], or null where
  /// the detection was too small to size.
  ///
  /// A ball is a known 24.3 cm across, so its width in pixels gives its
  /// distance without assuming which vertical plane it is travelling in. That
  /// makes it the right way to find the moment it reaches the ring: the shot
  /// plane is biased for exactly the shots that miss sideways, which are the
  /// ones whose crossing matters most.
  final List<double?> _sizedHeights = [];

  final List<Offset> _trajectory = [];
  final List<PoseFrame> _poses = [];

  ShotPhaseKind _phase = ShotPhaseKind.idle;
  int? _possessionSinceMs;
  int? _releasedAtMs;
  PoseFrame? _releasePose;
  PoseFrame? _loadPose;
  double _deepestKnee = 180;
  bool _reachedRimPlane = false;
  double? _lowestHeightAfterRim;

  ShotPhaseKind get phase => _phase;

  /// Feeds one frame in. Returns a shot on the frame that completes one.
  TrackedShot? accept(DetectionFrame detections) {
    final person = detections.subject;
    final pose = person == null
        ? null
        : poseFromDetection(person, detections.intrinsics.widthPx,
            detections.intrinsics.heightPx);
    if (pose != null) _poses.add(pose);

    final held = person != null &&
        detections.ball != null &&
        _isHeld(person, detections.ball!);

    if (held) {
      _possessionSinceMs ??= detections.timestampMs;
      if (_releasedAtMs == null) {
        _phase = ShotPhaseKind.possession;
        if (pose != null) _trackLoad(pose);
        return null;
      }
      if (detections.timestampMs - _releasedAtMs! > _repossessionGraceMs) {
        // Ball back in hand with no result: a rebound, not a shot.
        return _abandon();
      }
    }

    if (_releasedAtMs == null) {
      final released = person != null &&
          detections.ball != null &&
          _possessionSinceMs != null &&
          _isAboveHead(person, detections.ball!);
      if (!released) {
        if (_possessionSinceMs != null && detections.ball == null) {
          // Lost the ball without a release: drop the attempt.
          _reset();
        }
        _phase = _possessionSinceMs == null
            ? ShotPhaseKind.idle
            : ShotPhaseKind.possession;
        return null;
      }
      _releasedAtMs = detections.timestampMs;
      _releasePose = pose;
      _phase = ShotPhaseKind.release;
    }

    final ball = detections.ball;
    if (ball == null) {
      if (detections.timestampMs - _releasedAtMs! > _flightTimeoutMs) {
        return _abandon();
      }
      return null;
    }

    _recordFlightSample(detections, ball);

    final complete = _updateRimProgress(detections);
    if (complete != null) return complete;

    if (detections.timestampMs - _releasedAtMs! > _flightTimeoutMs) {
      return _abandon();
    }
    return null;
  }

  /// Ends any shot in progress, so stopping a session does not strand one.
  TrackedShot? flush() => _releasedAtMs == null ? null : _abandon();

  void _trackLoad(PoseFrame pose) {
    final knee = ShotMeasurer.jointAngle(
      pose,
      rightHanded ? PoseJoint.rightHip : PoseJoint.leftHip,
      rightHanded ? PoseJoint.rightKnee : PoseJoint.leftKnee,
      rightHanded ? PoseJoint.rightAnkle : PoseJoint.leftAnkle,
    );
    if (knee != null && knee < _deepestKnee) {
      _deepestKnee = knee;
      _loadPose = pose;
      _phase = ShotPhaseKind.load;
    }
  }

  bool _isHeld(PersonDetection person, Detection ball) {
    final shoulders = _shoulderWidth(person);
    if (shoulders <= 0) return false;

    final reach = shoulders * _possessionRatio;
    for (final index in const [9, 10]) {
      if (person.keypointScores[index] < 0.3) continue;
      if ((person.keypoints[index] - ball.centre).length < reach) return true;
    }
    return false;
  }

  bool _isAboveHead(PersonDetection person, Detection ball) {
    if (person.keypointScores[0] < 0.3) return false;

    final solved = frame;
    if (solved != null) {
      final feet = solved.pointOnFloor(
        Vector2(person.box.centre.x, person.box.bottom),
      );
      final plane = feet == null ? null : solved.shotPlaneThrough(feet);
      final ballPoint =
          plane == null ? null : solved.intersect(ball.centre, plane);
      final headPoint =
          plane == null ? null : solved.intersect(person.keypoints[0], plane);

      if (ballPoint != null && headPoint != null) {
        return solved.toCourt(ballPoint).heightM >
            solved.toCourt(headPoint).heightM + _releaseClearanceM;
      }
      // Falls through when the camera lies in the plane of the shot, where
      // every ray in it is degenerate. Declaring a release on the strength of
      // a failed intersection would invent shots, so the image-space test
      // below decides instead.
    }

    // The ball has to sit above the head by a share of the body's height in
    // frame. Weaker than the metric test, but it does not depend on geometry.
    return ball.centre.y < person.keypoints[0].y - person.box.height * 0.08;
  }

  double _shoulderWidth(PersonDetection person) {
    if (person.keypointScores[5] < 0.3 || person.keypointScores[6] < 0.3) {
      return person.box.width * 0.4;
    }
    return (person.keypoints[5] - person.keypoints[6]).length;
  }

  void _recordFlightSample(DetectionFrame detections, Detection ball) {
    _trajectory.add(
      Offset(
        ball.centre.x / detections.intrinsics.widthPx,
        ball.centre.y / detections.intrinsics.heightPx,
      ),
    );
    _phase = _reachedRimPlane
        ? ShotPhaseKind.rimInteraction
        : ShotPhaseKind.flight;

    final court = _ballCourtPosition(detections, ball);
    if (court != null) {
      _samples.add(
        BallSample(
          timeMs: detections.timestampMs,
          position: court,
          confidence: ball.score,
        ),
      );
      _ballPixels.add(ball.centre);
      _sizedHeights.add(_heightFromApparentSize(ball));
    }
  }

  double? _heightFromApparentSize(Detection ball) {
    final solved = frame;
    if (solved == null) return null;

    final distance = solved.ballDepthFromRadius(ball.equivalentRadius);
    if (distance == null) return null;

    final ray = solved.intrinsics.rayThroughPixel(ball.centre);
    return solved.toCourt(ray.normalized() * distance).heightM;
  }

  /// Where the ball crossed the ring, in centimetres from centre.
  ///
  /// Taken by intersecting the ball's ray with the horizontal plane through
  /// the ring rather than with the shot plane. At the moment of crossing the
  /// ball really is at rim height, so that intersection is exact and needs no
  /// assumption about which vertical plane the shot travelled in. It is also
  /// the only way to see a sideways miss from a side-on camera, where the shot
  /// plane passes through the ring and so can never show one.
  ({double lateralCm, double depthCm})? _crossing() {
    final solved = frame;
    if (solved == null || _samples.length < 2) return null;

    for (var i = 1; i < _samples.length; i++) {
      final above = _heightAt(i - 1);
      final below = _heightAt(i);
      if (above < CourtDimensions.rimHeightM ||
          below > CourtDimensions.rimHeightM) {
        continue;
      }

      final span = above - below;
      final t = span.abs() < 1e-9
          ? 0.0
          : (above - CourtDimensions.rimHeightM) / span;
      final pixel = _ballPixels[i - 1] + (_ballPixels[i] - _ballPixels[i - 1]) * t;
      return solved.missAtRim(pixel);
    }
    return null;
  }

  double _heightAt(int index) =>
      _sizedHeights[index] ?? _samples[index].position.heightM;

  CourtPosition? _ballCourtPosition(
    DetectionFrame detections,
    Detection ball,
  ) {
    final solved = frame;
    if (solved == null) return null;

    // The shot plane needs somewhere for the shooter to be standing. Once the
    // ball is airborne the shooter may be out of frame, so the plane is fixed
    // from the release and reused.
    final anchor = _shotPlaneAnchor(detections, solved);
    if (anchor == null) return null;

    return solved.ballInShotPlane(
      ballPixel: ball.centre,
      shooterFloorPoint: anchor,
    );
  }

  Vector3? _cachedAnchor;

  Vector3? _shotPlaneAnchor(DetectionFrame detections, CourtFrame solved) {
    if (_cachedAnchor != null) return _cachedAnchor;
    final person = detections.subject;
    if (person == null) return null;
    return _cachedAnchor = solved.pointOnFloor(
      Vector2(person.box.centre.x, person.box.bottom),
    );
  }

  /// Watches the ball down through the ring plane and decides the result.
  TrackedShot? _updateRimProgress(DetectionFrame detections) {
    if (_samples.length < 2) return null;
    final previous = _samples[_samples.length - 2].position;
    final current = _samples.last.position;

    if (!_reachedRimPlane) {
      final crossing = previous.heightM >= CourtDimensions.rimHeightM &&
          current.heightM <= CourtDimensions.rimHeightM;
      if (!crossing) return null;
      _reachedRimPlane = true;
      _lowestHeightAfterRim = current.heightM;
      return null;
    }

    _lowestHeightAfterRim = math.min(
      _lowestHeightAfterRim ?? current.heightM,
      current.heightM,
    );

    // Once the ball is clearly below the ring the outcome is settled.
    if (current.heightM > CourtDimensions.rimHeightM - 0.30) return null;
    return _complete(detections.timestampMs);
  }

  TrackedShot _complete(int endedAtMs) {
    final flight = ShotMeasurer.measureFlight(_samples);
    final miss = _crossing();

    final result = _classify(miss);
    final shot = TrackedShot(
      startedAtMs: _possessionSinceMs ?? _releasedAtMs ?? endedAtMs,
      releasedAtMs: _releasedAtMs ?? endedAtMs,
      endedAtMs: endedAtMs,
      flight: flight,
      miss: miss,
      result: result.$1,
      outcomeDetail: result.$2,
      trajectory: List.unmodifiable(_trajectory),
      poses: List.unmodifiable(_poses),
      releasePose: _releasePose,
      loadPose: _loadPose,
      shooter: _shooterCourtPosition(),
      evidence: _evidence(flight, miss),
    );

    _reset();
    return shot;
  }

  TrackedShot _abandon() {
    final shot = TrackedShot(
      startedAtMs: _possessionSinceMs ?? _releasedAtMs ?? 0,
      releasedAtMs: _releasedAtMs ?? 0,
      endedAtMs: _releasedAtMs ?? 0,
      flight: null,
      miss: null,
      result: ShotResult.uncertain,
      outcomeDetail: ShotOutcomeDetail.undetermined,
      trajectory: List.unmodifiable(_trajectory),
      poses: List.unmodifiable(_poses),
      releasePose: _releasePose,
      loadPose: _loadPose,
      shooter: _shooterCourtPosition(),
      evidence: 0,
    );
    _reset();
    return shot;
  }

  /// Decides made or missed from where the ball crossed the ring.
  ///
  /// The ball is treated as a point at its centre, so the usable radius is the
  /// ring minus the ball. A centre that passes inside that went through; one
  /// that passes outside it did not.
  (ShotResult, ShotOutcomeDetail) _classify(
    ({double lateralCm, double depthCm})? miss,
  ) {
    if (miss == null || frame == null) {
      return (ShotResult.uncertain, ShotOutcomeDetail.undetermined);
    }

    final clearanceCm =
        (CourtDimensions.rimRadiusM - CourtDimensions.ballRadiusM) * 100;
    final offset = math.sqrt(
      miss.lateralCm * miss.lateralCm + miss.depthCm * miss.depthCm,
    );

    if (offset <= clearanceCm * 0.55) {
      return (ShotResult.made, ShotOutcomeDetail.swish);
    }
    if (offset <= clearanceCm) {
      return (ShotResult.made, ShotOutcomeDetail.rimMake);
    }

    // Which way it missed is the coaching signal, so the dominant axis decides
    // before the magnitude does. Distance alone would file a shot half a metre
    // wide of the ring as short, which tells the athlete to change the wrong
    // thing.
    if (miss.lateralCm.abs() >= miss.depthCm.abs()) {
      return (
        ShotResult.missed,
        miss.lateralCm > 0
            ? ShotOutcomeDetail.rightRim
            : ShotOutcomeDetail.leftRim,
      );
    }
    if (offset <= clearanceCm * 2.2) {
      return (
        ShotResult.missed,
        miss.depthCm > 0
            ? ShotOutcomeDetail.frontRim
            : ShotOutcomeDetail.backRim,
      );
    }
    // Depth-dominant and well outside the ring: under or over hit.
    return (
      ShotResult.missed,
      miss.depthCm > 0 ? ShotOutcomeDetail.short : ShotOutcomeDetail.long,
    );
  }

  CourtPosition? _shooterCourtPosition() {
    final solved = frame;
    final anchor = _cachedAnchor;
    if (solved == null || anchor == null) return null;
    return solved.toCourt(anchor);
  }

  double _evidence(
    FlightMeasurement? flight,
    ({double lateralCm, double depthCm})? miss,
  ) {
    if (frame == null || flight == null) return 0;
    final crossing = miss == null ? 0.5 : 1.0;
    return flight.evidence * crossing;
  }

  void _reset() {
    _samples.clear();
    _ballPixels.clear();
    _sizedHeights.clear();
    _trajectory.clear();
    _poses.clear();
    _phase = ShotPhaseKind.idle;
    _possessionSinceMs = null;
    _releasedAtMs = null;
    _releasePose = null;
    _loadPose = null;
    _deepestKnee = 180;
    _reachedRimPlane = false;
    _lowestHeightAfterRim = null;
    _cachedAnchor = null;
  }

  /// Maps COCO landmarks onto the fourteen joints the product draws and
  /// measures, in normalised preview coordinates.
  static PoseFrame poseFromDetection(
    PersonDetection person,
    int widthPx,
    int heightPx,
  ) {
    final landmarks = <PoseJoint, Offset>{};
    for (final entry in ModelContract.cocoIndexForJoint.entries) {
      final point = person.keypoints[entry.value];
      landmarks[entry.key] = Offset(point.x / widthPx, point.y / heightPx);
    }

    for (final entry in ModelContract.derivedJoints.entries) {
      final a = landmarks[entry.value.$1];
      final b = landmarks[entry.value.$2];
      if (a != null && b != null) {
        landmarks[entry.key] = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      }
    }

    return PoseFrame(landmarks: landmarks, confidence: person.meanScore);
  }
}
