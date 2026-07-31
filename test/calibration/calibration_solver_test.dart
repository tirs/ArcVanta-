import 'dart:math' as math;

import 'package:arcvanta/data/calibration/calibration_solver.dart';
import 'package:arcvanta/data/calibration/camera_intrinsics.dart';
import 'package:arcvanta/data/calibration/conic.dart';
import 'package:arcvanta/data/calibration/court_dimensions.dart';
import 'package:arcvanta/data/calibration/court_frame.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

final _intrinsics = CameraIntrinsics.fromHorizontalFov(
  fovDegrees: 68,
  widthPx: 1920,
  heightPx: 1080,
);

/// Renders the ring as a real camera would see it, then reads the ellipse back
/// out, so the solver is fed the same shape a detector would produce.
RimObservation _observeRim({
  required Vector3 rimCentre,
  required Vector3 up,
  RimObservationSource source = RimObservationSource.detector,
  double detectorConfidence = 0.95,
  double noisePx = 0,
}) {
  final normal = up.normalized();
  final seed = normal.x.abs() < 0.9 ? Vector3(1, 0, 0) : Vector3(0, 1, 0);
  final e1 = seed.cross(normal).normalized();
  final e2 = normal.cross(e1).normalized();

  final random = math.Random(5);
  final points = <Vector2>[];
  for (var i = 0; i < 48; i++) {
    final t = 2 * math.pi * i / 48;
    final world = rimCentre +
        e1 * (CourtDimensions.rimRadiusM * math.cos(t)) +
        e2 * (CourtDimensions.rimRadiusM * math.sin(t));
    final pixel = _intrinsics.projectToPixel(world)!;
    points.add(
      noisePx == 0
          ? pixel
          : Vector2(
              pixel.x + (random.nextDouble() - 0.5) * noisePx,
              pixel.y + (random.nextDouble() - 0.5) * noisePx,
            ),
    );
  }

  return RimObservation(
    ellipse: Conic.fitToPoints(points)!.toEllipse()!,
    source: source,
    detectorConfidence: detectorConfidence,
    outlinePoints: points,
  );
}

/// The placement the guide asks for: tripod at about 1.1 m, 6 m out, pitched
/// up far enough to hold the ring and the ball's apex in frame.
final _pitch = Matrix3.rotationX(radians(13.0));
final _rimCentre = _pitch.transformed(Vector3(0, -1.95, 6.0));
final _up = _pitch.transformed(Vector3(0, -1, 0));

void main() {
  group('a good setup', () {
    late CalibrationSolution solution;

    setUp(() {
      solution = CalibrationSolver.solve(
        rim: _observeRim(rimCentre: _rimCentre, up: _up),
        intrinsics: _intrinsics,
        gravity: -_up,
      );
    });

    test('solves', () {
      expect(solution.isUsable, isTrue);
      expect(solution.failure, isNull);
    });

    test('recovers the ring position', () {
      expect((solution.frame!.rimCentre - _rimCentre).length, lessThan(0.05));
    });

    test('reprojects tightly', () {
      expect(solution.reprojectionErrorPx, lessThan(2.0));
    });

    test('scores high overall', () {
      expect(solution.overall, greaterThan(0.75));
    });

    test('reports the five factors the athlete sees', () {
      expect(
        solution.factors.map((f) => f.label),
        containsAll(<String>[
          'Court plane',
          'Rim reference',
          'Lighting',
          'Stability',
          'Framing',
        ]),
      );
    });

    test('does not claim to have measured the rim height', () {
      expect(solution.rimHeightAssumed, isTrue);
    });

    test('the floor it derives is a rim height below the ring', () {
      final frame = solution.frame!;
      expect(
        (frame.rimCentre - frame.floorOrigin).length,
        closeTo(CourtDimensions.rimHeightM, 1e-9),
      );
    });
  });

  group('refuses to produce a frame it cannot stand behind', () {
    test('no rim at all', () {
      final solution = CalibrationSolver.solve(
        rim: null,
        intrinsics: _intrinsics,
      );
      expect(solution.isUsable, isFalse);
      expect(solution.failure, CalibrationFailure.noRim);
      expect(solution.overall, 0);
    });

    test('rim too small to measure', () {
      final solution = CalibrationSolver.solve(
        rim: RimObservation(
          ellipse: EllipseParams(
            centre: Vector2(960, 400),
            semiMajor: 6,
            semiMinor: 2,
            rotation: 0,
          ),
          source: RimObservationSource.detector,
        ),
        intrinsics: _intrinsics,
      );
      expect(solution.failure, CalibrationFailure.rimTooSmall);
    });

    test('an edge-on ellipse carries no geometry', () {
      final solution = CalibrationSolver.solve(
        rim: RimObservation(
          ellipse: EllipseParams(
            centre: Vector2(960, 400),
            semiMajor: 90,
            semiMinor: 0.2,
            rotation: 0,
          ),
          source: RimObservationSource.detector,
        ),
        intrinsics: _intrinsics,
      );
      expect(solution.failure, CalibrationFailure.degenerateEllipse);
    });

    test('a ring that solves to an absurd distance', () {
      // A ring filling the frame would have to be centimetres away.
      final solution = CalibrationSolver.solve(
        rim: RimObservation(
          ellipse: EllipseParams(
            centre: Vector2(960, 540),
            semiMajor: 900,
            semiMinor: 880,
            rotation: 0,
          ),
          source: RimObservationSource.detector,
        ),
        intrinsics: _intrinsics,
      );
      expect(solution.isUsable, isFalse);
      expect(solution.failure, CalibrationFailure.implausibleGeometry);
    });
  });

  group('the score tracks the things that actually hurt accuracy', () {
    double scoreFor({
      CaptureConditions conditions = const CaptureConditions(),
      Vector3? gravity,
      CameraIntrinsics? intrinsics,
      RimObservation? rim,
    }) =>
        CalibrationSolver.solve(
          rim: rim ?? _observeRim(rimCentre: _rimCentre, up: _up),
          intrinsics: intrinsics ?? _intrinsics,
          conditions: conditions,
          gravity: gravity ?? -_up,
        ).overall;

    test('a dark gym scores below a well lit one', () {
      expect(
        scoreFor(conditions: const CaptureConditions(meanLuma: 0.12)),
        lessThan(scoreFor()),
      );
    });

    test('blown highlights score below even exposure', () {
      expect(
        scoreFor(conditions: const CaptureConditions(lumaClippedFraction: 0.2)),
        lessThan(scoreFor()),
      );
    });

    test('no tripod scores below a mounted phone', () {
      expect(
        scoreFor(
          conditions: const CaptureConditions(
            hasTripod: false,
            motionPixelsPerFrame: 2.4,
          ),
        ),
        lessThan(scoreFor()),
      );
    });

    test('thirty fps scores below sixty', () {
      expect(
        scoreFor(conditions: const CaptureConditions(frameRate: 30)),
        lessThan(scoreFor()),
      );
    });

    test('an assumed focal length scores below one read from the camera', () {
      expect(
        scoreFor(
          intrinsics: CameraIntrinsics.assumed(widthPx: 1920, heightPx: 1080),
        ),
        lessThan(scoreFor()),
      );
    });

    test('a hand-marked ring scores below a confident detection', () {
      expect(
        scoreFor(
          rim: _observeRim(
            rimCentre: _rimCentre,
            up: _up,
            source: RimObservationSource.manual,
          ),
        ),
        lessThan(scoreFor()),
      );
    });

    test('a distant, small ring scores below a close one', () {
      expect(
        scoreFor(
          rim: _observeRim(rimCentre: Vector3(0, -2.048, 13.0), up: _up),
        ),
        lessThan(scoreFor()),
      );
    });

    test('noisy detection scores below clean detection', () {
      expect(
        scoreFor(
          rim: _observeRim(rimCentre: _rimCentre, up: _up, noisePx: 6),
        ),
        lessThan(scoreFor()),
      );
    });

    test('one bad factor drags the whole score, it is not averaged away', () {
      final crippled = CalibrationSolver.solve(
        rim: _observeRim(rimCentre: _rimCentre, up: _up),
        intrinsics: _intrinsics,
        gravity: -_up,
        conditions: const CaptureConditions(
          meanLuma: 0.02,
          lumaClippedFraction: 0.24,
        ),
      );
      // Four strong factors and one near-zero: an arithmetic mean would still
      // read around 0.8, which would be a lie.
      expect(crippled.overall, lessThan(0.6));
    });
  });

  test('the solved frame measures a known court position', () {
    final frame = CalibrationSolver.solve(
      rim: _observeRim(rimCentre: _rimCentre, up: _up),
      intrinsics: _intrinsics,
      gravity: -_up,
    ).frame!;

    // Somewhere out on the court, projected through the true camera and read
    // back through the solved frame.
    final truth = CourtFrame(
      intrinsics: _intrinsics,
      rimCentre: _rimCentre,
      up: _up,
      backAxis: _pitch.transformed(Vector3(0, 0, 1)),
    );
    const spot = CourtPosition(lateralM: 1.4, depthM: 5.5, heightM: 0);
    final pixel = _intrinsics.projectToPixel(truth.fromCourt(spot))!;

    final measured = frame.shooterPosition(pixel)!;
    expect(measured.depthM, closeTo(spot.depthM, 0.15));
    expect(measured.lateralM.abs(), closeTo(spot.lateralM.abs(), 0.15));
  });

  test('a phone set up too close cannot frame the shooting area', () {
    // At two and a half metres the ring fills the frame and the athlete's
    // stepping room falls off both edges.
    final close = CalibrationSolver.solve(
      rim: _observeRim(
        rimCentre: _pitch.transformed(Vector3(0, -1.95, 2.5)),
        up: _up,
      ),
      intrinsics: _intrinsics,
      gravity: -_up,
    );
    final good = CalibrationSolver.solve(
      rim: _observeRim(rimCentre: _rimCentre, up: _up),
      intrinsics: _intrinsics,
      gravity: -_up,
    );

    double framing(CalibrationSolution s) =>
        s.factors.firstWhere((f) => f.label == 'Framing').score;

    expect(framing(close), lessThan(framing(good)));
  });

  test('a backboard detection fixes the direction the shot faces', () {
    final withBoard = CalibrationSolver.solve(
      rim: _observeRim(rimCentre: _rimCentre, up: _up),
      intrinsics: _intrinsics,
      gravity: -_up,
      backboard: BackboardObservation(
        centre: Vector2(960, 180),
        widthPx: 420,
        heightPx: 240,
      ),
    );

    expect(withBoard.isUsable, isTrue);
    // The board is beyond the ring, so the back axis points away from camera.
    expect(withBoard.frame!.backAxis.z, greaterThan(0));
  });
}
