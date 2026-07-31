import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import '../calibration/calibration_solver.dart';
import '../calibration/camera_intrinsics.dart';
import '../calibration/conic.dart';
import '../calibration/court_dimensions.dart';
import '../calibration/court_frame.dart';
import 'calibration_source.dart';

/// A believable gym, rendered through a real camera model.
///
/// The simulation does not hand the calibration screen a score; it hands it a
/// rim ellipse and lets the real solver work it out. That way the solver is
/// exercised on every run of the app rather than only on a device, and a
/// regression in the geometry shows up long before anyone finds a tripod.
abstract final class SimulatedScene {
  /// A tripod at about 1.6 m, nine metres out, pitched up slightly, with the
  /// shooting spot off to one side.
  static final CameraIntrinsics intrinsics =
      CameraIntrinsics.fromHorizontalFov(
        fovDegrees: 68,
        widthPx: 1920,
        heightPx: 1080,
      );

  static final Matrix3 _pitch = Matrix3.rotationX(radians(8.0));

  static final Vector3 up = _pitch.transformed(Vector3(0, -1, 0));

  static final Vector3 rimCentre = _pitch.transformed(
    Vector3(0.9, -1.448, 8.6),
  );

  static CourtFrame get courtFrame => CourtFrame(
    intrinsics: intrinsics,
    rimCentre: rimCentre,
    up: up,
    backAxis: _pitch.transformed(Vector3(0, 0, 1)),
  );

  /// The ring as the detector would report it, with a little wobble so the
  /// solved quality moves the way it does on a real preview.
  static CalibrationObservation observation({
    required int frame,
    bool rimVisible = true,
    bool hasTripod = true,
  }) {
    final wobble = math.sin(frame / 9) * 0.6;

    return CalibrationObservation(
      intrinsics: intrinsics,
      rim: rimVisible
          ? RimObservation(
              ellipse: _rimEllipse(wobble),
              source: RimObservationSource.detector,
              detectorConfidence: 0.93,
            )
          : null,
      backboard: rimVisible ? _backboard() : null,
      conditions: CaptureConditions(
        meanLuma: 0.54,
        lumaClippedFraction: 0.03,
        motionPixelsPerFrame: hasTripod ? 0.35 : 2.6,
        frameRate: 60,
        hasTripod: hasTripod,
      ),
      gravity: -up,
    );
  }

  /// Projects the real ring and fits the ellipse to it, rather than making one
  /// up, so the ellipse the solver sees is one a camera could produce.
  static EllipseParams _rimEllipse(double wobblePx) {
    final normal = up.normalized();
    final seed = normal.x.abs() < 0.9 ? Vector3(1, 0, 0) : Vector3(0, 1, 0);
    final e1 = seed.cross(normal).normalized();
    final e2 = normal.cross(e1).normalized();

    final points = <Vector2>[];
    for (var i = 0; i < 36; i++) {
      final t = 2 * math.pi * i / 36;
      final world = rimCentre +
          e1 * (CourtDimensions.rimRadiusM * math.cos(t)) +
          e2 * (CourtDimensions.rimRadiusM * math.sin(t));
      final pixel = intrinsics.projectToPixel(world);
      if (pixel == null) continue;
      points.add(Vector2(pixel.x + wobblePx, pixel.y + wobblePx * 0.4));
    }

    return Conic.fitToPoints(points)!.toEllipse()!;
  }

  static BackboardObservation _backboard() {
    final frame = courtFrame;
    final centre = frame.rimCentre +
        frame.backAxis *
            (CourtDimensions.rimRadiusM +
                CourtDimensions.rimOffsetFromBackboardM) +
        frame.up * 0.30;
    final pixel = intrinsics.projectToPixel(centre)!;

    final scale = intrinsics.focalXPx / centre.z;
    return BackboardObservation(
      centre: pixel,
      widthPx: CourtDimensions.backboardWidthM * scale,
      heightPx: CourtDimensions.backboardHeightM * scale,
      detectorConfidence: 0.9,
    );
  }
}
