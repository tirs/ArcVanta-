import 'dart:math' as math;

import 'package:arcvanta/data/calibration/camera_intrinsics.dart';
import 'package:arcvanta/data/calibration/court_dimensions.dart';
import 'package:arcvanta/data/calibration/court_frame.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

final _intrinsics = CameraIntrinsics.fromHorizontalFov(
  fovDegrees: 68,
  widthPx: 1920,
  heightPx: 1080,
);

/// A level phone 1 m off the floor, 6 m out from the hoop, looking straight
/// down the court. Camera y runs down, so up is -y.
CourtFrame _levelFrame({double cameraHeightM = 1.0, double distanceM = 6.0}) {
  return CourtFrame(
    intrinsics: _intrinsics,
    rimCentre: Vector3(
      0,
      -(CourtDimensions.rimHeightM - cameraHeightM),
      distanceM,
    ),
    up: Vector3(0, -1, 0),
    backAxis: Vector3(0, 0, 1),
  );
}

void main() {
  group('court axes', () {
    test('floor origin sits a rim height below the ring', () {
      final frame = _levelFrame();
      expect(
        (frame.rimCentre - frame.floorOrigin).length,
        closeTo(CourtDimensions.rimHeightM, 1e-12),
      );
      expect(frame.floorOrigin.y, closeTo(1.0, 1e-12));
    });

    test('axes are orthonormal and right handed', () {
      final frame = _levelFrame();
      expect(frame.up.length, closeTo(1, 1e-12));
      expect(frame.backAxis.length, closeTo(1, 1e-12));
      expect(frame.lateralAxis.length, closeTo(1, 1e-12));
      expect(frame.up.dot(frame.backAxis), closeTo(0, 1e-12));
      expect(frame.up.dot(frame.lateralAxis), closeTo(0, 1e-12));
      expect(frame.backAxis.dot(frame.lateralAxis), closeTo(0, 1e-12));
    });

    test('a back axis that is not level is projected into the floor plane', () {
      final frame = CourtFrame(
        intrinsics: _intrinsics,
        rimCentre: Vector3(0, -2.05, 6),
        up: Vector3(0, -1, 0),
        backAxis: Vector3(0, -0.45, 1),
      );
      expect(frame.up.dot(frame.backAxis), closeTo(0, 1e-12));
    });
  });

  group('court coordinates round trip', () {
    test('the ring is directly above the origin at rim height', () {
      final frame = _levelFrame();
      final rim = frame.toCourt(frame.rimCentre);
      expect(rim.lateralM, closeTo(0, 1e-9));
      expect(rim.depthM, closeTo(0, 1e-9));
      expect(rim.heightM, closeTo(CourtDimensions.rimHeightM, 1e-9));
    });

    test('fromCourt inverts toCourt', () {
      final frame = _levelFrame();
      for (final position in const [
        CourtPosition(lateralM: 1.5, depthM: 4.2, heightM: 0),
        CourtPosition(lateralM: -2.3, depthM: 6.75, heightM: 2.4),
        CourtPosition(lateralM: 0, depthM: 0, heightM: 3.048),
      ]) {
        final round = frame.toCourt(frame.fromCourt(position));
        expect(round.lateralM, closeTo(position.lateralM, 1e-9));
        expect(round.depthM, closeTo(position.depthM, 1e-9));
        expect(round.heightM, closeTo(position.heightM, 1e-9));
      }
    });

    test('depth increases away from the backboard', () {
      final frame = _levelFrame();
      // The camera sits out on the court, so it is at positive depth.
      expect(frame.toCourt(Vector3.zero()).depthM, greaterThan(0));
    });
  });

  group('measuring from pixels', () {
    test('a point on the floor projects and unprojects to itself', () {
      final frame = _levelFrame();
      const truth = CourtPosition(lateralM: 1.2, depthM: 4.8, heightM: 0);

      final pixel = _intrinsics.projectToPixel(frame.fromCourt(truth))!;
      final measured = frame.shooterPosition(pixel)!;

      expect(measured.lateralM, closeTo(truth.lateralM, 1e-6));
      expect(measured.depthM, closeTo(truth.depthM, 1e-6));
      expect(measured.heightM, closeTo(0, 1e-9));
    });

    test('recovers a shooter standing at the free-throw line', () {
      final frame = _levelFrame();
      final truth = CourtPosition(
        lateralM: 0,
        depthM: CourtDimensions.freeThrowToBackboardM -
            CourtDimensions.rimRadiusM -
            CourtDimensions.rimOffsetFromBackboardM,
        heightM: 0,
      );

      final pixel = _intrinsics.projectToPixel(frame.fromCourt(truth))!;
      expect(
        frame.shooterPosition(pixel)!.depthM,
        closeTo(truth.depthM, 1e-6),
      );
    });

    test('a ball in the shot plane recovers its height', () {
      final frame = _levelFrame();
      final shooter = frame.fromCourt(
        const CourtPosition(lateralM: 0.2, depthM: 6.0, heightM: 0),
      );
      const ball = CourtPosition(lateralM: 0.15, depthM: 4.5, heightM: 3.9);

      final pixel = _intrinsics.projectToPixel(frame.fromCourt(ball))!;
      final measured = frame.ballInShotPlane(
        ballPixel: pixel,
        shooterFloorPoint: shooter,
      )!;

      // The shot plane runs through the ring and the shooter, so a ball that
      // truly lies in it comes back exactly.
      expect(measured.heightM, closeTo(ball.heightM, 0.02));
      expect(measured.depthM, closeTo(ball.depthM, 0.02));
    });

    test('the shot plane needs a shooter away from the ring', () {
      final frame = _levelFrame();
      expect(frame.shotPlaneThrough(frame.floorOrigin), isNull);
    });
  });

  group('miss at the ring', () {
    test('dead centre reads zero', () {
      final frame = _levelFrame();
      final pixel = frame.projectRimCentre()!;
      final miss = frame.missAtRim(pixel)!;
      expect(miss.lateralCm, closeTo(0, 1e-6));
      expect(miss.depthCm, closeTo(0, 1e-6));
    });

    test('a known offset reads back in centimetres', () {
      final frame = _levelFrame();
      final offset = frame.rimCentre +
          frame.lateralAxis * 0.07 +
          frame.backAxis * -0.04;

      final miss = frame.missAtRim(_intrinsics.projectToPixel(offset)!)!;

      expect(miss.lateralCm, closeTo(7, 0.01));
      expect(miss.depthCm, closeTo(4, 0.01));
    });
  });

  group('ball depth from apparent size', () {
    test('agrees with the true distance', () {
      final frame = _levelFrame();
      const distance = 5.0;
      final radiusPx =
          _intrinsics.focalXPx * CourtDimensions.ballRadiusM / distance;

      expect(frame.ballDepthFromRadius(radiusPx), closeTo(distance, 1e-9));
    });

    test('rejects a radius too small to mean anything', () {
      expect(_levelFrame().ballDepthFromRadius(0.2), isNull);
    });
  });

  group('rim reprojection', () {
    test('the outline is centred on the ring and the right size', () {
      final frame = _levelFrame();
      final outline = frame.projectRimOutline();
      expect(outline.length, 48);

      final centre = frame.projectRimCentre()!;
      var maxRadius = 0.0;
      for (final point in outline) {
        maxRadius = math.max(maxRadius, (point - centre).length);
      }

      // Half the ring's angular width at this distance, in pixels.
      final expected = _intrinsics.focalXPx *
          CourtDimensions.rimRadiusM /
          frame.rimCentre.z;
      expect(maxRadius, closeTo(expected, expected * 0.05));
    });
  });

  test('a tilted camera still measures the floor correctly', () {
    final pitch = Matrix3.rotationX(radians(20.0));
    final frame = CourtFrame(
      intrinsics: _intrinsics,
      rimCentre: pitch.transformed(Vector3(0, -2.048, 6)),
      up: pitch.transformed(Vector3(0, -1, 0)),
      backAxis: pitch.transformed(Vector3(0, 0, 1)),
    );

    const truth = CourtPosition(lateralM: -1.1, depthM: 5.2, heightM: 0);
    final pixel = _intrinsics.projectToPixel(frame.fromCourt(truth))!;
    final measured = frame.shooterPosition(pixel)!;

    expect(measured.lateralM, closeTo(truth.lateralM, 1e-6));
    expect(measured.depthM, closeTo(truth.depthM, 1e-6));
  });

  test('rays that miss the plane return nothing', () {
    final frame = _levelFrame();
    // Far above the horizon, so the floor plane is never reached.
    expect(frame.pointOnFloor(Vector2(960, -40000)), isNull);
  });
}
