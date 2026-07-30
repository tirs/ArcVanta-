import 'package:flutter/material.dart';

import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/session.dart';
import '../../design/components/av_indicators.dart';
import '../../design/components/av_surface.dart';

/// Summary row for a completed session. Used on the dashboard, in history and
/// in the coach review queue.
class SessionCard extends StatelessWidget {
  const SessionCard({
    super.key,
    required this.session,
    required this.onTap,
    this.showAthlete,
  });

  final TrainingSession session;
  final VoidCallback onTap;
  final String? showAthlete;

  @override
  Widget build(BuildContext context) {
    final uncertain = session.uncertainCount;

    return AvCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showAthlete != null)
                      Text(
                        showAthlete!,
                        style: AvType.label.copyWith(color: AvColors.insight),
                      ),
                    Text(session.drillName, style: AvType.headingSmall.primary),
                    const SizedBox(height: 2),
                    Text(
                      '${Fmt.dateTime(session.startedAt)} \u00B7 '
                      '${Fmt.duration(session.duration)} \u00B7 '
                      '${session.calibration.courtProfile}',
                      style: AvType.caption.muted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AvSpace.xs),
              AvConfidenceBadge(
                level: session.calibration.level,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: AvSpace.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${session.makeCount}',
                        style: AvType.heroMetric.copyWith(
                          color: AvColors.textPrimary,
                          fontSize: 42,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          ' / ${session.attemptCount}',
                          style: AvType.headingMedium.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AvSpace.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Fmt.percent(session.percentage, decimals: 1),
                    style: AvType.metricLarge.copyWith(
                      color: AvColors.flare,
                      fontSize: 26,
                    ),
                  ),
                  Text('FIELD GOAL', style: AvType.overline.faint),
                ],
              ),
            ],
          ),
          const SizedBox(height: AvSpace.sm),
          AvOutcomeBar(
            made: session.makeCount,
            missed: session.missCount,
            uncertain: uncertain,
          ),
          const SizedBox(height: AvSpace.sm),
          Wrap(
            spacing: AvSpace.sm,
            runSpacing: 6,
            children: [
              _Meta(
                icon: Icons.local_fire_department_rounded,
                label: 'Best streak ${session.bestStreak}',
                color: AvColors.caution,
              ),
              _Meta(
                icon: Icons.auto_awesome_rounded,
                label: 'Swish ${session.swishRate.toStringAsFixed(0)}%',
                color: AvColors.made,
              ),
              _Meta(
                icon: Icons.accessibility_new_rounded,
                label:
                    'Mechanics ${session.averageMechanics.toStringAsFixed(0)}',
                color: AvColors.insight,
              ),
              if (uncertain > 0)
                _Meta(
                  icon: Icons.help_outline_rounded,
                  label: '$uncertain to confirm',
                  color: AvColors.caution,
                ),
              _Meta(
                icon: session.processedOnDevice
                    ? Icons.smartphone_rounded
                    : Icons.cloud_done_rounded,
                label: session.processedOnDevice ? 'On device' : 'Cloud review',
                color: AvColors.court,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label, style: AvType.caption.secondary),
      ],
    );
  }
}
