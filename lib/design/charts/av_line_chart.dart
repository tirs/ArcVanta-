import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';

class ChartSeries {
  const ChartSeries({
    required this.label,
    required this.values,
    required this.color,
    this.fill = true,
    this.dashed = false,
  });

  final String label;
  final List<double> values;
  final Color color;
  final bool fill;
  final bool dashed;
}

/// Trend chart with a soft gradient fill, gridlines, axis labels and an
/// interactive readout. Values of `double.nan` mark days without training so
/// the line breaks rather than implying data that does not exist.
class AvLineChart extends StatefulWidget {
  const AvLineChart({
    super.key,
    required this.series,
    required this.xLabels,
    this.height = 200,
    this.minY,
    this.maxY,
    this.yUnit = '',
    this.gridLines = 4,
    this.valueFormatter,
    this.targetLine,
    this.targetLabel,
  });

  final List<ChartSeries> series;
  final List<String> xLabels;
  final double height;
  final double? minY;
  final double? maxY;
  final String yUnit;
  final int gridLines;
  final String Function(double value)? valueFormatter;
  final double? targetLine;
  final String? targetLabel;

  @override
  State<AvLineChart> createState() => _AvLineChartState();
}

class _AvLineChartState extends State<AvLineChart> {
  int? _activeIndex;

  int get _length => widget.series.isEmpty
      ? 0
      : widget.series.map((s) => s.values.length).reduce(math.max);

  (double, double) get _bounds {
    final all = widget.series
        .expand((s) => s.values)
        .where((v) => !v.isNaN)
        .toList(growable: false);
    if (all.isEmpty) return (0, 1);
    var lo = widget.minY ?? all.reduce(math.min);
    var hi = widget.maxY ?? all.reduce(math.max);
    if (widget.targetLine != null) {
      lo = math.min(lo, widget.targetLine!);
      hi = math.max(hi, widget.targetLine!);
    }
    if ((hi - lo).abs() < 0.0001) {
      lo -= 1;
      hi += 1;
    }
    final pad = (hi - lo) * 0.14;
    return (widget.minY ?? lo - pad, widget.maxY ?? hi + pad);
  }

  String _format(double v) =>
      widget.valueFormatter?.call(v) ?? v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final (minY, maxY) = _bounds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) =>
                    _updateActive(d.localPosition, constraints.maxWidth),
                onHorizontalDragUpdate: (d) =>
                    _updateActive(d.localPosition, constraints.maxWidth),
                onHorizontalDragEnd: (_) => setState(() => _activeIndex = null),
                onTapUp: (_) => setState(() => _activeIndex = null),
                child: CustomPaint(
                  size: Size(constraints.maxWidth, widget.height),
                  painter: _LineChartPainter(
                    series: widget.series,
                    minY: minY,
                    maxY: maxY,
                    gridLines: widget.gridLines,
                    activeIndex: _activeIndex,
                    labelFormatter: _format,
                    yUnit: widget.yUnit,
                    targetLine: widget.targetLine,
                    targetLabel: widget.targetLabel,
                    textDirection: Directionality.of(context),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AvSpace.xs),
        LayoutBuilder(
          builder: (context, constraints) {
            final labels = widget.xLabels;
            if (labels.isEmpty) return const SizedBox.shrink();

            // Thin the ticks until they fit; a crowded axis reads as noise.
            final room = (constraints.maxWidth / 76).floor().clamp(2, 6);
            final step = (labels.length / room).ceil();
            final kept = <int>[for (var i = 0; i < labels.length; i += step) i];
            if (kept.last != labels.length - 1) kept.add(labels.length - 1);

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final index in kept)
                  Text(
                    labels[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AvType.caption.faint,
                  ),
              ],
            );
          },
        ),
        if (widget.series.length > 1) ...[
          const SizedBox(height: AvSpace.sm),
          Wrap(
            spacing: AvSpace.md,
            runSpacing: 6,
            children: [
              for (final s in widget.series)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 3,
                      decoration: BoxDecoration(
                        color: s.color,
                        borderRadius: AvRadius.pill,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        s.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AvType.caption.muted,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
        if (_activeIndex != null) ...[
          const SizedBox(height: AvSpace.xs),
          Text(
            widget.series
                .map((s) {
                  final v = _activeIndex! < s.values.length
                      ? s.values[_activeIndex!]
                      : double.nan;
                  return '${s.label} ${v.isNaN ? 'no session' : '${_format(v)}${widget.yUnit}'}';
                })
                .join('   \u00B7   '),
            style: AvType.tabular(AvType.caption).secondary,
          ),
        ],
      ],
    );
  }

  void _updateActive(Offset position, double width) {
    if (_length == 0) return;
    final step = width / math.max(_length - 1, 1);
    final index = (position.dx / step).round().clamp(0, _length - 1);
    if (index != _activeIndex) setState(() => _activeIndex = index);
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.series,
    required this.minY,
    required this.maxY,
    required this.gridLines,
    required this.activeIndex,
    required this.labelFormatter,
    required this.yUnit,
    required this.targetLine,
    required this.targetLabel,
    required this.textDirection,
  });

  final List<ChartSeries> series;
  final double minY;
  final double maxY;
  final int gridLines;
  final int? activeIndex;
  final String Function(double) labelFormatter;
  final String yUnit;
  final double? targetLine;
  final String? targetLabel;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 38.0;
    final plot = Rect.fromLTWH(
      leftPad,
      6,
      size.width - leftPad,
      size.height - 12,
    );

    double toY(double value) =>
        plot.bottom - (value - minY) / (maxY - minY) * plot.height;

    final grid = Paint()
      ..color = AvColors.hairline
      ..strokeWidth = 1;

    for (var i = 0; i <= gridLines; i++) {
      final value = minY + (maxY - minY) * i / gridLines;
      final y = toY(value);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      _text(
        canvas,
        labelFormatter(value),
        Offset(plot.left - 6, y),
        AvType.tabular(
          AvType.overline,
        ).copyWith(color: AvColors.textFaint, letterSpacing: 0),
        alignRight: true,
      );
    }

    if (targetLine != null) {
      final y = toY(targetLine!);
      final dash = Paint()
        ..color = AvColors.insight.withValues(alpha: 0.6)
        ..strokeWidth = 1.4;
      var x = plot.left;
      while (x < plot.right) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 5, plot.right), y),
          dash,
        );
        x += 9;
      }
      if (targetLabel != null) {
        _text(
          canvas,
          targetLabel!,
          Offset(plot.right - 2, y - 12),
          AvType.overline.copyWith(color: AvColors.insight, letterSpacing: 0.4),
          alignRight: true,
        );
      }
    }

    for (final s in series) {
      _paintSeries(canvas, plot, s, toY);
    }

    if (activeIndex != null && series.isNotEmpty) {
      final count = series.map((s) => s.values.length).reduce(math.max);
      final step = plot.width / math.max(count - 1, 1);
      final x = plot.left + step * activeIndex!;
      canvas.drawLine(
        Offset(x, plot.top),
        Offset(x, plot.bottom),
        Paint()
          ..color = AvColors.ink.withValues(alpha: 0.28)
          ..strokeWidth = 1.2,
      );
      for (final s in series) {
        if (activeIndex! >= s.values.length) continue;
        final v = s.values[activeIndex!];
        if (v.isNaN) continue;
        canvas.drawCircle(
          Offset(x, toY(v)),
          5.5,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(Offset(x, toY(v)), 4, Paint()..color = s.color);
      }
    }
  }

  void _paintSeries(
    Canvas canvas,
    Rect plot,
    ChartSeries s,
    double Function(double) toY,
  ) {
    if (s.values.isEmpty) return;
    final step = plot.width / math.max(s.values.length - 1, 1);

    final segments = <List<Offset>>[];
    var current = <Offset>[];
    for (var i = 0; i < s.values.length; i++) {
      final v = s.values[i];
      if (v.isNaN) {
        if (current.length > 1) segments.add(current);
        current = <Offset>[];
        continue;
      }
      current.add(Offset(plot.left + step * i, toY(v)));
    }
    if (current.length > 1) segments.add(current);

    for (final points in segments) {
      final path = _smoothPath(points);

      if (s.fill) {
        final fillPath = Path.from(path)
          ..lineTo(points.last.dx, plot.bottom)
          ..lineTo(points.first.dx, plot.bottom)
          ..close();
        canvas.drawPath(
          fillPath,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                s.color.withValues(alpha: 0.26),
                s.color.withValues(alpha: 0.0),
              ],
            ).createShader(plot),
        );
      }

      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = s.color,
      );
    }
  }

  Path _smoothPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      path.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }
    return path;
  }

  void _text(
    Canvas canvas,
    String value,
    Offset position,
    TextStyle style, {
    bool alignRight = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: textDirection,
    )..layout();
    painter.paint(
      canvas,
      Offset(
        alignRight ? position.dx - painter.width : position.dx,
        position.dy - painter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(_LineChartPainter oldDelegate) =>
      oldDelegate.activeIndex != activeIndex ||
      oldDelegate.series != series ||
      oldDelegate.minY != minY ||
      oldDelegate.maxY != maxY;
}

/// Inline trend line without axes, used inside tiles and list rows.
class AvSparkline extends StatelessWidget {
  const AvSparkline({
    super.key,
    required this.values,
    this.color = AvColors.flare,
    this.height = 34,
    this.fill = true,
    this.showLastPoint = true,
  });

  final List<double> values;
  final Color color;
  final double height;
  final bool fill;
  final bool showLastPoint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _SparklinePainter(
          values: values,
          color: color,
          fill: fill,
          showLastPoint: showLastPoint,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({
    required this.values,
    required this.color,
    required this.fill,
    required this.showLastPoint,
  });

  final List<double> values;
  final Color color;
  final bool fill;
  final bool showLastPoint;

  @override
  void paint(Canvas canvas, Size size) {
    final clean = values.where((v) => !v.isNaN).toList(growable: false);
    if (clean.length < 2) return;
    final lo = clean.reduce(math.min);
    final hi = clean.reduce(math.max);
    final range = (hi - lo).abs() < 0.0001 ? 1.0 : hi - lo;
    final step = size.width / (values.length - 1);

    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v.isNaN) continue;
      points.add(
        Offset(
          step * i,
          size.height - ((v - lo) / range) * (size.height - 5) - 2.5,
        ),
      );
    }
    if (points.length < 2) return;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final midX = (points[i].dx + points[i + 1].dx) / 2;
      path.cubicTo(
        midX,
        points[i].dy,
        midX,
        points[i + 1].dy,
        points[i + 1].dx,
        points[i + 1].dy,
      );
    }

    if (fill) {
      final fillPath = Path.from(path)
        ..lineTo(points.last.dx, size.height)
        ..lineTo(points.first.dx, size.height)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.3),
              color.withValues(alpha: 0.0),
            ],
          ).createShader(Offset.zero & size),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = color,
    );

    if (showLastPoint) {
      canvas.drawCircle(points.last, 4.4, Paint()..color = Colors.white);
      canvas.drawCircle(points.last, 3, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}
