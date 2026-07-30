import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../data/models/shot.dart';

/// Side-on arc diagram for a single attempt, with release angle, apex and
/// entry angle drawn from the measured trajectory.
class AvArcDiagram extends StatelessWidget {
  const AvArcDiagram({
    super.key,
    required this.shot,
    this.comparison,
    this.height = 190,
    this.showAnnotations = true,
    this.onInk = false,
  });

  final Shot shot;

  /// Optional second attempt drawn as a ghost, used for best-shot comparison.
  final Shot? comparison;
  final double height;
  final bool showAnnotations;
  final bool onInk;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _ArcPainter(
          shot: shot,
          comparison: comparison,
          showAnnotations: showAnnotations,
          onInk: onInk,
          textDirection: Directionality.of(context),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({
    required this.shot,
    required this.comparison,
    required this.showAnnotations,
    required this.onInk,
    required this.textDirection,
  });

  final Shot shot;
  final Shot? comparison;
  final bool showAnnotations;
  final bool onInk;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final floorY = size.height - 18;
    final lineColor = onInk
        ? Colors.white.withValues(alpha: 0.22)
        : AvColors.hairlineStrong;

    // Floor.
    canvas.drawLine(
      Offset(0, floorY),
      Offset(size.width, floorY),
      Paint()
        ..strokeWidth = 1.2
        ..color = lineColor,
    );

    // Hoop and backboard on the right.
    final rimY = floorY - size.height * 0.44;
    final rimX = size.width * 0.86;
    canvas.drawLine(
      Offset(rimX - 26, rimY),
      Offset(rimX + 6, rimY),
      Paint()
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = AvColors.flare,
    );
    canvas.drawLine(
      Offset(rimX + 8, rimY - 34),
      Offset(rimX + 8, rimY + 10),
      Paint()
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = onInk
            ? Colors.white.withValues(alpha: 0.5)
            : AvColors.hairlineStrong,
    );
    canvas.drawLine(
      Offset(rimX + 8, rimY + 10),
      Offset(rimX + 8, floorY),
      Paint()
        ..strokeWidth = 2
        ..color = lineColor,
    );

    if (comparison != null) {
      _drawPath(
        canvas,
        size,
        comparison!,
        AvColors.insight.withValues(alpha: 0.55),
        dashed: true,
      );
    }

    _drawPath(
      canvas,
      size,
      shot,
      shot.isMake ? AvColors.made : AvColors.flare,
    );

    if (!showAnnotations) return;

    final points = _points(size, shot);
    if (points.length < 3) return;

    // Release angle wedge.
    final release = points.first;
    canvas.drawCircle(release, 4.5, Paint()..color = AvColors.flare);
    canvas.drawLine(
      release,
      release + const Offset(46, 0),
      Paint()
        ..strokeWidth = 1
        ..color = lineColor,
    );
    _label(
      canvas,
      '${shot.releaseAngle.toStringAsFixed(0)}\u00B0 release',
      release + const Offset(10, 12),
      AvColors.flare,
    );

    // Apex marker.
    var apex = points.first;
    for (final p in points) {
      if (p.dy < apex.dy) apex = p;
    }
    canvas.drawCircle(
      apex,
      3.6,
      Paint()..color = onInk ? Colors.white : AvColors.ink,
    );
    _label(
      canvas,
      'Apex ${shot.apexHeightM.toStringAsFixed(2)} m',
      apex + const Offset(-24, -20),
      onInk ? Colors.white : AvColors.textSecondary,
    );

    // Entry angle.
    _label(
      canvas,
      '${shot.entryAngle.toStringAsFixed(0)}\u00B0 entry',
      Offset(rimX - 88, rimY - 26),
      shot.isMake ? AvColors.made : AvColors.miss,
    );
  }

  List<Offset> _points(Size size, Shot source) {
    final floorY = size.height - 18;
    return source.trajectory
        .map(
          (p) => Offset(
            p.dx * size.width,
            p.dy * (floorY - 8) + 4,
          ),
        )
        .toList(growable: false);
  }

  void _drawPath(
    Canvas canvas,
    Size size,
    Shot source,
    Color color, {
    bool dashed = false,
  }) {
    final points = _points(size, source);
    if (points.length < 2) return;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = dashed ? 2 : 3
      ..strokeCap = StrokeCap.round
      ..color = color;

    if (!dashed) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: 0.14),
      );
      canvas.drawPath(path, paint);
      return;
    }

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + 6, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + 5;
      }
    }
  }

  void _label(Canvas canvas, String text, Offset at, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: AvType.overline.copyWith(color: color, letterSpacing: 0.4),
      ),
      textDirection: textDirection,
    )..layout();
    painter.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) =>
      oldDelegate.shot != shot || oldDelegate.comparison != comparison;
}

/// Phase timeline for one attempt. Segment width is proportional to measured
/// duration so timing problems are visible rather than described.
class AvPhaseTimeline extends StatelessWidget {
  const AvPhaseTimeline({
    super.key,
    required this.phases,
    this.highlight,
    this.onInk = false,
  });

  final List<ShotPhase> phases;
  final String? highlight;
  final bool onInk;

  static const List<Color> _palette = [
    AvColors.court,
    AvColors.courtDeep,
    AvColors.insight,
    AvColors.insightDeep,
    AvColors.flare,
    AvColors.flareDeep,
    AvColors.made,
    AvColors.madeDeep,
    AvColors.caution,
    AvColors.unavailable,
  ];

  @override
  Widget build(BuildContext context) {
    if (phases.isEmpty) return const SizedBox.shrink();
    final total =
        phases.map((p) => p.durationMs).reduce((a, b) => a + b).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: AvRadius.pill,
          child: SizedBox(
            height: 16,
            child: Row(
              children: [
                for (var i = 0; i < phases.length; i++)
                  Expanded(
                    flex: math.max(1, phases[i].durationMs),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _palette[i % _palette.length].withValues(
                          alpha: highlight == null ||
                                  highlight == phases[i].name
                              ? 1
                              : 0.3,
                        ),
                        border: Border(
                          right: BorderSide(
                            color: onInk
                                ? AvColors.ink
                                : Colors.white.withValues(alpha: 0.9),
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AvSpace.sm),
        Wrap(
          spacing: AvSpace.sm,
          runSpacing: 6,
          children: [
            for (var i = 0; i < phases.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _palette[i % _palette.length],
                      borderRadius: AvRadius.allXs,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${phases[i].name} ${phases[i].durationMs} ms',
                    style: AvType.caption.copyWith(
                      color: onInk
                          ? AvColors.textOnInkMuted
                          : AvColors.textMuted,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Total motion ${total.toStringAsFixed(0)} ms',
          style: AvType.caption.faint,
        ),
      ],
    );
  }
}

/// Rim-plane accuracy plot: where the ball crossed relative to the centre of
/// the rim, in centimetres.
class AvRimPlot extends StatelessWidget {
  const AvRimPlot({
    super.key,
    required this.shots,
    this.height = 190,
    this.highlightShotId,
  });

  final List<Shot> shots;
  final double height;
  final String? highlightShotId;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _RimPlotPainter(
          shots: shots,
          highlightShotId: highlightShotId,
          textDirection: Directionality.of(context),
        ),
      ),
    );
  }
}

class _RimPlotPainter extends CustomPainter {
  const _RimPlotPainter({
    required this.shots,
    required this.highlightShotId,
    required this.textDirection,
  });

  final List<Shot> shots;
  final String? highlightShotId;
  final TextDirection textDirection;

  static const double _rangeCm = 40;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final scale = math.min(size.width, size.height) / 2 / _rangeCm;

    for (final ring in [10.0, 20.0, 30.0, 40.0]) {
      canvas.drawCircle(
        centre,
        ring * scale,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = AvColors.hairline,
      );
      final painter = TextPainter(
        text: TextSpan(
          text: '${ring.toStringAsFixed(0)} cm',
          style: AvType.overline.copyWith(
            color: AvColors.textFaint,
            letterSpacing: 0,
          ),
        ),
        textDirection: textDirection,
      )..layout();
      painter.paint(canvas, centre + Offset(ring * scale - painter.width, 3));
    }

    // Rim opening: 22.9 cm ball through a 45.7 cm rim leaves 11.4 cm of margin.
    canvas.drawCircle(
      centre,
      11.4 * scale,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AvColors.flare.withValues(alpha: 0.7),
    );

    final axis = Paint()
      ..strokeWidth = 1
      ..color = AvColors.hairlineStrong;
    canvas.drawLine(
      Offset(0, centre.dy),
      Offset(size.width, centre.dy),
      axis,
    );
    canvas.drawLine(
      Offset(centre.dx, 0),
      Offset(centre.dx, size.height),
      axis,
    );

    for (final shot in shots) {
      final point = centre +
          Offset(
            shot.lateralDeviationCm.clamp(-_rangeCm, _rangeCm) * scale,
            -shot.depthCm.clamp(-_rangeCm, _rangeCm) * scale,
          );
      final highlighted = shot.id == highlightShotId;
      final color = shot.result.color;
      canvas.drawCircle(
        point,
        highlighted ? 6 : 4,
        Paint()..color = color.withValues(alpha: highlighted ? 1 : 0.62),
      );
      if (highlighted) {
        canvas.drawCircle(
          point,
          9,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = color,
        );
      }
    }

    _axisLabel(canvas, 'Left', Offset(6, centre.dy - 16));
    _axisLabel(
      canvas,
      'Right',
      Offset(size.width - 34, centre.dy - 16),
    );
    _axisLabel(canvas, 'Long', Offset(centre.dx + 8, 4));
    _axisLabel(canvas, 'Short', Offset(centre.dx + 8, size.height - 16));
  }

  void _axisLabel(Canvas canvas, String text, Offset at) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: AvType.overline.copyWith(
          color: AvColors.textFaint,
          letterSpacing: 0.6,
        ),
      ),
      textDirection: textDirection,
    )..layout();
    painter.paint(canvas, at);
  }

  @override
  bool shouldRepaint(_RimPlotPainter oldDelegate) =>
      oldDelegate.shots != shots ||
      oldDelegate.highlightShotId != highlightShotId;
}
