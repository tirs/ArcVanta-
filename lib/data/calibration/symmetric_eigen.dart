import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

/// Eigenvalues and eigenvectors of a symmetric 3x3 matrix.
///
/// [values] are sorted descending, and column `i` of [vectors] is the unit
/// eigenvector for `values[i]`, so `vectors * diag(values) * vectors^T`
/// reconstructs the input and [vectors] is a rotation.
class SymmetricEigen {
  const SymmetricEigen(this.values, this.vectors);

  final Vector3 values;
  final Matrix3 vectors;

  Vector3 vectorAt(int index) => Vector3(
    vectors.entry(0, index),
    vectors.entry(1, index),
    vectors.entry(2, index),
  );

  /// Cyclic Jacobi rotation.
  ///
  /// The conic matrices this runs on are 3x3 and well conditioned, so the
  /// iteration converges in a handful of sweeps and avoids pulling in a
  /// linear algebra package for one routine.
  static SymmetricEigen decompose(Matrix3 input) {
    final a = List<List<double>>.generate(
      3,
      (r) => List<double>.generate(3, (c) => input.entry(r, c)),
    );
    final v = List<List<double>>.generate(
      3,
      (r) => List<double>.generate(3, (c) => r == c ? 1.0 : 0.0),
    );

    for (var sweep = 0; sweep < 32; sweep++) {
      final off =
          a[0][1].abs() + a[0][2].abs() + a[1][2].abs();
      if (off < 1e-18) break;

      for (var p = 0; p < 2; p++) {
        for (var q = p + 1; q < 3; q++) {
          if (a[p][q].abs() < 1e-20) continue;

          final theta = (a[q][q] - a[p][p]) / (2 * a[p][q]);
          final t = theta.sign / (theta.abs() + math.sqrt(theta * theta + 1));
          final c = 1 / math.sqrt(t * t + 1);
          final s = t * c;

          for (var k = 0; k < 3; k++) {
            final akp = a[k][p];
            final akq = a[k][q];
            a[k][p] = c * akp - s * akq;
            a[k][q] = s * akp + c * akq;
          }
          for (var k = 0; k < 3; k++) {
            final apk = a[p][k];
            final aqk = a[q][k];
            a[p][k] = c * apk - s * aqk;
            a[q][k] = s * apk + c * aqk;
          }
          for (var k = 0; k < 3; k++) {
            final vkp = v[k][p];
            final vkq = v[k][q];
            v[k][p] = c * vkp - s * vkq;
            v[k][q] = s * vkp + c * vkq;
          }
        }
      }
    }

    final order = [0, 1, 2]..sort((x, y) => a[y][y].compareTo(a[x][x]));
    final values = Vector3(
      a[order[0]][order[0]],
      a[order[1]][order[1]],
      a[order[2]][order[2]],
    );

    final vectors = Matrix3.zero();
    for (var column = 0; column < 3; column++) {
      final source = order[column];
      for (var row = 0; row < 3; row++) {
        vectors.setEntry(row, column, v[row][source]);
      }
    }

    // A reflection here would silently flip the recovered surface normal.
    if (vectors.determinant() < 0) {
      for (var row = 0; row < 3; row++) {
        vectors.setEntry(row, 2, -vectors.entry(row, 2));
      }
    }

    return SymmetricEigen(values, vectors);
  }
}
