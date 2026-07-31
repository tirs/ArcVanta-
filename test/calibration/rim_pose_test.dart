import 'dart:math' as math;

import 'package:arcvanta/data/calibration/camera_intrinsics.dart';
import 'package:arcvanta/data/calibration/conic.dart';
import 'package:arcvanta/data/calibration/court_dimensions.dart';
import 'package:arcvanta/data/calibration/rim_pose.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

final _intrinsics = CameraIntrinsics.fromHorizontalFov(
  fovDegrees: 68,
  widthPx: 1920,
  heightPx: 1080,
);

/// Two orthonormal directions spanning the plane with the given normal.
(Vector3, Vector3) _planeBasis(Vector3 normal) {
  final seed = normal.x.abs() < 0.9 ? Vector3(1, 0, 0) : Vector3(0, 1, 0);
  final e1 = seed.cross(normal).normalized();
  final e2 = normal.cross(e1).normalized();
  return (e1, e2);
}

/// Projects a circle in camera space into a pixel-space conic, the same way a
/// real camera would.
Conic? _imageOfCircle({
  required Vector3 centre,
  required Vector3 normal,
  double radius = CourtDimensions.rimRadiusM,
  int samples = 64,
  double noisePx = 0,
}) {
  final (e1, e2) = _planeBasis(normal.normalized());
  final random = math.Random(3);
  final points = <Vector2>[];

  for (var i = 0; i < samples; i++) {
    final t = 2 * math.pi * i / samples;
    final world =
        centre + e1 * (radius * math.cos(t)) + e2 * (radius * math.sin(t));
    final pixel = _intrinsics.projectToPixel(world);
    if (pixel == null) return null;
    points.add(
      noisePx == 0
          ? pixel
          : Vector2(
              pixel.x + (random.nextDouble() - 0.5) * noisePx,
              pixel.y + (random.nextDouble() - 0.5) * noisePx,
            ),
    );
  }

  return Conic.fitToPoints(points);
}

void _expectRecovers({
  required Vector3 centre,
  required Vector3 normal,
  double radius = CourtDimensions.rimRadiusM,
  double centreToleranceM = 0.02,
  double normalToleranceDeg = 1.5,
  double noisePx = 0,
}) {
  final unitNormal = normal.normalized();
  final conic = _imageOfCircle(
    centre: centre,
    normal: unitNormal,
    radius: radius,
    noisePx: noisePx,
  );
  expect(conic, isNotNull, reason: 'circle did not project to an ellipse');

  final solution = RimPoseSolver.solve(
    imageConic: conic!,
    radiusM: radius,
    intrinsics: _intrinsics,
    cameraUp: unitNormal,
  );
  expect(solution, isNotNull, reason: 'solver returned nothing');

  final pose = solution!.chosen;
  expect(
    (pose.centre - centre).length,
    lessThan(centreToleranceM),
    reason: 'centre ${pose.centre} should be $centre',
  );

  final angle = degrees(
    math.acos(pose.normal.dot(unitNormal).abs().clamp(0.0, 1.0)),
  );
  expect(
    angle,
    lessThan(normalToleranceDeg),
    reason: 'normal ${pose.normal} should be $unitNormal',
  );
}

void main() {
  group('recovers a known circle pose', () {
    test('rim straight ahead, camera level, viewed from below', () {
      // Phone at 1 m, rim at 3.05 m, 6 m away: the ring is above the camera so
      // it appears as a flattened ellipse seen from underneath.
      _expectRecovers(
        centre: Vector3(0, -2.05, 6.0),
        normal: Vector3(0, -1, 0),
      );
    });

    test('rim off to one side', () {
      _expectRecovers(
        centre: Vector3(1.8, -1.9, 5.4),
        normal: Vector3(0, -1, 0),
      );
    });

    test('camera pitched up so the rim sits near the image centre', () {
      // Pitching the camera up by 18 degrees rotates the world about x.
      final pitch = radians(18.0);
      final rotation = Matrix3.rotationX(pitch);
      _expectRecovers(
        centre: rotation.transformed(Vector3(0, -2.05, 6.0)),
        normal: rotation.transformed(Vector3(0, -1, 0)),
      );
    });

    test('camera rolled, as on a hand-held or badly levelled tripod', () {
      final rotation = Matrix3.rotationZ(radians(9.0))
        ..multiply(Matrix3.rotationX(radians(14.0)));
      _expectRecovers(
        centre: rotation.transformed(Vector3(0.4, -2.0, 5.8)),
        normal: rotation.transformed(Vector3(0, -1, 0)),
      );
    });

    test('close placement, three metres out', () {
      _expectRecovers(centre: Vector3(0, -1.6, 3.0), normal: Vector3(0, -1, 0));
    });

    test('far placement, nine metres out', () {
      _expectRecovers(
        centre: Vector3(0, -2.1, 9.0),
        normal: Vector3(0, -1, 0),
        centreToleranceM: 0.05,
      );
    });

    test('sweeps distance and lateral offset', () {
      for (final distance in const [4.0, 5.5, 7.0, 8.5]) {
        for (final lateral in const [-2.5, -1.0, 0.0, 1.0, 2.5]) {
          _expectRecovers(
            centre: Vector3(lateral, -2.0, distance),
            normal: Vector3(0, -1, 0),
            centreToleranceM: 0.05,
          );
        }
      }
    });
  });

  test('recovers scale, which is what every metric measurement needs', () {
    // The absolute distance is the part that cannot be guessed from the image.
    const trueDistance = 6.4;
    final conic = _imageOfCircle(
      centre: Vector3(0, -2.0, trueDistance),
      normal: Vector3(0, -1, 0),
      radius: CourtDimensions.rimRadiusM,
    )!;

    final pose = RimPoseSolver.solve(
      imageConic: conic,
      radiusM: CourtDimensions.rimRadiusM,
      intrinsics: _intrinsics,
      cameraUp: Vector3(0, -1, 0),
    )!.chosen;

    expect(pose.centre.z, closeTo(trueDistance, 0.03));
  });

  test('a wrong radius scales the whole solve proportionally', () {
    final conic = _imageOfCircle(
      centre: Vector3(0, -2.0, 6.0),
      normal: Vector3(0, -1, 0),
      radius: CourtDimensions.rimRadiusM,
    )!;

    final halfRadius = RimPoseSolver.solve(
      imageConic: conic,
      radiusM: CourtDimensions.rimRadiusM / 2,
      intrinsics: _intrinsics,
      cameraUp: Vector3(0, -1, 0),
    )!.chosen;

    expect(halfRadius.centre.z, closeTo(3.0, 0.05));
  });

  test('tolerates a few pixels of detection noise', () {
    _expectRecovers(
      centre: Vector3(0.5, -2.0, 6.0),
      normal: Vector3(0, -1, 0),
      centreToleranceM: 0.20,
      normalToleranceDeg: 6,
      noisePx: 3.0,
    );
  });

  test('reports both mirror solutions', () {
    final conic = _imageOfCircle(
      centre: Vector3(0, -2.05, 6.0),
      normal: Vector3(0, -1, 0),
    )!;

    final solution = RimPoseSolver.solve(
      imageConic: conic,
      radiusM: CourtDimensions.rimRadiusM,
      intrinsics: _intrinsics,
      cameraUp: Vector3(0, -1, 0),
    )!;

    expect(solution.tiltSeparationDegrees, greaterThan(0));
    expect(
      solution.chosen.normal.dot(Vector3(0, -1, 0)),
      greaterThanOrEqualTo(solution.rejected.normal.dot(Vector3(0, -1, 0))),
    );
  });

  test('gravity picks the intended mirror solution', () {
    // Tilt the rim plane away from horizontal so the two solutions genuinely
    // differ, then confirm the supplied up vector selects the right one.
    final normal = Vector3(0.22, -1, 0.10).normalized();
    final centre = Vector3(0, -2.0, 6.0);
    final conic = _imageOfCircle(centre: centre, normal: normal)!;

    final solution = RimPoseSolver.solve(
      imageConic: conic,
      radiusM: CourtDimensions.rimRadiusM,
      intrinsics: _intrinsics,
      cameraUp: normal,
    )!;

    final chosenAngle = degrees(
      math.acos(solution.chosen.normal.dot(normal).clamp(-1.0, 1.0)),
    );
    expect(chosenAngle, lessThan(2));
  });

  group('rejects input that is not a rim', () {
    test('null for a non-positive radius', () {
      final conic = Conic.fromEllipse(
        EllipseParams(
          centre: Vector2(960, 540),
          semiMajor: 100,
          semiMinor: 40,
          rotation: 0,
        ),
      );
      expect(
        RimPoseSolver.solve(
          imageConic: conic,
          radiusM: 0,
          intrinsics: _intrinsics,
        ),
        isNull,
      );
    });

    test('null for a hyperbola', () {
      expect(
        RimPoseSolver.solve(
          imageConic: const Conic(1, 0, -1, 0, 0, -1),
          radiusM: CourtDimensions.rimRadiusM,
          intrinsics: _intrinsics,
        ),
        isNull,
      );
    });
  });
}
