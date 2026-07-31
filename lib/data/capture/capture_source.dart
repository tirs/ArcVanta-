import 'dart:ui' show Offset, Rect;

import 'package:flutter/foundation.dart' show ValueListenable;

import '../models/confidence.dart';
import '../models/drill.dart';
import '../models/pose.dart';
import '../models/shot.dart';

/// What the analysis pipeline reports for one processed frame.
///
/// Coordinates are normalised against the preview, so nothing above this layer
/// needs to know the capture resolution. Full-resolution frames never cross
/// this boundary; only the derived geometry does.
class CaptureFrame {
  const CaptureFrame({
    required this.phase,
    required this.cycleProgress,
    required this.pose,
    required this.ball,
    required this.rim,
    required this.backboard,
    required this.trackingConfidence,
    required this.processedFps,
    required this.thermalHeadroom,
  });

  /// Where the shooter is in the shooting motion.
  final ShotPhaseKind phase;

  /// Position inside the current shot cycle, 0 to 1. Drives the overlay.
  final double cycleProgress;

  /// Landmarks for the tracked shooter, or null when nobody is tracked.
  final PoseFrame? pose;

  /// Ball centre while the ball is in flight, null while it is in hand or lost.
  final Offset? ball;

  /// Rim and backboard as located during calibration. Both are null until the
  /// scene is locked, which is what the placement guide waits on.
  final Rect? rim;
  final Rect? backboard;

  final double trackingConfidence;
  final int processedFps;

  /// Remaining sustained-performance budget, 1 down to 0. The pipeline sheds
  /// work as this falls, and the interface says so rather than silently
  /// degrading measurements.
  final double thermalHeadroom;
}

/// Parameters handed to the pipeline when capture starts.
class CaptureRequest {
  const CaptureRequest({
    required this.drill,
    required this.angle,
    required this.calibrationQuality,
    this.highFrameRate = true,
    this.thermalGuard = true,
    this.tripod = true,
    this.frontCamera = false,
  });

  final Drill drill;
  final CameraAngle angle;
  final double calibrationQuality;

  /// Ask the camera for 60 fps rather than 30. Sharper release timing, more
  /// heat, and not every device will honour it.
  final bool highFrameRate;

  /// Let the pipeline shed work before it sheds accuracy when the phone gets
  /// hot, rather than pushing until the frame rate collapses mid-session.
  final bool thermalGuard;

  /// Whether the athlete said the phone is mounted. Caps the stability grade
  /// rather than being trusted outright.
  final bool tripod;

  /// Use the front (selfie) camera so the athlete can see the tracking
  /// overlay while shooting.
  final bool frontCamera;
}

/// The analysis pipeline as the product layer sees it.
///
/// One implementation simulates a session for development and tests; the other
/// forwards to on-device detection and pose over the native bridge. Nothing
/// above this interface knows which is attached, so the models behind it can be
/// replaced without touching a screen.
abstract interface class CaptureSource {
  /// Per-frame geometry and telemetry, at whatever rate the pipeline sustains.
  Stream<CaptureFrame> get frames;

  /// The platform texture the camera is drawing into, once one exists.
  ///
  /// Null while nothing is open, and null for the whole life of a simulated
  /// source, which is how the preview widget knows to draw the schematic scene
  /// and label it as one rather than passing a drawing off as a camera feed.
  ValueListenable<int?> get previewTexture;

  /// Completed shots, emitted once the result is decided. A shot whose result
  /// could not be classified with enough evidence arrives with
  /// [ShotResult.uncertain] and is confirmed by the athlete.
  Stream<Shot> get shots;

  Future<void> start(CaptureRequest request);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> dispose();
}
