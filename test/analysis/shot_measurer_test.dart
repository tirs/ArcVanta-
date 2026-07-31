import 'dart:math' as math;

import 'package:arcvanta/data/analysis/shot_measurer.dart';
import 'package:arcvanta/data/calibration/camera_intrinsics.dart';
import 'package:arcvanta/data/calibration/court_dimensions.dart';
import 'package:arcvanta/data/calibration/court_frame.dart';
import 'package:arcvanta/data/models/pose.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

const double _g = 9.80665;

/// Generates a true projectile from a known release, so the measurement can be
/// checked against the physics that produced it rather than against itself.
List<BallSample> _flight({
  required double releaseHeightM,
  required double releaseAngleDeg,
  required double releaseDistanceM,
  double lateralM = 0,
  int sampleHz = 60,
  double noiseM = 0,
  double? speedOverride,
}) {
  final angle = radians(releaseAngleDeg);

  // Pick the speed that lands the ball on the ring, so the flight is one a
  // shooter could actually take.
  final dropToRim = CourtDimensions.rimHeightM - releaseHeightM;
  final cos = math.cos(angle);
  final tan = math.tan(angle);
  final denominator =
      2 * cos * cos * (releaseDistanceM * tan - dropToRim);
  final speed = speedOverride ??
      math.sqrt(_g * releaseDistanceM * releaseDistanceM / denominator);

  final vGround = speed * cos;
  final vUp = speed * math.sin(angle);
  final flightTime = releaseDistanceM / vGround;

  final random = math.Random(19);
  final samples = <BallSample>[];
  final steps = (flightTime * sampleHz).floor();
  for (var i = 0; i <= steps; i++) {
    final t = i / sampleHz;
    final travelled = vGround * t;
    final height = releaseHeightM + vUp * t - 0.5 * _g * t * t;

    // The shooter starts at releaseDistance out and moves towards the ring.
    final remaining = releaseDistanceM - travelled;
    double jitter() => noiseM == 0 ? 0 : (random.nextDouble() - 0.5) * noiseM;

    samples.add(
      BallSample(
        timeMs: (t * 1000).round(),
        position: CourtPosition(
          lateralM: lateralM * remaining / releaseDistanceM + jitter(),
          depthM: remaining + jitter(),
          heightM: height + jitter(),
        ),
      ),
    );
  }
  return samples;
}

void main() {
  group('flight fitting recovers the physics it was generated from', () {
    test('a standard free throw', () {
      final measured = ShotMeasurer.measureFlight(
        _flight(
          releaseHeightM: 2.30,
          releaseAngleDeg: 52,
          releaseDistanceM: 4.19,
        ),
      )!;

      expect(measured.releaseAngleDeg, closeTo(52, 0.5));
      expect(measured.releaseHeightM, closeTo(2.30, 0.02));
      expect(measured.releaseDistanceM, closeTo(4.19, 0.05));
    });

    test('release angle across the coaching range', () {
      for (final angle in const [45.0, 48.0, 51.0, 55.0, 58.0]) {
        final measured = ShotMeasurer.measureFlight(
          _flight(
            releaseHeightM: 2.25,
            releaseAngleDeg: angle,
            releaseDistanceM: 5.0,
          ),
        )!;
        expect(measured.releaseAngleDeg, closeTo(angle, 0.5));
      }
    });

    test('entry angle is reported below horizontal and lands in range', () {
      final measured = ShotMeasurer.measureFlight(
        _flight(
          releaseHeightM: 2.30,
          releaseAngleDeg: 52,
          releaseDistanceM: 4.19,
        ),
      )!;

      // A 52 degree release from the line arrives around 45 to 48 degrees.
      expect(measured.entryAngleDeg, greaterThan(40));
      expect(measured.entryAngleDeg, lessThan(52));
    });

    test('a flatter shot enters flatter, which is the whole coaching point', () {
      double entryFor(double release) => ShotMeasurer.measureFlight(
        _flight(
          releaseHeightM: 2.3,
          releaseAngleDeg: release,
          releaseDistanceM: 5.0,
        ),
      )!.entryAngleDeg;

      expect(entryFor(44), lessThan(entryFor(50)));
      expect(entryFor(50), lessThan(entryFor(56)));
    });

    test('apex height matches the analytic apex', () {
      const releaseHeight = 2.3;
      const angle = 53.0;
      const distance = 4.6;

      final samples = _flight(
        releaseHeightM: releaseHeight,
        releaseAngleDeg: angle,
        releaseDistanceM: distance,
      );
      final measured = ShotMeasurer.measureFlight(samples)!;

      final trueApex = samples
          .map((s) => s.position.heightM)
          .reduce(math.max);
      // The sampled maximum sits just under the true apex, so the fit should
      // be at or a touch above it.
      expect(measured.apexHeightM, greaterThanOrEqualTo(trueApex - 0.01));
      expect(measured.apexHeightM, closeTo(trueApex, 0.05));
    });

    test('flight time matches the generated flight', () {
      final samples = _flight(
        releaseHeightM: 2.3,
        releaseAngleDeg: 52,
        releaseDistanceM: 4.19,
      );
      final measured = ShotMeasurer.measureFlight(samples)!;

      expect(
        measured.flightTimeMs,
        closeTo(samples.last.timeMs, 40),
      );
    });

    test('release speed is physically sane', () {
      final measured = ShotMeasurer.measureFlight(
        _flight(
          releaseHeightM: 2.3,
          releaseAngleDeg: 52,
          releaseDistanceM: 4.19,
        ),
      )!;
      // A free throw leaves the hand around 7 metres per second.
      expect(measured.releaseSpeedMs, greaterThan(6));
      expect(measured.releaseSpeedMs, lessThan(9));
    });

    test('a three pointer needs more speed than a free throw', () {
      double speedAt(double distance) => ShotMeasurer.measureFlight(
        _flight(
          releaseHeightM: 2.3,
          releaseAngleDeg: 50,
          releaseDistanceM: distance,
        ),
      )!.releaseSpeedMs;

      expect(speedAt(6.75), greaterThan(speedAt(4.19)));
    });

    test('a clean flight fits to within a centimetre', () {
      final measured = ShotMeasurer.measureFlight(
        _flight(
          releaseHeightM: 2.3,
          releaseAngleDeg: 52,
          releaseDistanceM: 4.19,
        ),
      )!;
      expect(measured.residualM, lessThan(0.01));
      expect(measured.evidence, greaterThan(0.9));
    });
  });

  group('evidence tracks how well the fit is supported', () {
    test('noisy tracking lowers evidence', () {
      final clean = ShotMeasurer.measureFlight(
        _flight(
          releaseHeightM: 2.3,
          releaseAngleDeg: 52,
          releaseDistanceM: 4.19,
        ),
      )!;
      final noisy = ShotMeasurer.measureFlight(
        _flight(
          releaseHeightM: 2.3,
          releaseAngleDeg: 52,
          releaseDistanceM: 4.19,
          noiseM: 0.12,
        ),
      )!;

      expect(noisy.residualM, greaterThan(clean.residualM));
      expect(noisy.evidence, lessThan(clean.evidence));
    });

    test('a sparse track lowers evidence even when it fits perfectly', () {
      final full = _flight(
        releaseHeightM: 2.3,
        releaseAngleDeg: 52,
        releaseDistanceM: 4.19,
      );
      // The ball was found on only every sixth frame: the fit is still exact,
      // but there is less of it to stand on.
      final sparse = [
        for (var i = 0; i < full.length; i += 6) full[i],
      ];
      expect(sparse.length, lessThan(12));

      final measured = ShotMeasurer.measureFlight(sparse)!;
      expect(measured.residualM, lessThan(0.01));
      expect(measured.evidence, lessThan(0.85));
      expect(
        measured.evidence,
        lessThan(ShotMeasurer.measureFlight(full)!.evidence),
      );
    });

    test('a flight cut too short to span any distance is refused', () {
      final full = _flight(
        releaseHeightM: 2.3,
        releaseAngleDeg: 52,
        releaseDistanceM: 4.19,
      );
      // A tenth of a second of tracking covers half a metre, which is not a
      // shot arc no matter how cleanly it fits.
      expect(ShotMeasurer.measureFlight(full.take(6).toList()), isNull);
    });

    test('noisy tracking still recovers the angle to within a few degrees', () {
      final measured = ShotMeasurer.measureFlight(
        _flight(
          releaseHeightM: 2.3,
          releaseAngleDeg: 52,
          releaseDistanceM: 4.19,
          noiseM: 0.05,
        ),
      )!;
      expect(measured.releaseAngleDeg, closeTo(52, 3));
    });
  });

  group('refuses to measure what it cannot', () {
    test('too few samples', () {
      expect(
        ShotMeasurer.measureFlight([
          for (var i = 0; i < 4; i++)
            BallSample(
              timeMs: i * 16,
              position: CourtPosition(
                lateralM: 0,
                depthM: 4.0 - i * 0.1,
                heightM: 2.4,
              ),
            ),
        ]),
        isNull,
      );
    });

    test('a ball that never travels', () {
      expect(
        ShotMeasurer.measureFlight([
          for (var i = 0; i < 20; i++)
            BallSample(
              timeMs: i * 16,
              position: const CourtPosition(
                lateralM: 0,
                depthM: 4.0,
                heightM: 2.4,
              ),
            ),
        ]),
        isNull,
      );
    });
  });

  group('miss at the ring', () {
    test('interpolates the crossing rather than taking the nearest sample', () {
      final samples = [
        const BallSample(
          timeMs: 0,
          position: CourtPosition(lateralM: 0.10, depthM: 0.20, heightM: 3.20),
        ),
        const BallSample(
          timeMs: 16,
          position: CourtPosition(lateralM: 0.06, depthM: 0.10, heightM: 2.90),
        ),
      ];

      final miss = ShotMeasurer.missAtRim(samples)!;

      // Rim height sits just over half way between the two heights.
      final t = (3.20 - CourtDimensions.rimHeightM) / (3.20 - 2.90);
      expect(miss.lateralCm, closeTo((0.10 + (0.06 - 0.10) * t) * 100, 0.01));
      expect(miss.depthCm, closeTo((0.20 + (0.10 - 0.20) * t) * 100, 0.01));
    });

    test('a swish reads near zero on both axes', () {
      final samples = [
        const BallSample(
          timeMs: 0,
          position: CourtPosition(lateralM: 0.002, depthM: 0.004, heightM: 3.1),
        ),
        const BallSample(
          timeMs: 16,
          position: CourtPosition(lateralM: 0.001, depthM: 0.002, heightM: 3.0),
        ),
      ];

      final miss = ShotMeasurer.missAtRim(samples)!;
      expect(miss.lateralCm.abs(), lessThan(1));
      expect(miss.depthCm.abs(), lessThan(1));
    });

    test('null when the ball never reaches the ring', () {
      expect(
        ShotMeasurer.missAtRim([
          for (var i = 0; i < 10; i++)
            BallSample(
              timeMs: i * 16,
              position: CourtPosition(
                lateralM: 0,
                depthM: 2.0,
                heightM: 2.5 - i * 0.05,
              ),
            ),
        ]),
        isNull,
      );
    });
  });

  group('joint angles', () {
    PoseFrame poseWith(Map<PoseJoint, Offset> landmarks) =>
        PoseFrame(landmarks: landmarks, confidence: 0.9);

    test('a right angle reads ninety degrees', () {
      final pose = poseWith({
        PoseJoint.rightShoulder: const Offset(0.5, 0.3),
        PoseJoint.rightElbow: const Offset(0.5, 0.5),
        PoseJoint.rightWrist: const Offset(0.7, 0.5),
      });

      expect(
        ShotMeasurer.elbowAngle(pose, rightHanded: true),
        closeTo(90, 1e-6),
      );
    });

    test('a straight arm reads a hundred and eighty', () {
      final pose = poseWith({
        PoseJoint.rightShoulder: const Offset(0.5, 0.2),
        PoseJoint.rightElbow: const Offset(0.5, 0.5),
        PoseJoint.rightWrist: const Offset(0.5, 0.8),
      });

      expect(
        ShotMeasurer.elbowAngle(pose, rightHanded: true),
        closeTo(180, 1e-6),
      );
    });

    test('null when a landmark is missing', () {
      final pose = poseWith({
        PoseJoint.rightShoulder: const Offset(0.5, 0.3),
        PoseJoint.rightElbow: const Offset(0.5, 0.5),
      });

      expect(ShotMeasurer.elbowAngle(pose, rightHanded: true), isNull);
    });

    test('deepest knee flexion picks the bottom of the load', () {
      final poses = [
        for (final bend in const [170.0, 150.0, 124.0, 138.0])
          poseWith({
            PoseJoint.rightHip: const Offset(0.5, 0.4),
            PoseJoint.rightKnee: const Offset(0.5, 0.6),
            PoseJoint.rightAnkle: Offset(
              0.5 + 0.2 * math.sin(radians(180 - bend)),
              0.6 + 0.2 * math.cos(radians(180 - bend)),
            ),
          }),
      ];

      expect(
        ShotMeasurer.deepestKneeFlexion(poses, rightHanded: true),
        closeTo(124, 0.5),
      );
    });
  });

  test('landing drift is measured on the floor, in centimetres', () {
    final frame = CourtFrame(
      intrinsics: _intrinsics,
      rimCentre: Vector3(0, -2.048, 6.0),
      up: Vector3(0, -1, 0),
      backAxis: Vector3(0, 0, 1),
    );

    const start = CourtPosition(lateralM: 0, depthM: 4.5, heightM: 0);
    const end = CourtPosition(lateralM: 0.09, depthM: 4.44, heightM: 0);

    final drift = ShotMeasurer.landingDriftCm(
      frame: frame,
      startFootPixel: _intrinsics.projectToPixel(frame.fromCourt(start))!,
      endFootPixel: _intrinsics.projectToPixel(frame.fromCourt(end))!,
    )!;

    expect(drift, closeTo(math.sqrt(0.09 * 0.09 + 0.06 * 0.06) * 100, 0.1));
  });
}

final _intrinsics = CameraIntrinsics.fromHorizontalFov(
  fovDegrees: 68,
  widthPx: 1920,
  heightPx: 1080,
);
