import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'camera_intrinsics.dart';
import 'court_dimensions.dart';

/// A position on the court, in metres, relative to the point on the floor
/// directly below the centre of the ring.
class CourtPosition {
  const CourtPosition({
    required this.lateralM,
    required this.depthM,
    required this.heightM,
  });

  /// Across the court. Positive is towards the camera's right along the
  /// backboard face.
  final double lateralM;

  /// Out from the backboard. Positive is away from the board, onto the court.
  final double depthM;

  /// Above the floor.
  final double heightM;

  double get groundDistanceM => math.sqrt(lateralM * lateralM + depthM * depthM);

  @override
  String toString() =>
      'CourtPosition(lateral: ${lateralM.toStringAsFixed(3)}m, '
      'depth: ${depthM.toStringAsFixed(3)}m, '
      'height: ${heightM.toStringAsFixed(3)}m)';
}

/// A plane in camera coordinates.
class ScenePlane {
  ScenePlane({required this.point, required Vector3 normal})
    : normal = normal.normalized();

  final Vector3 point;
  final Vector3 normal;

  double signedDistanceTo(Vector3 other) => normal.dot(other - point);
}

/// The solved scene: where the ring is, which way is up, and where the floor
/// and the backboard sit relative to it.
///
/// This is the object every metric measurement goes through. A pixel on its
/// own carries no scale; a pixel plus a plane to intersect it with becomes a
/// position in metres, and that is the only honest way to turn a phone video
/// into a release height or a lateral miss in centimetres.
class CourtFrame {
  CourtFrame({
    required this.intrinsics,
    required this.rimCentre,
    required Vector3 up,
    required Vector3 backAxis,
    this.rimHeightM = CourtDimensions.rimHeightM,
  }) : up = up.normalized(),
       // Force the backboard direction into the floor plane so the axes stay
       // orthonormal even when the detection that produced it was rough.
       backAxis = (backAxis - up.normalized() * up.normalized().dot(backAxis))
           .normalized();

  final CameraIntrinsics intrinsics;

  /// Centre of the ring, camera coordinates, metres.
  final Vector3 rimCentre;

  /// Unit up, camera coordinates. The floor normal.
  final Vector3 up;

  /// Unit horizontal direction from the ring towards the backboard.
  final Vector3 backAxis;

  /// Height of the ring above the floor. Regulation unless the calibration
  /// measured something else and the caller chose to trust it.
  final double rimHeightM;

  /// Across the court, completing a right-handed set with [up] and [backAxis].
  Vector3 get lateralAxis => up.cross(backAxis).normalized();

  /// The point on the floor directly below the centre of the ring: the origin
  /// for every [CourtPosition].
  Vector3 get floorOrigin => rimCentre - up * rimHeightM;

  ScenePlane get floorPlane => ScenePlane(point: floorOrigin, normal: up);

  ScenePlane get rimPlane => ScenePlane(point: rimCentre, normal: up);

  /// The plane of the backboard face, standing vertically behind the ring.
  ScenePlane get backboardPlane => ScenePlane(
    point:
        rimCentre +
        backAxis * (CourtDimensions.rimRadiusM +
            CourtDimensions.rimOffsetFromBackboardM),
    normal: backAxis,
  );

  ScenePlane horizontalPlaneAt(double heightM) =>
      ScenePlane(point: floorOrigin + up * heightM, normal: up);

  /// The vertical plane containing the ring and a point on the court, which is
  /// where a shot taken from that spot travels.
  ///
  /// A single camera cannot place a ball in three dimensions from one pixel.
  /// Constraining the flight to this plane is the assumption that makes arc
  /// measurement possible, and it is why the arc metrics are only offered from
  /// placements where that assumption holds.
  ScenePlane? shotPlaneThrough(Vector3 courtPoint) {
    final along = _flatten(courtPoint - floorOrigin);
    if (along.length < 0.25) return null;
    return ScenePlane(point: floorOrigin, normal: up.cross(along).normalized());
  }

  /// Where the ray through a pixel meets a plane, or null when it runs
  /// parallel to it or lands behind the camera.
  Vector3? intersect(Vector2 pixel, ScenePlane plane) {
    final direction = intrinsics.rayThroughPixel(pixel);
    final denominator = plane.normal.dot(direction);
    if (denominator.abs() < 1e-9) return null;
    final t = plane.normal.dot(plane.point) / denominator;
    if (t <= 0) return null;
    return direction * t;
  }

  Vector3? pointOnFloor(Vector2 pixel) => intersect(pixel, floorPlane);

  Vector3? pointOnRimPlane(Vector2 pixel) => intersect(pixel, rimPlane);

  /// Camera-space point to court coordinates.
  CourtPosition toCourt(Vector3 cameraPoint) {
    final offset = cameraPoint - floorOrigin;
    return CourtPosition(
      lateralM: offset.dot(lateralAxis),
      depthM: -offset.dot(backAxis),
      heightM: offset.dot(up),
    );
  }

  Vector3 fromCourt(CourtPosition position) =>
      floorOrigin +
      lateralAxis * position.lateralM +
      backAxis * -position.depthM +
      up * position.heightM;

  /// Metres spanned by one pixel at a given distance from the camera. Used for
  /// uncertainty, not for measurement, since it ignores the surface angle.
  double metresPerPixelAt(double distanceM) => distanceM / intrinsics.focalXPx;

  /// Where a shooter standing at [footPixel] is on the court.
  CourtPosition? shooterPosition(Vector2 footPixel) {
    final point = pointOnFloor(footPixel);
    return point == null ? null : toCourt(point);
  }

  /// A ball at [ballPixel] resolved into court coordinates, on the assumption
  /// that it is travelling in the vertical plane through the shooter and the
  /// ring.
  CourtPosition? ballInShotPlane({
    required Vector2 ballPixel,
    required Vector3 shooterFloorPoint,
  }) {
    final plane = shotPlaneThrough(shooterFloorPoint);
    if (plane == null) return null;
    final point = intersect(ballPixel, plane);
    return point == null ? null : toCourt(point);
  }

  /// Depth of a ball from its apparent size, which does not need the shot
  /// plane assumption and so acts as an independent check on it.
  double? ballDepthFromRadius(double radiusPx) {
    if (radiusPx <= 0.5) return null;
    return intrinsics.focalXPx * CourtDimensions.ballRadiusM / radiusPx;
  }

  /// Signed miss at the ring: how far the ball passed to one side of centre
  /// and how far beyond it, both in centimetres.
  ({double lateralCm, double depthCm})? missAtRim(Vector2 ballPixel) {
    final point = pointOnRimPlane(ballPixel);
    if (point == null) return null;
    final offset = point - rimCentre;
    return (
      lateralCm: offset.dot(lateralAxis) * 100,
      depthCm: -offset.dot(backAxis) * 100,
    );
  }

  /// Where the ring projects to, which is what the overlay draws and what the
  /// solve is scored against.
  Vector2? projectRimCentre() => intrinsics.projectToPixel(rimCentre);

  /// The ring's outline in pixels, for drawing and for reprojection error.
  List<Vector2> projectRimOutline({int samples = 48}) {
    final a = lateralAxis;
    final b = backAxis;
    final points = <Vector2>[];
    for (var i = 0; i < samples; i++) {
      final t = 2 * math.pi * i / samples;
      final world =
          rimCentre +
          a * (CourtDimensions.rimRadiusM * math.cos(t)) +
          b * (CourtDimensions.rimRadiusM * math.sin(t));
      final pixel = intrinsics.projectToPixel(world);
      if (pixel != null) points.add(pixel);
    }
    return points;
  }

  /// Angle between the camera's optical axis and the floor, degrees. Near zero
  /// is a level phone; large values mean a steep upward tilt, which shortens
  /// the court and costs depth accuracy.
  double get cameraPitchDegrees =>
      90 - degrees(math.acos(up.dot(Vector3(0, 0, 1)).clamp(-1.0, 1.0)));

  /// Straight-line distance from the camera to the ring.
  double get rimDistanceM => rimCentre.length;

  Vector3 _flatten(Vector3 v) => v - up * up.dot(v);
}
