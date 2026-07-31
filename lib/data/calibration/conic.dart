import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

/// An ellipse described the way a detector reports one.
class EllipseParams {
  const EllipseParams({
    required this.centre,
    required this.semiMajor,
    required this.semiMinor,
    required this.rotation,
  });

  final Vector2 centre;

  /// Always the longer of the two, in the same units as [centre].
  final double semiMajor;
  final double semiMinor;

  /// Angle of the major axis from the x axis, radians.
  final double rotation;

  /// 0 for a circle, approaching 1 as the ellipse flattens. A rim viewed
  /// square-on from the side degenerates, which is when the pose solve stops
  /// being trustworthy.
  double get eccentricity {
    if (semiMajor <= 0) return 0;
    final ratio = semiMinor / semiMajor;
    return math.sqrt((1 - ratio * ratio).clamp(0.0, 1.0));
  }

  double get area => math.pi * semiMajor * semiMinor;

  @override
  String toString() =>
      'EllipseParams(centre: (${centre.x.toStringAsFixed(1)}, '
      '${centre.y.toStringAsFixed(1)}), '
      'axes: ${semiMajor.toStringAsFixed(1)}/${semiMinor.toStringAsFixed(1)}, '
      'rot: ${degrees(rotation).toStringAsFixed(1)}deg)';
}

/// A conic section as `ax^2 + bxy + cy^2 + dx + ey + f = 0`.
///
/// The rim is a circle, so its image under a pinhole camera is exactly a
/// conic. Recovering where that circle sits in space is the whole calibration,
/// and it operates on this rather than on the ellipse parameters because the
/// matrix form is what transforms cleanly between pixel and normalised
/// coordinates.
class Conic {
  const Conic(this.a, this.b, this.c, this.d, this.e, this.f);

  factory Conic.fromEllipse(EllipseParams ellipse) {
    final cos = math.cos(ellipse.rotation);
    final sin = math.sin(ellipse.rotation);
    final aa = ellipse.semiMajor * ellipse.semiMajor;
    final bb = ellipse.semiMinor * ellipse.semiMinor;

    final a = cos * cos / aa + sin * sin / bb;
    final b = 2 * cos * sin * (1 / aa - 1 / bb);
    final c = sin * sin / aa + cos * cos / bb;

    final x0 = ellipse.centre.x;
    final y0 = ellipse.centre.y;

    return Conic(
      a,
      b,
      c,
      -2 * a * x0 - b * y0,
      -b * x0 - 2 * c * y0,
      a * x0 * x0 + b * x0 * y0 + c * y0 * y0 - 1,
    );
  }

  /// Symmetric matrix form, so `[x y 1] * M * [x y 1]^T == 0` on the conic.
  factory Conic.fromMatrix(Matrix3 m) => Conic(
    m.entry(0, 0),
    m.entry(0, 1) * 2,
    m.entry(1, 1),
    m.entry(0, 2) * 2,
    m.entry(1, 2) * 2,
    m.entry(2, 2),
  );

  /// Algebraic least-squares fit through five or more points.
  ///
  /// Points are centred and scaled first, which both conditions the system and
  /// puts the origin inside the ellipse so the `f = -1` normalisation used to
  /// reduce this to five unknowns cannot be degenerate.
  static Conic? fitToPoints(List<Vector2> points) {
    if (points.length < 5) return null;

    var cx = 0.0;
    var cy = 0.0;
    for (final p in points) {
      cx += p.x;
      cy += p.y;
    }
    cx /= points.length;
    cy /= points.length;

    var spread = 0.0;
    for (final p in points) {
      spread += (p.x - cx).abs() + (p.y - cy).abs();
    }
    spread /= points.length * 2;
    if (spread < 1e-12) return null;

    final normal = List<List<double>>.generate(5, (_) => List.filled(6, 0.0));
    for (final p in points) {
      final x = (p.x - cx) / spread;
      final y = (p.y - cy) / spread;
      final row = <double>[x * x, x * y, y * y, x, y];
      for (var i = 0; i < 5; i++) {
        for (var j = 0; j < 5; j++) {
          normal[i][j] += row[i] * row[j];
        }
        normal[i][5] += row[i];
      }
    }

    final solved = _solve(normal, 5);
    if (solved == null) return null;

    // Undo the normalisation: x_n = (x - cx) / s.
    final an = solved[0];
    final bn = solved[1];
    final cn = solved[2];
    final dn = solved[3];
    final en = solved[4];
    const fn = -1.0;

    final s = spread;
    final a = an / (s * s);
    final b = bn / (s * s);
    final c = cn / (s * s);
    final d = -2 * an * cx / (s * s) - bn * cy / (s * s) + dn / s;
    final e = -bn * cx / (s * s) - 2 * cn * cy / (s * s) + en / s;
    final f =
        an * cx * cx / (s * s) +
        bn * cx * cy / (s * s) +
        cn * cy * cy / (s * s) -
        dn * cx / s -
        en * cy / s +
        fn;

    final conic = Conic(a, b, c, d, e, f);
    return conic.isEllipse ? conic : null;
  }

  final double a;
  final double b;
  final double c;
  final double d;
  final double e;
  final double f;

  Matrix3 get matrix => Matrix3(
    a, b / 2, d / 2, //
    b / 2, c, e / 2, //
    d / 2, e / 2, f,
  );

  double get discriminant => b * b - 4 * a * c;

  bool get isEllipse => discriminant < 0;

  double evaluate(Vector2 point) {
    final x = point.x;
    final y = point.y;
    return a * x * x + b * x * y + c * y * y + d * x + e * y + f;
  }

  /// Pulls the geometric parameters back out. Null when the conic is not an
  /// ellipse, which happens on a bad fit rather than on a real rim.
  EllipseParams? toEllipse() {
    if (!isEllipse) return null;

    final det = 4 * a * c - b * b;
    final x0 = (b * e - 2 * c * d) / det;
    final y0 = (b * d - 2 * a * e) / det;

    // Constant term once the conic is recentred on its own centre.
    final constant = a * x0 * x0 + b * x0 * y0 + c * y0 * y0 + d * x0 + e * y0 + f;
    if (constant.abs() < 1e-18) return null;

    final scale = -1 / constant;
    final qa = a * scale;
    final qb = b * scale / 2;
    final qc = c * scale;

    // Eigenvalues of [[qa, qb], [qb, qc]]; the axes are 1/sqrt of them.
    final mean = (qa + qc) / 2;
    final delta = math.sqrt(math.pow((qa - qc) / 2, 2) + qb * qb);
    final lambdaSmall = mean - delta;
    final lambdaLarge = mean + delta;
    if (lambdaSmall <= 1e-18 || lambdaLarge <= 1e-18) return null;

    final semiMajor = 1 / math.sqrt(lambdaSmall);
    final semiMinor = 1 / math.sqrt(lambdaLarge);

    // The major axis follows the eigenvector of the smaller eigenvalue.
    final rotation = qb.abs() < 1e-18
        ? (qa <= qc ? 0.0 : math.pi / 2)
        : math.atan2(lambdaSmall - qa, qb);

    return EllipseParams(
      centre: Vector2(x0, y0),
      semiMajor: semiMajor,
      semiMinor: semiMinor,
      rotation: _wrapAngle(rotation),
    );
  }

  /// Re-expresses the conic in a coordinate system whose points map into this
  /// one as `p = h * q`, giving `h^T M h`.
  ///
  /// Pulling a pixel-space conic back through the intrinsics is how it becomes
  /// a conic in normalised camera coordinates, where the pose solve lives.
  Conic pullback(Matrix3 h) {
    final transformed = Matrix3.copy(h)
      ..transpose()
      ..multiply(matrix)
      ..multiply(h);
    return Conic.fromMatrix(transformed);
  }

  Conic normalised() {
    final scale = math.sqrt(a * a + b * b + c * c + d * d + e * e + f * f);
    if (scale < 1e-300) return this;
    return Conic(a / scale, b / scale, c / scale, d / scale, e / scale, f / scale);
  }

  static double _wrapAngle(double value) {
    var angle = value;
    while (angle < -math.pi / 2) {
      angle += math.pi;
    }
    while (angle >= math.pi / 2) {
      angle -= math.pi;
    }
    return angle;
  }

  /// Gauss-Jordan with partial pivoting on an `n by n+1` augmented matrix.
  static List<double>? _solve(List<List<double>> augmented, int n) {
    for (var col = 0; col < n; col++) {
      var pivot = col;
      for (var row = col + 1; row < n; row++) {
        if (augmented[row][col].abs() > augmented[pivot][col].abs()) {
          pivot = row;
        }
      }
      if (augmented[pivot][col].abs() < 1e-14) return null;
      final swap = augmented[col];
      augmented[col] = augmented[pivot];
      augmented[pivot] = swap;

      final lead = augmented[col][col];
      for (var j = col; j <= n; j++) {
        augmented[col][j] /= lead;
      }
      for (var row = 0; row < n; row++) {
        if (row == col) continue;
        final factor = augmented[row][col];
        if (factor == 0) continue;
        for (var j = col; j <= n; j++) {
          augmented[row][j] -= factor * augmented[col][j];
        }
      }
    }
    return [for (var i = 0; i < n; i++) augmented[i][n]];
  }

  @override
  String toString() => 'Conic($a, $b, $c, $d, $e, $f)';
}
