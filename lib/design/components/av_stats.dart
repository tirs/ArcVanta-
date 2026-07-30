import 'package:flutter/material.dart';

import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../data/models/confidence.dart';
import '../../data/models/shot.dart';
import 'av_indicators.dart';
import 'av_surface.dart';

/// Compact metric tile for grids and scoreboards.
class AvStatTile extends StatelessWidget {
  const AvStatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.caption,
    this.accent = AvColors.ink,
    this.delta,
    this.deltaInverted = false,
    this.icon,
    this.onTap,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final String? unit;
  final String? caption;
  final Color accent;
  final double? delta;
  final bool deltaInverted;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return AvCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AvSpace.md),
      color: emphasis ? accent.withValues(alpha: 0.07) : AvColors.surface,
      border: Border.all(
        color: emphasis ? accent.withValues(alpha: 0.28) : AvColors.hairline,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: accent),
                const SizedBox(width: 5),
              ],
              Expanded(
                child: Text(
                  label,
                  style: AvType.label.muted,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: AvType.metricLarge.copyWith(color: accent),
                  ),
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 3),
                Text(
                  unit!,
                  style: AvType.titleSmall.copyWith(
                    color: accent.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
          if (delta != null)
            AvDelta(value: delta!, inverted: deltaInverted)
          else if (caption != null)
            Text(
              caption!,
              style: AvType.caption.faint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}

/// Scoreboard figure used on ink panels.
class AvInkStat extends StatelessWidget {
  const AvInkStat({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.accent = AvColors.textOnInk,
    this.alignment = CrossAxisAlignment.start,
  });

  final String label;
  final String value;
  final String? unit;
  final Color accent;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AvType.overline.onInkMuted,
        ),
        const SizedBox(height: 6),
        // The figure is the point of this component, so it scales rather than
        // truncating when the row it sits in runs out of width.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment == CrossAxisAlignment.end
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: AvType.metricLarge.copyWith(color: accent)),
              if (unit != null) ...[
                const SizedBox(width: 2),
                Text(
                  unit!,
                  style: AvType.titleMedium.copyWith(
                    color: accent.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Full metric row with confidence, target band and personal baseline.
class AvMetricRow extends StatelessWidget {
  const AvMetricRow({
    super.key,
    required this.metric,
    required this.angle,
    this.onTap,
  });

  final MetricValue metric;
  final CameraAngle angle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final eligible = metric.eligibleFor(angle);
    final unavailable =
        !eligible || metric.confidence == ConfidenceLevel.unavailable;

    return AvPressable(
      onTap: onTap,
      borderRadius: AvRadius.allSm,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AvSpace.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(metric.label, style: AvType.titleSmall.primary),
                ),
                const SizedBox(width: AvSpace.xs),
                if (unavailable)
                  const AvPill(
                    label: 'Not eligible',
                    color: AvColors.unavailable,
                    icon: Icons.visibility_off_rounded,
                    dense: true,
                  )
                else
                  Text(
                    metric.formatted,
                    style: AvType.tabular(AvType.metricMedium).copyWith(
                      fontSize: 17,
                      color: metric.inTarget
                          ? AvColors.textPrimary
                          : AvColors.caution,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (unavailable)
              Text(
                eligible
                    ? metric.confidence.explanation
                    : '${angle.label} placement cannot measure this. Use '
                          '${metric.eligibleAngles.map((a) => a.label.toLowerCase()).join(' or ')} placement.',
                style: AvType.caption.faint,
              )
            else ...[
              _TargetBand(metric: metric),
              const SizedBox(height: 6),
              Row(
                children: [
                  AvConfidenceBadge(level: metric.confidence, compact: true),
                  const SizedBox(width: AvSpace.xs),
                  if (metric.deltaFromBaseline != null)
                    AvDelta(
                      value: metric.deltaFromBaseline!,
                      unit: metric.unit,
                      showBackground: false,
                    ),
                  const Spacer(),
                  if (metric.targetLow != null && metric.targetHigh != null)
                    Text(
                      'Target ${metric.targetLow!.toStringAsFixed(0)}'
                      '\u2013${metric.targetHigh!.toStringAsFixed(0)}${metric.unit}',
                      style: AvType.caption.faint,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TargetBand extends StatelessWidget {
  const _TargetBand({required this.metric});

  final MetricValue metric;

  @override
  Widget build(BuildContext context) {
    final low = metric.targetLow;
    final high = metric.targetHigh;
    if (low == null || high == null) {
      return const SizedBox.shrink();
    }

    final span = (high - low);
    final min = low - span * 0.9;
    final max = high + span * 0.9;
    double pos(double v) => ((v - min) / (max - min)).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: 14,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: AvColors.canvasSunken,
                  borderRadius: AvRadius.pill,
                ),
              ),
              Positioned(
                left: width * pos(low),
                width: width * (pos(high) - pos(low)),
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: AvColors.madeSoft,
                    borderRadius: AvRadius.pill,
                    border: Border.all(
                      color: AvColors.made.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ),
              if (metric.personalBaseline != null)
                Positioned(
                  left: (width * pos(metric.personalBaseline!) - 1).clamp(
                    0.0,
                    width - 2,
                  ),
                  child: Container(
                    width: 2,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AvColors.insight.withValues(alpha: 0.65),
                      borderRadius: AvRadius.pill,
                    ),
                  ),
                ),
              Positioned(
                left: (width * pos(metric.value) - 6).clamp(0.0, width - 12),
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: metric.inTarget ? AvColors.made : AvColors.caution,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: AvShadow.level1,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Shot outcome chip used in timelines and lists.
class AvResultChip extends StatelessWidget {
  const AvResultChip({
    super.key,
    required this.result,
    this.detail,
    this.corrected = false,
  });

  final ShotResult result;
  final ShotOutcomeDetail? detail;
  final bool corrected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: result.softColor,
        borderRadius: AvRadius.pill,
        border: Border.all(color: result.color.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(result.icon, size: 13, color: result.color),
          const SizedBox(width: 4),
          Text(
            detail == null || detail == ShotOutcomeDetail.undetermined
                ? result.label
                : detail!.label,
            style: AvType.label.copyWith(color: result.color),
          ),
          if (corrected) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.edit_rounded,
              size: 11,
              color: result.color.withValues(alpha: 0.7),
            ),
          ],
        ],
      ),
    );
  }
}
