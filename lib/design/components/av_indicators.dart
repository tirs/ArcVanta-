import 'package:flutter/material.dart';

import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../data/models/confidence.dart';
import 'av_surface.dart';

/// Confidence indicator. Level is carried by glyph, text and colour together so
/// the state survives colour-blind and high-contrast conditions.
class AvConfidenceBadge extends StatelessWidget {
  const AvConfidenceBadge({
    super.key,
    required this.level,
    this.compact = false,
    this.onInk = false,
    this.onTap,
  });

  final ConfidenceLevel level;
  final bool compact;
  final bool onInk;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = onInk ? _onInkColor(level) : level.color;
    final background = onInk
        ? Colors.white.withValues(alpha: 0.12)
        : level.softColor;

    final content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AvRadius.pill,
        border: Border.all(color: foreground.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(level.icon, size: compact ? 11 : 13, color: foreground),
          const SizedBox(width: 4),
          Text(
            compact ? level.shortLabel : level.label,
            style: (compact ? AvType.overline : AvType.label)
                .copyWith(color: foreground, letterSpacing: compact ? 0.6 : 0),
          ),
        ],
      ),
    );

    return Semantics(
      label: 'Reliability: ${level.label}',
      child: onTap == null
          ? content
          : AvPressable(
              onTap: onTap,
              borderRadius: AvRadius.pill,
              child: content,
            ),
    );
  }

  static Color _onInkColor(ConfidenceLevel level) => switch (level) {
        ConfidenceLevel.high => const Color(0xFF5FE3AE),
        ConfidenceLevel.medium => const Color(0xFFFFC861),
        ConfidenceLevel.low => const Color(0xFFFF8FA3),
        ConfidenceLevel.unavailable => const Color(0xFFB8B6CC),
      };
}

/// Small status label used for assignment state, plan tier and similar.
class AvPill extends StatelessWidget {
  const AvPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.filled = false,
    this.dense = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool filled;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : color;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.11),
        borderRadius: AvRadius.pill,
        border: filled
            ? null
            : Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (dense ? AvType.overline : AvType.label).copyWith(
                color: fg,
                letterSpacing: dense ? 0.5 : 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Signed change indicator with an arrow. `inverted` flips the colour meaning
/// for metrics where a lower value is better.
class AvDelta extends StatelessWidget {
  const AvDelta({
    super.key,
    required this.value,
    this.unit = '',
    this.inverted = false,
    this.onInk = false,
    this.showBackground = true,
  });

  final double value;
  final String unit;
  final bool inverted;
  final bool onInk;
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    final flat = value.abs() < 0.05;
    final good = inverted ? value < 0 : value > 0;
    final color = flat
        ? (onInk ? AvColors.textOnInkMuted : AvColors.textMuted)
        : (good ? AvColors.made : AvColors.miss);
    final icon = flat
        ? Icons.remove_rounded
        : (value > 0
            ? Icons.arrow_upward_rounded
            : Icons.arrow_downward_rounded);
    final text =
        '${value > 0 && !flat ? '+' : ''}${value.toStringAsFixed(1)}$unit';

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            flat ? 'No change' : text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AvType.tabular(AvType.label).copyWith(color: color),
          ),
        ),
      ],
    );

    if (!showBackground) return row;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: onInk ? 0.18 : 0.1),
        borderRadius: AvRadius.pill,
      ),
      child: row,
    );
  }
}

/// Selectable filter chip.
class AvChip extends StatelessWidget {
  const AvChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.accent = AvColors.insight,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color accent;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return AvPressable(
      onTap: onTap,
      borderRadius: AvRadius.pill,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: AvMotion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? accent : AvColors.surface,
          borderRadius: AvRadius.pill,
          border: Border.all(
            color: selected ? accent : AvColors.hairline,
            width: 1.2,
          ),
          boxShadow: selected ? AvShadow.glow(accent) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: selected ? Colors.white : AvColors.textMuted,
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AvType.titleSmall.copyWith(
                  color: selected ? Colors.white : AvColors.textSecondary,
                ),
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Text(
                '$count',
                style: AvType.tabular(AvType.label).copyWith(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.75)
                      : AvColors.textFaint,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Horizontal segmented control for two to four mutually exclusive options.
class AvSegmented<T> extends StatelessWidget {
  const AvSegmented({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.accent = AvColors.ink,
    this.dense = false,
  });

  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;
  final Color accent;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AvColors.canvasSunken,
        borderRadius: AvRadius.pill,
        border: Border.all(color: AvColors.hairline),
      ),
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: AvPressable(
                onTap: () => onChanged(values[i]),
                borderRadius: AvRadius.pill,
                scale: 1,
                semanticLabel: labels[i],
                child: AnimatedContainer(
                  duration: AvMotion.fast,
                  curve: AvMotion.enter,
                  padding: EdgeInsets.symmetric(vertical: dense ? 7 : 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: values[i] == selected
                        ? accent
                        : Colors.transparent,
                    borderRadius: AvRadius.pill,
                  ),
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AvType.titleSmall.copyWith(
                      color: values[i] == selected
                          ? Colors.white
                          : AvColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Linear meter used for goals, calibration quality and drill targets.
class AvMeter extends StatelessWidget {
  const AvMeter({
    super.key,
    required this.value,
    this.color = AvColors.flare,
    this.trackColor = AvColors.hairline,
    this.height = 8,
    this.showMarker = false,
    this.markerAt = 0,
  });

  final double value;
  final Color color;
  final Color trackColor;
  final double height;
  final bool showMarker;
  final double markerAt;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: height,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: trackColor,
                  borderRadius: AvRadius.pill,
                ),
              ),
              AnimatedContainer(
                duration: AvMotion.slow,
                curve: AvMotion.enter,
                width: width * value.clamp(0, 1),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.72), color],
                  ),
                  borderRadius: AvRadius.pill,
                ),
              ),
              if (showMarker)
                Positioned(
                  left: (width * markerAt.clamp(0, 1) - 1).clamp(0, width - 2),
                  child: Container(
                    width: 2,
                    height: height,
                    color: AvColors.ink.withValues(alpha: 0.55),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Stacked make/miss/uncertain bar used in summaries and roster rows.
class AvOutcomeBar extends StatelessWidget {
  const AvOutcomeBar({
    super.key,
    required this.made,
    required this.missed,
    required this.uncertain,
    this.height = 10,
  });

  final int made;
  final int missed;
  final int uncertain;
  final double height;

  @override
  Widget build(BuildContext context) {
    final total = made + missed + uncertain;
    if (total == 0) {
      return SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: AvColors.hairline,
            borderRadius: AvRadius.pill,
          ),
          child: const SizedBox.expand(),
        ),
      );
    }
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: AvRadius.pill,
        child: Row(
          children: [
            if (made > 0)
              Expanded(
                flex: made,
                child: const ColoredBox(color: AvColors.made),
              ),
            if (missed > 0)
              Expanded(
                flex: missed,
                child: const ColoredBox(color: AvColors.miss),
              ),
            if (uncertain > 0)
              Expanded(
                flex: uncertain,
                child: const ColoredBox(color: AvColors.caution),
              ),
          ],
        ),
      ),
    );
  }
}

/// Explains why a metric is hidden for the current camera placement.
class AvUnavailableNotice extends StatelessWidget {
  const AvUnavailableNotice({
    super.key,
    required this.metric,
    required this.reason,
  });

  final String metric;
  final String reason;

  @override
  Widget build(BuildContext context) {
    return AvHatch(
      color: AvColors.hairline,
      child: Container(
        padding: const EdgeInsets.all(AvSpace.md),
        decoration: BoxDecoration(
          color: AvColors.canvas.withValues(alpha: 0.86),
          borderRadius: AvRadius.allSm,
          border: Border.all(color: AvColors.hairlineStrong),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.visibility_off_rounded,
              size: 17,
              color: AvColors.unavailable,
            ),
            const SizedBox(width: AvSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(metric, style: AvType.titleSmall.secondary),
                  const SizedBox(height: 2),
                  Text(reason, style: AvType.caption.muted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
