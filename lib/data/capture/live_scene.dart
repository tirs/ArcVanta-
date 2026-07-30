import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import '../models/pose.dart';

/// Geometry of the tracked scene in normalised preview coordinates.
///
/// The rim and backboard are fixed here because the simulated pipeline works
/// against a fixed preview. A real pipeline locates them once during
/// calibration and reports them on every [CaptureFrame], which is why the
/// overlay takes them as values rather than reading these constants.
abstract final class LiveScene {
  static const Rect hoop = Rect.fromLTWH(0.700, 0.212, 0.132, 0.030);
  static const Rect backboard = Rect.fromLTWH(0.688, 0.098, 0.180, 0.118);
  static Offset get rimCentre => hoop.center;

  static Rect playerBox(PoseFrame pose) {
    var left = 1.0, top = 1.0, right = 0.0, bottom = 0.0;
    for (final point in pose.landmarks.values) {
      left = math.min(left, point.dx);
      top = math.min(top, point.dy);
      right = math.max(right, point.dx);
      bottom = math.max(bottom, point.dy);
    }
    return Rect.fromLTRB(
      left - 0.045,
      top - 0.055,
      right + 0.045,
      bottom + 0.025,
    );
  }
}
