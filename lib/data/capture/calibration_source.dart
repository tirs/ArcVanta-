import 'package:vector_math/vector_math_64.dart';

import '../calibration/calibration_solver.dart';
import '../calibration/camera_intrinsics.dart';

/// One frame's worth of everything the calibration solver needs.
///
/// The pipeline reports what it saw; it does not decide whether the scene is
/// good enough. That judgement lives in [CalibrationSolver] on the Dart side,
/// where it is testable without a camera.
class CalibrationObservation {
  const CalibrationObservation({
    required this.intrinsics,
    required this.rim,
    required this.backboard,
    required this.conditions,
    required this.gravity,
  });

  final CameraIntrinsics intrinsics;

  /// The ring, if the detector found one this frame.
  final RimObservation? rim;

  final BackboardObservation? backboard;

  final CaptureConditions conditions;

  /// Down, in camera coordinates, from the accelerometer. Null when the sensor
  /// is unavailable, which costs the solver its tie-break between the two
  /// mirror poses a circle's image always admits.
  final Vector3? gravity;
}

/// The camera preview as the calibration screen sees it.
///
/// Separate from `CaptureSource` because calibration runs before a session
/// exists and needs the raw scene geometry rather than derived shot events.
/// The native bridge implements both over one camera; the simulation
/// implements both too, so every screen works without a device.
abstract interface class CalibrationSource {
  /// Scene geometry at preview rate. Starts empty and stays empty for as long
  /// as the ring is out of shot.
  Stream<CalibrationObservation> get observations;

  /// Opens the camera for calibration. Cheaper than [CaptureSource.start]:
  /// pose estimation stays off until a session begins.
  ///
  /// [tripod] is the athlete's own declaration from the placement step. It is
  /// not measured, and it is not treated as fact: it caps the stability score
  /// so a handheld setup cannot be graded as though it were mounted, while a
  /// mount that is actually drifting is still caught by the observed jitter.
  Future<void> startPreview({bool tripod = true});

  Future<void> stopPreview();
}
