import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart'
    show Alignment, LinearGradient, RadialGradient;

import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';

/// The launcher mark, painted rather than stored as artwork so the icon and
/// the in-app [AvLogoMark] cannot drift apart.
///
/// Every platform wants the same drawing at a different crop: iOS takes the
/// full square, Android's adaptive icon splits it into a background layer and
/// a foreground layer that gets masked and parallaxed, and themed icons take
/// the silhouette alone. Those are all [AvIconArt] calls with different flags.
abstract final class AvIconArt {
  /// Android masks adaptive icons down to roughly the middle 66 of 108 units,
  /// so the mark has to sit well inside the canvas or the ball loses its edge.
  static const double adaptiveSafeFraction = 66 / 108;

  static void paintBackground(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;

    canvas.drawRect(
      bounds,
      Paint()..shader = AvGradients.ink.createShader(bounds),
    );

    // The same corner lighting as the launch backdrop, so opening the app
    // feels like the icon growing rather than a cut to a different screen.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.85, -0.85),
          radius: 1.15,
          colors: [
            AvColors.flare.withValues(alpha: 0.30),
            AvColors.flare.withValues(alpha: 0),
          ],
        ).createShader(bounds),
    );
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.95, 0.95),
          radius: 1.0,
          colors: [
            AvColors.insight.withValues(alpha: 0.28),
            AvColors.insight.withValues(alpha: 0),
          ],
        ).createShader(bounds),
    );

    final arcs = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.012
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.055);
    final centre = Offset(size.width * 0.5, size.height * 1.18);
    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(centre, size.width * (0.46 + i * 0.26), arcs);
    }
  }

  /// The rising arc and the ball, scaled to fill [size].
  ///
  /// [arcProgress] draws the arc partially, which the launch sequence animates.
  ///
  /// [monochrome] renders the themed-icon silhouette. Android tints that layer
  /// with a single wallpaper colour and keeps only its alpha, so the seams are
  /// cut out of the shape rather than drawn on top of it.
  static void paintMark(
    Canvas canvas,
    Size size, {
    bool monochrome = false,
    double arcProgress = 1,
  }) {
    final w = size.width;
    final h = size.height;
    final bounds = Offset.zero & size;
    final ballCentre = Offset(w * 0.735, h * 0.665);
    final ballRadius = w * 0.150;

    // Erasing composites only against what the current layer already holds,
    // so the mark needs a layer of its own to cut away from.
    if (monochrome) canvas.saveLayer(bounds, Paint());

    final arc = Path()
      ..moveTo(w * 0.20, h * 0.76)
      ..cubicTo(w * 0.24, h * 0.24, w * 0.66, h * 0.16, w * 0.80, h * 0.44);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.085
      ..strokeCap = StrokeCap.round;
    if (monochrome) {
      arcPaint.color = const Color(0xFFFFFFFF);
    } else {
      arcPaint.shader = const LinearGradient(
        colors: [Color(0xFFFFB27A), AvColors.flare],
      ).createShader(bounds);
    }
    if (arcProgress >= 1) {
      canvas.drawPath(arc, arcPaint);
    } else {
      for (final metric in arc.computeMetrics()) {
        canvas.drawPath(
          metric.extractPath(0, metric.length * arcProgress),
          arcPaint,
        );
      }
    }

    // Flattened to one colour the arc and the ball merge into a blob, so the
    // ball gets a gap punched around it to keep its edge.
    if (monochrome) {
      canvas.drawCircle(
        ballCentre,
        ballRadius + w * 0.030,
        Paint()..blendMode = BlendMode.clear,
      );
    }

    final ballPaint = Paint();
    if (monochrome) {
      ballPaint.color = const Color(0xFFFFFFFF);
    } else {
      ballPaint.shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF8A4C), AvColors.flareDeep],
      ).createShader(Rect.fromCircle(center: ballCentre, radius: ballRadius));
    }
    canvas.drawCircle(ballCentre, ballRadius, ballPaint);

    final seam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * (monochrome ? 0.026 : 0.020);
    if (monochrome) {
      seam.blendMode = BlendMode.clear;
    } else {
      seam.color = const Color(0xFFFFFFFF).withValues(alpha: 0.72);
    }

    // Clipped to the ball: left loose, the curved seams run off into the
    // shot arc and the whole mark turns into a tangle of overlapping strokes.
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: ballCentre, radius: ballRadius)),
    );
    canvas.drawLine(
      ballCentre - Offset(ballRadius, 0),
      ballCentre + Offset(ballRadius, 0),
      seam,
    );
    for (final side in const [-1.0, 1.0]) {
      canvas.drawArc(
        Rect.fromCircle(
          center: ballCentre + Offset(side * ballRadius * 1.50, 0),
          radius: ballRadius * 1.28,
        ),
        side < 0 ? -math.pi * 0.38 : math.pi * 0.62,
        math.pi * 0.76,
        false,
        seam,
      );
    }
    canvas.restore();

    if (monochrome) canvas.restore();
  }

  /// Where the ink actually lands inside [paintMark]'s unit square, stroke
  /// widths included. The mark is drawn with slack around it for use as a
  /// badge in the app, and an icon that inherited that slack would float in
  /// the middle of the tile looking undersized.
  static const Rect _markContent = Rect.fromLTRB(0.158, 0.239, 0.885, 0.815);

  /// Draws the mark centred in [size], its content spanning [fraction] of the
  /// width.
  static void paintMarkInset(
    Canvas canvas,
    Size size,
    double fraction, {
    bool monochrome = false,
    double arcProgress = 1,
  }) {
    final scale = size.width * fraction / _markContent.width;

    canvas.save();
    canvas.translate(
      (size.width - _markContent.width * scale) / 2 - _markContent.left * scale,
      (size.height - _markContent.height * scale) / 2 -
          _markContent.top * scale,
    );
    canvas.scale(scale);
    paintMark(
      canvas,
      const Size(1, 1),
      monochrome: monochrome,
      arcProgress: arcProgress,
    );
    canvas.restore();
  }
}
