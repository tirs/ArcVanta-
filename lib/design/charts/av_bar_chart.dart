import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';

class BarDatum {
  const BarDatum({
    required this.label,
    required this.value,
    required this.color,
    this.secondaryValue,
    this.caption,
  });

  final String label;
  final double value;
  final Color color;

  /// Optional lighter portion drawn behind the main bar, used to show attempts
  /// behind makes.
  final double? secondaryValue;
  final String? caption;
}

/// Horizontal bar list used for zone breakdowns and drill comparisons.
class AvBarList extends StatelessWidget {
  const AvBarList({
    super.key,
    required this.data,
    this.maxValue,
    this.valueSuffix = '',
    this.barHeight = 10,
    this.showValues = true,
  });

  final List<BarDatum> data;
  final double? maxValue;
  final String valueSuffix;
  final double barHeight;
  final bool showValues;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final max = maxValue ??
        data
            .map((d) => math.max(d.value, d.secondaryValue ?? 0))
            .reduce(math.max);
    final safeMax = max <= 0 ? 1.0 : max;

    return Column(
      children: [
        for (var i = 0; i < data.length; i++) ...[
          if (i > 0) const SizedBox(height: AvSpace.sm),
          _Row(
            datum: data[i],
            max: safeMax,
            suffix: valueSuffix,
            barHeight: barHeight,
            showValue: showValues,
          ),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.datum,
    required this.max,
    required this.suffix,
    required this.barHeight,
    required this.showValue,
  });

  final BarDatum datum;
  final double max;
  final String suffix;
  final double barHeight;
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                datum.label,
                style: AvType.titleSmall.secondary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (datum.caption != null) ...[
              Text(datum.caption!, style: AvType.caption.faint),
              const SizedBox(width: AvSpace.xs),
            ],
            if (showValue)
              Text(
                '${datum.value.toStringAsFixed(datum.value % 1 == 0 ? 0 : 1)}$suffix',
                style: AvType.tabular(AvType.titleSmall).primary,
              ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return SizedBox(
              height: barHeight,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AvColors.canvasSunken,
                      borderRadius: AvRadius.pill,
                    ),
                  ),
                  if (datum.secondaryValue != null)
                    Container(
                      width: width * (datum.secondaryValue! / max).clamp(0, 1),
                      decoration: BoxDecoration(
                        color: datum.color.withValues(alpha: 0.2),
                        borderRadius: AvRadius.pill,
                      ),
                    ),
                  AnimatedContainer(
                    duration: AvMotion.slow,
                    curve: AvMotion.enter,
                    width: width * (datum.value / max).clamp(0, 1),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          datum.color.withValues(alpha: 0.75),
                          datum.color,
                        ],
                      ),
                      borderRadius: AvRadius.pill,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Vertical column chart used for training volume and distribution.
class AvColumnChart extends StatelessWidget {
  const AvColumnChart({
    super.key,
    required this.values,
    required this.labels,
    this.color = AvColors.court,
    this.highlightColor = AvColors.flare,
    this.highlightIndex,
    this.height = 130,
    this.valueSuffix = '',
  });

  final List<double> values;
  final List<String> labels;
  final Color color;
  final Color highlightColor;
  final int? highlightIndex;
  final double height;
  final String valueSuffix;

  @override
  Widget build(BuildContext context) {
    final max = values.isEmpty ? 1.0 : values.reduce(math.max);
    final safeMax = max <= 0 ? 1.0 : max;

    return Column(
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < values.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (values[i] > 0)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${values[i].toStringAsFixed(0)}$valueSuffix',
                              maxLines: 1,
                              style: AvType.tabular(AvType.overline).copyWith(
                                color: i == highlightIndex
                                    ? highlightColor
                                    : AvColors.textFaint,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: AvMotion.slow,
                          curve: AvMotion.enter,
                          height: math.max(
                            3,
                            (height - 28) * (values[i] / safeMax).clamp(0, 1),
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: i == highlightIndex
                                  ? [
                                      highlightColor,
                                      highlightColor.withValues(alpha: 0.55),
                                    ]
                                  : [
                                      color.withValues(alpha: 0.85),
                                      color.withValues(alpha: 0.32),
                                    ],
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                              bottom: Radius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AvType.overline.copyWith(
                    color: i == highlightIndex
                        ? highlightColor
                        : AvColors.textFaint,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Distribution histogram with a target band, used for release and entry angle.
class AvDistributionChart extends StatelessWidget {
  const AvDistributionChart({
    super.key,
    required this.buckets,
    required this.bucketLabels,
    required this.color,
    this.targetRange,
    this.height = 120,
    this.meanIndex,
  });

  final List<int> buckets;
  final List<String> bucketLabels;
  final Color color;
  final (int, int)? targetRange;
  final double height;
  final int? meanIndex;

  @override
  Widget build(BuildContext context) {
    final max = buckets.isEmpty ? 1 : buckets.reduce(math.max);
    final safeMax = max <= 0 ? 1 : max;

    return Column(
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < buckets.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (i == meanIndex)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: const BoxDecoration(
                              color: AvColors.ink,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Container(
                          height: math.max(
                            2,
                            (height - 18) * (buckets[i] / safeMax),
                          ),
                          decoration: BoxDecoration(
                            color: _inTarget(i)
                                ? color
                                : color.withValues(alpha: 0.28),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < bucketLabels.length; i++)
              Expanded(
                child: Text(
                  bucketLabels[i],
                  textAlign: TextAlign.center,
                  style: AvType.overline.copyWith(
                    color: _inTarget(i)
                        ? AvColors.textSecondary
                        : AvColors.textFaint,
                    letterSpacing: 0,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  bool _inTarget(int index) {
    final range = targetRange;
    if (range == null) return true;
    return index >= range.$1 && index <= range.$2;
  }
}
