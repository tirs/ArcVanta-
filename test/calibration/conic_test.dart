import 'dart:math' as math;

import 'package:arcvanta/data/calibration/conic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

List<Vector2> _samplePoints(EllipseParams e, int count, {double noise = 0}) {
  final random = math.Random(11);
  return [
    for (var i = 0; i < count; i++)
      () {
        final t = 2 * math.pi * i / count;
        final x = e.semiMajor * math.cos(t);
        final y = e.semiMinor * math.sin(t);
        final cos = math.cos(e.rotation);
        final sin = math.sin(e.rotation);
        return Vector2(
          e.centre.x + x * cos - y * sin + (random.nextDouble() - 0.5) * noise,
          e.centre.y + x * sin + y * cos + (random.nextDouble() - 0.5) * noise,
        );
      }(),
  ];
}

void _expectEllipseClose(
  EllipseParams actual,
  EllipseParams expected, {
  double tolerance = 1e-6,
}) {
  expect(actual.centre.x, closeTo(expected.centre.x, tolerance));
  expect(actual.centre.y, closeTo(expected.centre.y, tolerance));
  expect(actual.semiMajor, closeTo(expected.semiMajor, tolerance));
  expect(actual.semiMinor, closeTo(expected.semiMinor, tolerance));

  // Orientation is only defined modulo pi, and is meaningless on a circle.
  if ((expected.semiMajor - expected.semiMinor).abs() > 1e-6) {
    final diff = (actual.rotation - expected.rotation).abs() % math.pi;
    expect(math.min(diff, math.pi - diff), lessThan(1e-5));
  }
}

void main() {
  group('ellipse round trip', () {
    test('axis aligned', () {
      final source = EllipseParams(
        centre: Vector2(120, -40),
        semiMajor: 80,
        semiMinor: 30,
        rotation: 0,
      );
      _expectEllipseClose(Conic.fromEllipse(source).toEllipse()!, source);
    });

    test('rotated', () {
      final source = EllipseParams(
        centre: Vector2(-15.5, 62.25),
        semiMajor: 44,
        semiMinor: 12,
        rotation: 0.63,
      );
      _expectEllipseClose(Conic.fromEllipse(source).toEllipse()!, source);
    });

    test('circle', () {
      final source = EllipseParams(
        centre: Vector2(5, 5),
        semiMajor: 20,
        semiMinor: 20,
        rotation: 0,
      );
      _expectEllipseClose(Conic.fromEllipse(source).toEllipse()!, source);
    });

    test('sweeps orientation and aspect', () {
      for (var i = 0; i < 24; i++) {
        final rotation = -math.pi / 2 + math.pi * i / 24;
        for (final ratio in const [0.2, 0.5, 0.9]) {
          final source = EllipseParams(
            centre: Vector2(300, 220),
            semiMajor: 90,
            semiMinor: 90 * ratio,
            rotation: rotation,
          );
          _expectEllipseClose(
            Conic.fromEllipse(source).toEllipse()!,
            source,
            tolerance: 1e-5,
          );
        }
      }
    });
  });

  test('points on the ellipse evaluate to zero', () {
    final source = EllipseParams(
      centre: Vector2(10, 20),
      semiMajor: 50,
      semiMinor: 25,
      rotation: 0.4,
    );
    final conic = Conic.fromEllipse(source);

    for (final point in _samplePoints(source, 32)) {
      expect(conic.evaluate(point).abs(), lessThan(1e-9));
    }
    expect(conic.evaluate(source.centre), lessThan(0));
  });

  group('fitToPoints', () {
    test('recovers an exact ellipse from clean samples', () {
      final source = EllipseParams(
        centre: Vector2(640, 360),
        semiMajor: 140,
        semiMinor: 46,
        rotation: -0.22,
      );

      final fitted = Conic.fitToPoints(_samplePoints(source, 40))!;
      _expectEllipseClose(fitted.toEllipse()!, source, tolerance: 1e-4);
    });

    test('recovers from the minimum of five points', () {
      final source = EllipseParams(
        centre: Vector2(100, 100),
        semiMajor: 60,
        semiMinor: 35,
        rotation: 0.9,
      );

      final fitted = Conic.fitToPoints(_samplePoints(source, 5))!;
      _expectEllipseClose(fitted.toEllipse()!, source, tolerance: 1e-4);
    });

    test('stays close under pixel noise', () {
      final source = EllipseParams(
        centre: Vector2(500, 300),
        semiMajor: 120,
        semiMinor: 40,
        rotation: 0.15,
      );

      final fitted = Conic.fitToPoints(
        _samplePoints(source, 60, noise: 2.0),
      )!.toEllipse()!;

      expect((fitted.centre - source.centre).length, lessThan(1.5));
      expect(fitted.semiMajor, closeTo(source.semiMajor, 3));
      expect(fitted.semiMinor, closeTo(source.semiMinor, 3));
    });

    test('rejects too few points', () {
      expect(Conic.fitToPoints([Vector2.zero(), Vector2(1, 1)]), isNull);
    });

    test('rejects collinear points, which are not an ellipse', () {
      expect(
        Conic.fitToPoints([
          for (var i = 0; i < 8; i++) Vector2(i.toDouble(), i * 2.0),
        ]),
        isNull,
      );
    });
  });

  test('eccentricity reads zero for a circle and rises as it flattens', () {
    Vector2 c() => Vector2(0, 0);
    expect(
      EllipseParams(centre: c(), semiMajor: 10, semiMinor: 10, rotation: 0)
          .eccentricity,
      closeTo(0, 1e-12),
    );
    expect(
      EllipseParams(centre: c(), semiMajor: 10, semiMinor: 1, rotation: 0)
          .eccentricity,
      greaterThan(0.99),
    );
  });
}
