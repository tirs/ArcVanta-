import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

/// Pinhole camera parameters for the preview stream.
///
/// The solver works in normalised image coordinates, where a point is
/// `K^-1 * pixel`, because that is the space in which a circle's image is a
/// conic with no focal length baked into it. Everything the pipeline reports
/// in metres depends on [focalXPx] being roughly right, so the native layer
/// reads it from the camera rather than guessing where it can.
class CameraIntrinsics {
  const CameraIntrinsics({
    required this.focalXPx,
    required this.focalYPx,
    required this.principalXPx,
    required this.principalYPx,
    required this.widthPx,
    required this.heightPx,
    this.fromDevice = true,
  });

  /// Derived from the horizontal field of view, which is what both Camera2 and
  /// AVFoundation expose most reliably. Square pixels are assumed, which holds
  /// for every phone sensor the product targets.
  factory CameraIntrinsics.fromHorizontalFov({
    required double fovDegrees,
    required int widthPx,
    required int heightPx,
    bool fromDevice = true,
  }) {
    final focal = widthPx / (2 * math.tan(radians(fovDegrees) / 2));
    return CameraIntrinsics(
      focalXPx: focal,
      focalYPx: focal,
      principalXPx: widthPx / 2,
      principalYPx: heightPx / 2,
      widthPx: widthPx,
      heightPx: heightPx,
      fromDevice: fromDevice,
    );
  }

  /// Last resort when the platform reports nothing usable. 65 degrees is the
  /// middle of the range for a phone main camera; a solve that used it is
  /// marked [fromDevice] false so the quality score can discount it.
  factory CameraIntrinsics.assumed({
    required int widthPx,
    required int heightPx,
  }) => CameraIntrinsics.fromHorizontalFov(
    fovDegrees: 65,
    widthPx: widthPx,
    heightPx: heightPx,
    fromDevice: false,
  );

  final double focalXPx;
  final double focalYPx;
  final double principalXPx;
  final double principalYPx;
  final int widthPx;
  final int heightPx;

  /// False when the focal length was assumed rather than read from the camera.
  final bool fromDevice;

  double get horizontalFovDegrees =>
      degrees(2 * math.atan(widthPx / (2 * focalXPx)));

  Matrix3 get matrix => Matrix3(
    focalXPx, 0, 0, //
    0, focalYPx, 0, //
    principalXPx, principalYPx, 1,
  );

  Matrix3 get inverseMatrix => Matrix3(
    1 / focalXPx, 0, 0, //
    0, 1 / focalYPx, 0, //
    -principalXPx / focalXPx, -principalYPx / focalYPx, 1,
  );

  /// Pixel coordinates for a point given in the normalised 0..1 preview space
  /// the capture interface speaks.
  Vector2 pixelFromUnit(Vector2 unit) =>
      Vector2(unit.x * widthPx, unit.y * heightPx);

  Vector2 unitFromPixel(Vector2 pixel) =>
      Vector2(pixel.x / widthPx, pixel.y / heightPx);

  /// Direction, in camera coordinates, of the ray through a pixel. Not
  /// normalised to unit length: z stays 1 so it can be scaled by depth.
  Vector3 rayThroughPixel(Vector2 pixel) => Vector3(
    (pixel.x - principalXPx) / focalXPx,
    (pixel.y - principalYPx) / focalYPx,
    1,
  );

  /// Projects a camera-space point back to pixels. Returns null behind the
  /// camera, where the projection is meaningless rather than merely large.
  Vector2? projectToPixel(Vector3 point) {
    if (point.z <= 1e-9) return null;
    return Vector2(
      point.x / point.z * focalXPx + principalXPx,
      point.y / point.z * focalYPx + principalYPx,
    );
  }

  CameraIntrinsics scaledTo({required int widthPx, required int heightPx}) {
    final sx = widthPx / this.widthPx;
    final sy = heightPx / this.heightPx;
    return CameraIntrinsics(
      focalXPx: focalXPx * sx,
      focalYPx: focalYPx * sy,
      principalXPx: principalXPx * sx,
      principalYPx: principalYPx * sy,
      widthPx: widthPx,
      heightPx: heightPx,
      fromDevice: fromDevice,
    );
  }

  @override
  String toString() =>
      'CameraIntrinsics(f: ${focalXPx.toStringAsFixed(1)}px, '
      '${widthPx}x$heightPx, '
      'fov: ${horizontalFovDegrees.toStringAsFixed(1)}deg, '
      'fromDevice: $fromDevice)';
}
