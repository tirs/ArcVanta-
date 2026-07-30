import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../data/models/session.dart';
import '../../data/models/shot.dart';

/// Half-court geometry in feet, measured from the baseline.
abstract final class CourtGeometry {
  static const double widthFt = 50;
  static const double depthFt = 35;
  static const double rimFromBaselineFt = 5.25;
  static const double rimRadiusFt = 0.75;
  static const double keyHalfWidthFt = 8;
  static const double freeThrowFt = 19;
  static const double freeThrowCircleFt = 6;
  static const double restrictedRadiusFt = 4;
  static const double cornerThreeXFt = 22;
  static const double threeRadiusFt = 23.75;
  static const double backboardHalfWidthFt = 3;
  static const double backboardFromBaselineFt = 4;

  static double get cornerBreakFt =>
      rimFromBaselineFt +
      math.sqrt(
        threeRadiusFt * threeRadiusFt - cornerThreeXFt * cornerThreeXFt,
      );

  static const double aspect = widthFt / depthFt;
}

/// Draws the half court. Reused by the shot chart, the placement guide and the
/// calibration preview so court graphics stay identical across the product.
class CourtPainter extends CustomPainter {
  const CourtPainter({
    required this.lineColor,
    this.floorColor,
    this.keyColor,
    this.lineWidth = 1.4,
    this.showRestricted = true,
  });

  final Color lineColor;
  final Color? floorColor;
  final Color? keyColor;
  final double lineWidth;
  final bool showRestricted;

  Offset _p(Size size, double xFt, double yFt) => Offset(
        (xFt + CourtGeometry.widthFt / 2) / CourtGeometry.widthFt * size.width,
        size.height - yFt / CourtGeometry.depthFt * size.height,
      );

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / CourtGeometry.widthFt;
    final scaleY = size.height / CourtGeometry.depthFt;

    if (floorColor != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = floorColor!);
    }

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round
      ..color = lineColor;

    // Key.
    final keyRect = Rect.fromPoints(
      _p(size, -CourtGeometry.keyHalfWidthFt, 0),
      _p(size, CourtGeometry.keyHalfWidthFt, CourtGeometry.freeThrowFt),
    );
    if (keyColor != null) {
      canvas.drawRect(keyRect, Paint()..color = keyColor!);
    }
    canvas.drawRect(keyRect, line);

    // Free-throw circle.
    canvas.drawOval(
      Rect.fromCenter(
        center: _p(size, 0, CourtGeometry.freeThrowFt),
        width: CourtGeometry.freeThrowCircleFt * 2 * scaleX,
        height: CourtGeometry.freeThrowCircleFt * 2 * scaleY,
      ),
      line,
    );

    // Restricted area.
    if (showRestricted) {
      canvas.drawArc(
        Rect.fromCenter(
          center: _p(size, 0, CourtGeometry.rimFromBaselineFt),
          width: CourtGeometry.restrictedRadiusFt * 2 * scaleX,
          height: CourtGeometry.restrictedRadiusFt * 2 * scaleY,
        ),
        0,
        -math.pi,
        false,
        line,
      );
    }

    // Backboard and rim.
    canvas.drawLine(
      _p(size, -CourtGeometry.backboardHalfWidthFt,
          CourtGeometry.backboardFromBaselineFt),
      _p(size, CourtGeometry.backboardHalfWidthFt,
          CourtGeometry.backboardFromBaselineFt),
      Paint()
        ..strokeWidth = lineWidth * 1.8
        ..strokeCap = StrokeCap.round
        ..color = lineColor,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: _p(size, 0, CourtGeometry.rimFromBaselineFt),
        width: CourtGeometry.rimRadiusFt * 2 * scaleX,
        height: CourtGeometry.rimRadiusFt * 2 * scaleY,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = lineWidth * 1.3
        ..color = lineColor,
    );

    // Three-point line: two straight corner segments joined by the arc.
    final breakFt = CourtGeometry.cornerBreakFt;
    canvas.drawLine(
      _p(size, -CourtGeometry.cornerThreeXFt, 0),
      _p(size, -CourtGeometry.cornerThreeXFt, breakFt),
      line,
    );
    canvas.drawLine(
      _p(size, CourtGeometry.cornerThreeXFt, 0),
      _p(size, CourtGeometry.cornerThreeXFt, breakFt),
      line,
    );

    final theta = math.acos(
      CourtGeometry.cornerThreeXFt / CourtGeometry.threeRadiusFt,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: _p(size, 0, CourtGeometry.rimFromBaselineFt),
        width: CourtGeometry.threeRadiusFt * 2 * scaleX,
        height: CourtGeometry.threeRadiusFt * 2 * scaleY,
      ),
      -theta,
      -(math.pi - 2 * theta),
      false,
      line,
    );

    // Baseline and sidelines.
    canvas.drawRect(
      Rect.fromLTRB(0, 0, size.width, size.height).deflate(lineWidth / 2),
      line..color = lineColor.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(CourtPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor ||
      oldDelegate.floorColor != floorColor ||
      oldDelegate.keyColor != keyColor;
}

enum CourtMapMode { heat, markers }

/// Shot chart. Renders either a zone heatmap or individual attempt markers.
class AvCourtMap extends StatelessWidget {
  const AvCourtMap({
    super.key,
    required this.zones,
    this.shots = const [],
    this.mode = CourtMapMode.heat,
    this.onZoneTap,
    this.selectedZone,
    this.minimumSample = 4,
    this.onInk = false,
  });

  final Map<CourtZone, ZoneRecord> zones;
  final List<Shot> shots;
  final CourtMapMode mode;
  final ValueChanged<CourtZone>? onZoneTap;
  final CourtZone? selectedZone;

  /// Zones below this attempt count are shown as low-sample rather than being
  /// given a colour that implies a reliable rate.
  final int minimumSample;
  final bool onInk;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: CourtGeometry.aspect,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size =
              Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            onTapUp: onZoneTap == null
                ? null
                : (details) => _handleTap(details.localPosition, size),
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: AvRadius.allMd,
                    gradient: onInk
                        ? const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF1D1F3A), Color(0xFF141628)],
                          )
                        : const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFFFFDF8), Color(0xFFF6F1E6)],
                          ),
                    border: Border.all(
                      color: onInk
                          ? AvColors.hairlineOnInk
                          : AvColors.hairline,
                    ),
                  ),
                ),
                ClipRRect(
                  borderRadius: AvRadius.allMd,
                  child: CustomPaint(
                    painter: _CourtMapPainter(
                      zones: zones,
                      shots: shots,
                      mode: mode,
                      selectedZone: selectedZone,
                      minimumSample: minimumSample,
                      onInk: onInk,
                      textDirection: Directionality.of(context),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleTap(Offset position, Size size) {
    CourtZone? nearest;
    var best = double.infinity;
    for (final zone in CourtZone.values) {
      final centre = Offset(
        zone.position.dx * size.width,
        size.height - zone.position.dy * size.height,
      );
      final distance = (centre - position).distance;
      if (distance < best) {
        best = distance;
        nearest = zone;
      }
    }
    if (nearest != null && best < size.width * 0.18) {
      onZoneTap!(nearest);
    }
  }
}

class _CourtMapPainter extends CustomPainter {
  const _CourtMapPainter({
    required this.zones,
    required this.shots,
    required this.mode,
    required this.selectedZone,
    required this.minimumSample,
    required this.onInk,
    required this.textDirection,
  });

  final Map<CourtZone, ZoneRecord> zones;
  final List<Shot> shots;
  final CourtMapMode mode;
  final CourtZone? selectedZone;
  final int minimumSample;
  final bool onInk;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    if (mode == CourtMapMode.heat) _paintHeat(canvas, size);

    CourtPainter(
      lineColor: onInk
          ? Colors.white.withValues(alpha: 0.34)
          : AvColors.hairlineStrong,
      lineWidth: 1.3,
    ).paint(canvas, size);

    if (mode == CourtMapMode.heat) {
      _paintZoneLabels(canvas, size);
    } else {
      _paintMarkers(canvas, size);
    }
  }

  Offset _zonePoint(CourtZone zone, Size size) => Offset(
        zone.position.dx * size.width,
        size.height - zone.position.dy * size.height,
      );

  void _paintHeat(Canvas canvas, Size size) {
    for (final entry in zones.entries) {
      final record = entry.value;
      if (record.attempts == 0) continue;
      final centre = _zonePoint(entry.key, size);
      final radius = size.width * (0.10 + math.min(record.attempts, 24) * 0.004);
      final lowSample = record.attempts < minimumSample;
      final color = lowSample
          ? AvColors.unavailable
          : _heatColor(record.percentage);

      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: lowSample ? 0.20 : 0.55),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: centre, radius: radius)),
      );
    }
  }

  void _paintZoneLabels(Canvas canvas, Size size) {
    for (final entry in zones.entries) {
      final record = entry.value;
      if (record.attempts == 0) continue;
      final centre = _zonePoint(entry.key, size);
      final lowSample = record.attempts < minimumSample;
      final selected = entry.key == selectedZone;

      final chipColor = lowSample
          ? AvColors.unavailable
          : _heatColor(record.percentage);

      final label = lowSample
          ? '${record.makes}/${record.attempts}'
          : '${record.percentage.toStringAsFixed(0)}%';

      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: AvType.tabular(AvType.label).copyWith(
            color: Colors.white,
            fontSize: 11.5,
          ),
        ),
        textDirection: textDirection,
      )..layout();

      final chipRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: centre,
          width: painter.width + 16,
          height: painter.height + 9,
        ),
        const Radius.circular(999),
      );

      canvas.drawRRect(
        chipRect,
        Paint()
          ..color = chipColor.withValues(alpha: selected ? 1 : 0.92),
      );
      if (selected) {
        canvas.drawRRect(
          chipRect.inflate(3),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = AvColors.ink.withValues(alpha: onInk ? 0 : 0.6),
        );
      }
      painter.paint(
        canvas,
        centre - Offset(painter.width / 2, painter.height / 2),
      );

      if (!lowSample) {
        final sub = TextPainter(
          text: TextSpan(
            text: '${record.makes}/${record.attempts}',
            style: AvType.tabular(AvType.overline).copyWith(
              color: onInk
                  ? Colors.white.withValues(alpha: 0.72)
                  : AvColors.textMuted,
              letterSpacing: 0,
            ),
          ),
          textDirection: textDirection,
        )..layout();
        sub.paint(
          canvas,
          centre + Offset(-sub.width / 2, painter.height / 2 + 7),
        );
      }
    }
  }

  void _paintMarkers(Canvas canvas, Size size) {
    final random = math.Random(9134);
    for (final shot in shots) {
      final base = _zonePoint(shot.zone, size);
      final jitter = Offset(
        (random.nextDouble() - 0.5) * size.width * 0.085 +
            shot.lateralDeviationCm / 240 * size.width * 0.1,
        (random.nextDouble() - 0.5) * size.height * 0.07,
      );
      final point = base + jitter;

      switch (shot.result) {
        case ShotResult.made:
          canvas.drawCircle(
            point,
            5.2,
            Paint()..color = AvColors.made.withValues(alpha: 0.9),
          );
          canvas.drawCircle(
            point,
            5.2,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4
              ..color = Colors.white.withValues(alpha: onInk ? 0.5 : 0.9),
          );
        case ShotResult.missed:
          final paint = Paint()
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round
            ..color = AvColors.miss.withValues(alpha: 0.92);
          canvas.drawLine(
            point + const Offset(-4.4, -4.4),
            point + const Offset(4.4, 4.4),
            paint,
          );
          canvas.drawLine(
            point + const Offset(4.4, -4.4),
            point + const Offset(-4.4, 4.4),
            paint,
          );
        case ShotResult.uncertain:
          canvas.drawCircle(
            point,
            5,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = AvColors.caution,
          );
        case ShotResult.blocked:
        case ShotResult.invalid:
          canvas.drawCircle(
            point,
            4,
            Paint()..color = AvColors.unavailable.withValues(alpha: 0.7),
          );
      }
    }
  }

  static Color _heatColor(double percentage) {
    final ramp = AvColors.heat;
    final t = (percentage / 70).clamp(0.0, 1.0);
    final scaled = t * (ramp.length - 1);
    final index = scaled.floor().clamp(0, ramp.length - 2);
    return Color.lerp(ramp[index], ramp[index + 1], scaled - index)!;
  }

  @override
  bool shouldRepaint(_CourtMapPainter oldDelegate) =>
      oldDelegate.zones != zones ||
      oldDelegate.shots != shots ||
      oldDelegate.mode != mode ||
      oldDelegate.selectedZone != selectedZone;
}

/// Legend explaining the heat ramp and the low-sample state.
class AvCourtLegend extends StatelessWidget {
  const AvCourtLegend({super.key, this.minimumSample = 4});

  final int minimumSample;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Cold', style: AvType.caption.faint),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            height: 7,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AvColors.heat),
              borderRadius: AvRadius.pill,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text('Hot', style: AvType.caption.faint),
        const SizedBox(width: AvSpace.md),
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: AvColors.unavailable.withValues(alpha: 0.35),
            shape: BoxShape.circle,
            border: Border.all(color: AvColors.unavailable),
          ),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            'Under $minimumSample attempts',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AvType.caption.faint,
          ),
        ),
      ],
    );
  }
}
