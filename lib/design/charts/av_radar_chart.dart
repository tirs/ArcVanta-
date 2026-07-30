import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/av_colors.dart';
import '../../core/theme/av_typography.dart';

class RadarAxis {
  const RadarAxis({required this.label, required this.value, this.baseline});

  final String label;

  /// Normalised 0 to 1.
  final double value;

  /// The athlete's own rolling baseline, drawn as a reference ring.
  final double? baseline;
}

/// Mechanics profile. Compares the current session against the athlete's own
/// baseline rather than a universal ideal, as required by the coaching model.
class AvRadarChart extends StatelessWidget {
  const AvRadarChart({
    super.key,
    required this.axes,
    this.color = AvColors.insight,
    this.baselineColor = AvColors.flare,
    this.size = 240,
  });

  final List<RadarAxis> axes;
  final Color color;
  final Color baselineColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      child: CustomPaint(
        size: Size.infinite,
        painter: _RadarPainter(
          axes: axes,
          color: color,
          baselineColor: baselineColor,
          textDirection: Directionality.of(context),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter({
    required this.axes,
    required this.color,
    required this.baselineColor,
    required this.textDirection,
  });

  final List<RadarAxis> axes;
  final Color color;
  final Color baselineColor;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    if (axes.length < 3) return;
    final centre = Offset(size.width / 2, size.height / 2 + 2);
    final radius = math.min(size.width, size.height) / 2 - 34;

    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AvColors.hairline;

    for (var ring = 1; ring <= 4; ring++) {
      final path = Path();
      for (var i = 0; i < axes.length; i++) {
        final point = _point(centre, radius * ring / 4, i);
        i == 0
            ? path.moveTo(point.dx, point.dy)
            : path.lineTo(point.dx, point.dy);
      }
      path.close();
      canvas.drawPath(path, grid);
    }

    for (var i = 0; i < axes.length; i++) {
      canvas.drawLine(centre, _point(centre, radius, i), grid);
    }

    if (axes.any((a) => a.baseline != null)) {
      final path = Path();
      for (var i = 0; i < axes.length; i++) {
        final value = axes[i].baseline ?? axes[i].value;
        final point = _point(centre, radius * value.clamp(0, 1), i);
        i == 0
            ? path.moveTo(point.dx, point.dy)
            : path.lineTo(point.dx, point.dy);
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = baselineColor.withValues(alpha: 0.75),
      );
    }

    final path = Path();
    for (var i = 0; i < axes.length; i++) {
      final point = _point(centre, radius * axes[i].value.clamp(0, 1), i);
      i == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.42),
            color.withValues(alpha: 0.16),
          ],
        ).createShader(Rect.fromCircle(center: centre, radius: radius)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

    for (var i = 0; i < axes.length; i++) {
      final point = _point(centre, radius * axes[i].value.clamp(0, 1), i);
      canvas.drawCircle(point, 4.2, Paint()..color = Colors.white);
      canvas.drawCircle(point, 3, Paint()..color = color);

      final labelPoint = _point(centre, radius + 20, i);
      final painter = TextPainter(
        text: TextSpan(
          text: axes[i].label,
          style: AvType.overline.copyWith(
            color: AvColors.textMuted,
            letterSpacing: 0.3,
          ),
        ),
        textDirection: textDirection,
        textAlign: TextAlign.center,
      )..layout(maxWidth: 78);
      painter.paint(
        canvas,
        labelPoint - Offset(painter.width / 2, painter.height / 2),
      );
    }
  }

  Offset _point(Offset centre, double radius, int index) {
    final angle = -math.pi / 2 + index * 2 * math.pi / axes.length;
    return centre + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) =>
      oldDelegate.axes != axes || oldDelegate.color != color;
}
