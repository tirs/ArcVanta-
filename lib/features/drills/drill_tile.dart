import 'package:flutter/material.dart';

import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../data/models/drill.dart';
import '../../design/components/av_indicators.dart';
import '../../design/components/av_surface.dart';

class DrillTile extends StatelessWidget {
  const DrillTile({
    super.key,
    required this.drill,
    required this.onTap,
    this.onStart,
  });

  final Drill drill;
  final VoidCallback onTap;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final accent = drill.category.color;

    return AvCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      clip: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: accent, width: 4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AvSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AvGlyph(
                    icon: drill.category.icon,
                    color: accent,
                    size: 34,
                    shape: BoxShape.rectangle,
                  ),
                  const SizedBox(width: AvSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(drill.name, style: AvType.headingSmall.primary),
                        Text(
                          '${drill.category.label} \u00B7 ${drill.difficulty.label}',
                          style: AvType.overline.faint,
                        ),
                      ],
                    ),
                  ),
                  if (drill.isCustom)
                    const AvPill(
                      label: 'Custom',
                      color: AvColors.insight,
                      dense: true,
                    ),
                ],
              ),
              const SizedBox(height: AvSpace.sm),
              Text(
                drill.summary,
                style: AvType.bodySmall.secondary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AvSpace.sm),
              Wrap(
                spacing: AvSpace.sm,
                runSpacing: 6,
                children: [
                  _Meta(
                    icon: Icons.schedule_rounded,
                    label: '${drill.estimatedMinutes} min',
                  ),
                  _Meta(
                    icon: Icons.adjust_rounded,
                    label: 'Goal ${drill.targetMakes}/${drill.targetAttempts}',
                  ),
                  _Meta(
                    icon: drill.recommendedAngle.icon,
                    label: drill.recommendedAngle.label,
                  ),
                  _Meta(
                    icon: Icons.place_rounded,
                    label: drill.zones.length == 1
                        ? '1 spot'
                        : '${drill.zones.length} spots',
                  ),
                ],
              ),
              if (onStart != null) ...[
                const SizedBox(height: AvSpace.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Focus: ${drill.coachingFocus}',
                        style: AvType.caption.copyWith(color: accent),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AvPressable(
                      onTap: onStart,
                      borderRadius: AvRadius.pill,
                      semanticLabel: 'Start ${drill.name}',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: AvRadius.pill,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_arrow_rounded,
                              size: 16,
                              color: accent,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Start',
                              style: AvType.label.copyWith(color: accent),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AvColors.textFaint),
        const SizedBox(width: 4),
        Text(label, style: AvType.caption.muted),
      ],
    );
  }
}
