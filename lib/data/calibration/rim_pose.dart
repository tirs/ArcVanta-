import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

import 'camera_intrinsics.dart';
import 'conic.dart';
import 'symmetric_eigen.dart';

/// One of the two poses a circle of known radius can have, given its image.
class CirclePose {
  const CirclePose({required this.centre, required this.normal});

  /// Circle centre in camera coordinates, metres, z forward.
  final Vector3 centre;

  /// Unit normal of the circle's plane, in camera coordinates. Sign is chosen
  /// by the solver so it points towards the camera's up direction.
  final Vector3 normal;

  double get distanceM => centre.length;

  @override
  String toString() =>
      'CirclePose(centre: ${_fmt(centre)}, normal: ${_fmt(normal)})';

  static String _fmt(Vector3 v) =>
      '(${v.x.toStringAsFixed(3)}, ${v.y.toStringAsFixed(3)}, '
      '${v.z.toStringAsFixed(3)})';
}

/// Both solutions, plus which one the solver believes.
class RimPoseSolution {
  const RimPoseSolution({
    required this.chosen,
    required this.rejected,
    required this.tiltSeparationDegrees,
  });

  final CirclePose chosen;

  /// The mirror solution. A circle's image never distinguishes the two on its
  /// own, so this is kept for diagnostics and for the ambiguity penalty in the
  /// quality score.
  final CirclePose rejected;

  /// Angle between the two candidate normals. When this is small the choice
  /// barely matters; when it is large and the evidence for one over the other
  /// is weak, the solve is fragile.
  final double tiltSeparationDegrees;
}

/// Recovers where a circle of known radius sits in space, from its image.
///
/// This is what makes a single camera enough. A basketball ring is the only
/// thing in a gym that is simultaneously a known size, a known height and a
/// circle, so its image ellipse pins down distance, tilt and scale, and every
/// measurement the product reports in metres hangs off it.
///
/// The method is the classical one: in the eigenbasis of the image conic the
/// cone through the circle is diagonal, and the planes that cut it in a circle
/// have normals lying in the plane of the largest and smallest eigenvectors.
/// That yields two mirror-image solutions, which is a genuine geometric
/// ambiguity rather than a shortcoming, so the caller supplies gravity to
/// break it.
abstract final class RimPoseSolver {
  /// [imageConic] is in pixel coordinates, [radiusM] the true circle radius.
  ///
  /// [cameraUp] is the world up direction expressed in camera coordinates,
  /// which on a phone comes straight from the accelerometer. It only picks
  /// between the two solutions; it does not otherwise enter the geometry.
  static RimPoseSolution? solve({
    required Conic imageConic,
    required double radiusM,
    required CameraIntrinsics intrinsics,
    Vector3? cameraUp,
  }) {
    if (radiusM <= 0) return null;

    // Eigenvalue signs cannot tell an ellipse from a hyperbola: both are two
    // of one sign and one of the other, because negating a conic matrix leaves
    // the same curve. The discriminant is what separates them, and the
    // intrinsics preserve it.
    if (!imageConic.isEllipse) return null;

    // A conic in pixels becomes a conic in normalised camera coordinates by
    // pulling it back through the intrinsics, which removes focal length from
    // the geometry.
    final normalisedConic = imageConic.pullback(intrinsics.matrix);
    var matrix = normalisedConic.normalised().matrix;

    final probe = SymmetricEigen.decompose(matrix);
    final positives = [probe.values.x, probe.values.y, probe.values.z]
        .where((v) => v > 0)
        .length;
    // Orient the matrix so the signature reads (+,+,-), which the closed form
    // below assumes. A degenerate fit lands on neither count.
    if (positives == 1) {
      matrix = matrix.scaled(-1.0);
    } else if (positives != 2) {
      return null;
    }

    final eigen = SymmetricEigen.decompose(matrix);
    final l1 = eigen.values.x;
    final l2 = eigen.values.y;
    final l3 = eigen.values.z;
    if (!(l1 >= l2 && l2 > 0 && l3 < 0)) return null;

    final span = l1 - l3;
    if (span < 1e-12) return null;

    final g = math.sqrt(((l1 - l2) / span).clamp(0.0, 1.0));
    final h = math.sqrt(((l2 - l3) / span).clamp(0.0, 1.0));
    final scale = radiusM / math.sqrt(-l1 * l3);

    final v = eigen.vectors;
    final candidates = <CirclePose>[];
    for (final sign in const [1.0, -1.0]) {
      final n1 = g;
      final n3 = sign * h;

      // Derived in the eigenbasis: centre = r/sqrt(-l1 l3) * (n1 l3, 0, n3 l1).
      var centre = v.transformed(Vector3(n1 * l3 * scale, 0, n3 * l1 * scale));
      var normal = v.transformed(Vector3(n1, 0, n3));

      // The circle has to be in front of the camera; that fixes the overall
      // sign that the algebra leaves free.
      if (centre.z < 0) {
        centre = -centre;
        normal = -normal;
      }
      candidates.add(
        CirclePose(centre: centre, normal: normal.normalized()),
      );
    }

    // Without gravity, assume the phone is roughly upright: image y runs down,
    // so world up is near -y in camera coordinates.
    final up = (cameraUp ?? Vector3(0, -1, 0)).normalized();

    final oriented = [
      for (final pose in candidates)
        CirclePose(
          centre: pose.centre,
          // A plane normal is sign-free; point it up so downstream code can
          // treat it as the floor normal without re-deciding.
          normal: pose.normal.dot(up) < 0 ? -pose.normal : pose.normal,
        ),
    ];

    oriented.sort(
      (a, b) => b.normal.dot(up).compareTo(a.normal.dot(up)),
    );

    final separation = degrees(
      math.acos(
        oriented.first.normal.dot(oriented.last.normal).clamp(-1.0, 1.0),
      ),
    );

    return RimPoseSolution(
      chosen: oriented.first,
      rejected: oriented.last,
      tiltSeparationDegrees: separation,
    );
  }
}
