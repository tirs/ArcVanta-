import 'dart:math' as math;

import 'package:arcvanta/data/calibration/symmetric_eigen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('recovers a known spectrum', () {
    // Build A = R diag(d) R^T so the answer is known exactly.
    final rotation = Matrix3.rotationZ(0.7)..multiply(Matrix3.rotationX(-0.4));
    final expected = Vector3(6.0, 2.0, -3.0);
    final composed = Matrix3.copy(rotation)
      ..multiply(Matrix3.zero()..setDiagonal(expected))
      ..multiplyTranspose(rotation);

    final eigen = SymmetricEigen.decompose(composed);

    expect(eigen.values.x, closeTo(6, 1e-9));
    expect(eigen.values.y, closeTo(2, 1e-9));
    expect(eigen.values.z, closeTo(-3, 1e-9));
  });

  test('reconstructs the input matrix', () {
    final source = Matrix3(
      4.0, -1.5, 0.9, //
      -1.5, 2.2, 0.4, //
      0.9, 0.4, -1.1,
    );

    final eigen = SymmetricEigen.decompose(source);
    final rebuilt = Matrix3.copy(eigen.vectors)
      ..multiply(Matrix3.zero()..setDiagonal(eigen.values))
      ..multiplyTranspose(eigen.vectors);

    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        expect(rebuilt.entry(r, c), closeTo(source.entry(r, c), 1e-10));
      }
    }
  });

  test('eigenvectors are orthonormal and right handed', () {
    final source = Matrix3(
      2.0, 0.7, -0.3, //
      0.7, 5.0, 1.1, //
      -0.3, 1.1, 0.5,
    );

    final eigen = SymmetricEigen.decompose(source);

    for (var i = 0; i < 3; i++) {
      expect(eigen.vectorAt(i).length, closeTo(1, 1e-12));
      for (var j = i + 1; j < 3; j++) {
        expect(eigen.vectorAt(i).dot(eigen.vectorAt(j)), closeTo(0, 1e-12));
      }
    }
    expect(eigen.vectors.determinant(), closeTo(1, 1e-12));
  });

  test('each pair satisfies the eigen relation', () {
    final source = Matrix3(
      1.0, 2.0, 3.0, //
      2.0, -4.0, 0.5, //
      3.0, 0.5, 6.0,
    );

    final eigen = SymmetricEigen.decompose(source);

    for (var i = 0; i < 3; i++) {
      final vector = eigen.vectorAt(i);
      final applied = source * vector as Vector3;
      final scaled = vector * eigen.values[i];
      expect((applied - scaled).length, lessThan(1e-10));
    }
  });

  test('handles an already diagonal matrix', () {
    final eigen = SymmetricEigen.decompose(
      Matrix3.zero()..setDiagonal(Vector3(-2.0, 7.0, 1.0)),
    );

    expect(eigen.values.x, closeTo(7, 1e-12));
    expect(eigen.values.y, closeTo(1, 1e-12));
    expect(eigen.values.z, closeTo(-2, 1e-12));
    expect(eigen.vectors.determinant(), closeTo(1, 1e-12));
  });

  test('values come back sorted descending for random symmetric input', () {
    final random = math.Random(7);
    for (var trial = 0; trial < 200; trial++) {
      double next() => random.nextDouble() * 10 - 5;
      final ab = next();
      final ac = next();
      final bc = next();
      final source = Matrix3(
        next(), ab, ac, //
        ab, next(), bc, //
        ac, bc, next(),
      );

      final eigen = SymmetricEigen.decompose(source);

      expect(eigen.values.x, greaterThanOrEqualTo(eigen.values.y));
      expect(eigen.values.y, greaterThanOrEqualTo(eigen.values.z));

      final rebuilt = Matrix3.copy(eigen.vectors)
        ..multiply(Matrix3.zero()..setDiagonal(eigen.values))
        ..multiplyTranspose(eigen.vectors);
      for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 3; c++) {
          expect(rebuilt.entry(r, c), closeTo(source.entry(r, c), 1e-9));
        }
      }
    }
  });
}
