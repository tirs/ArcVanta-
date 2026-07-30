import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/program.dart';
import '../../design/components/av_button.dart';
import '../../design/components/av_indicators.dart';
import '../../design/components/av_layout.dart';
import '../../design/components/av_surface.dart';
import '../../state/stores.dart';

/// The week ahead. The plan states why it was built this way and what it is
/// trying to move, so it reads as coaching rather than a generated schedule.
class TrainingPlanScreen extends ConsumerStatefulWidget {
  const TrainingPlanScreen({super.key});

  @override
  ConsumerState<TrainingPlanScreen> createState() =>
      _TrainingPlanScreenState();
}

class _TrainingPlanScreenState extends ConsumerState<TrainingPlanScreen> {
  int _selectedDay = 0;

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(trainingPlanProvider);
    final drills = ref.watch(drillStoreProvider);
    final day = plan.days[_selectedDay.clamp(0, plan.days.length - 1)];
    final textScale =
        MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);

    return AvScaffold(
      title: 'Training plan',
      subtitle: plan.name,
      leading: const AvBackButton(),
      actions: [
        AvIconButton(
          icon: Icons.flag_rounded,
          tooltip: 'Goals',
          onPressed: () => context.push(AppRoute.goals),
        ),
      ],
      slivers: [
        SliverGutter(child: _PlanHeader(plan: plan)),
        SliverGutter(
          top: AvSpace.md,
          child: SizedBox(
            height: 92 * textScale,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: plan.days.length,
              separatorBuilder: (_, __) => const SizedBox(width: AvSpace.xs),
              itemBuilder: (context, index) => _DayPip(
                day: plan.days[index],
                selected: index == _selectedDay,
                onTap: () => setState(() => _selectedDay = index),
              ),
            ),
          ),
        ),
        SliverGutter(
          top: AvSpace.md,
          child: AvCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AvSpace.xs,
                  runSpacing: AvSpace.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AvPill(
                      label: day.kind.label,
                      color: switch (day.kind) {
                        PlanDayKind.session => AvColors.flare,
                        PlanDayKind.recovery => AvColors.court,
                        PlanDayKind.rest => AvColors.unavailable,
                      },
                      dense: true,
                    ),
                    Text(
                      Fmt.weekday(day.date),
                      style: AvType.caption.faint,
                    ),
                    if (day.completed)
                      const AvPill(
                        label: 'Done',
                        color: AvColors.made,
                        icon: Icons.check_rounded,
                        dense: true,
                      )
                    else if (day.kind != PlanDayKind.rest)
                      Text(
                        '${day.estimatedMinutes} min',
                        style: AvType.tabular(AvType.caption).muted,
                      ),
                  ],
                ),
                const SizedBox(height: AvSpace.sm),
                Text(day.title, style: AvType.headingSmall.primary),
                const SizedBox(height: 4),
                Text(day.focus, style: AvType.bodySmall.muted),
                if (day.drillIds.isNotEmpty) ...[
                  const SizedBox(height: AvSpace.md),
                  const AvSeparator(),
                  const SizedBox(height: AvSpace.sm),
                  for (final drillId in day.drillIds)
                    Builder(
                      builder: (context) {
                        final drill = drills.firstWhere(
                          (d) => d.id == drillId,
                          orElse: () => drills.first,
                        );
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AvSpace.xs),
                          child: Row(
                            children: [
                              AvGlyph(
                                icon: drill.category.icon,
                                color: drill.category.color,
                                background:
                                    drill.category.color.withValues(alpha: 0.12),
                                size: 34,
                              ),
                              const SizedBox(width: AvSpace.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      drill.name,
                                      style: AvType.titleSmall.primary,
                                    ),
                                    Text(
                                      '${drill.targetMakes} makes \u00B7 '
                                      '${drill.estimatedMinutes} min',
                                      style: AvType.caption.faint,
                                    ),
                                  ],
                                ),
                              ),
                              AvButton(
                                label: 'Start',
                                size: AvButtonSize.small,
                                onPressed: () => context.push(
                                  AppRoute.placement(drill.id),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
                if (day.kind == PlanDayKind.rest) ...[
                  const SizedBox(height: AvSpace.md),
                  AvTintCard(
                    tint: AvColors.canvasSunken,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.bedtime_rounded,
                          size: 18,
                          color: AvColors.textMuted,
                        ),
                        const SizedBox(width: AvSpace.sm),
                        Expanded(
                          child: Text(
                            'Rest is part of the plan. Shooting volume '
                            'without recovery is where form breaks down.',
                            style: AvType.caption.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SliverGutter(
          top: AvSpace.lg,
          child: AvSectionHeader(
            title: 'Why this plan',
            accent: AvColors.insight,
            padding: EdgeInsets.only(bottom: AvSpace.sm),
          ),
        ),
        SliverGutter(
          child: AvTintCard(
            tint: AvColors.insightTint,
            borderColor: AvColors.insightSoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const AvGlyph(
                      icon: Icons.auto_awesome_rounded,
                      color: AvColors.insightDeep,
                      background: AvColors.insightSoft,
                      size: 34,
                    ),
                    const SizedBox(width: AvSpace.sm),
                    Expanded(
                      child: Text(
                        'Built by ${plan.authoredBy}',
                        style: AvType.titleSmall.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AvSpace.sm),
                Text(plan.rationale, style: AvType.bodySmall.muted),
              ],
            ),
          ),
        ),
        SliverGutter(
          top: AvSpace.sm,
          child: AvCard(
            child: Column(
              children: [
                AvKeyValue(
                  label: 'Target metric',
                  value: plan.targetMetric,
                ),
                AvKeyValue(
                  label: 'Now',
                  value: plan.currentValue.toStringAsFixed(1),
                ),
                AvKeyValue(
                  label: 'Goal for this block',
                  value: plan.targetValue.toStringAsFixed(1),
                ),
                const SizedBox(height: AvSpace.sm),
                AvMeter(
                  value: (plan.currentValue / plan.targetValue).clamp(0, 1),
                  color: AvColors.insight,
                  showMarker: true,
                  markerAt: 1,
                ),
              ],
            ),
          ),
        ),
        SliverGutter(
          top: AvSpace.lg,
          child: AvButton(
            label: 'Regenerate next week',
            variant: AvButtonVariant.outline,
            icon: Icons.refresh_rounded,
            expand: true,
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Next week rebuilds automatically once this block finishes',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanHeader extends StatelessWidget {
  const _PlanHeader({required this.plan});

  final TrainingPlan plan;

  @override
  Widget build(BuildContext context) {
    return AvInkCard(
      padding: const EdgeInsets.all(AvSpace.lg),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WEEK OF ${Fmt.date(plan.weekStart).toUpperCase()}',
                  style:
                      AvType.overline.copyWith(color: AvColors.textOnInkMuted),
                ),
                const SizedBox(height: AvSpace.xs),
                Text(
                  plan.name,
                  style: AvType.headingMedium
                      .copyWith(color: AvColors.textOnInk),
                ),
                const SizedBox(height: AvSpace.xs),
                Text(
                  '${plan.completedDays} of ${plan.sessionDays} sessions done',
                  style: AvType.caption
                      .copyWith(color: AvColors.textOnInkMuted),
                ),
              ],
            ),
          ),
          AvProgressRing(
            value: plan.progress,
            size: 66,
            strokeWidth: 7,
            color: AvColors.flare,
            trackColor: AvColors.hairlineOnInk,
            child: Text(
              '${(plan.progress * 100).round()}%',
              style: AvType.tabular(AvType.metricSmall)
                  .copyWith(color: AvColors.textOnInk),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayPip extends StatelessWidget {
  const _DayPip({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final PlanDay day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = switch (day.kind) {
      PlanDayKind.session => AvColors.flare,
      PlanDayKind.recovery => AvColors.court,
      PlanDayKind.rest => AvColors.unavailable,
    };

    return AvPressable(
      onTap: onTap,
      borderRadius: AvRadius.allMd,
      child: AnimatedContainer(
        duration: AvMotion.fast,
        width: 66 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0),
        padding: const EdgeInsets.symmetric(vertical: AvSpace.sm),
        decoration: BoxDecoration(
          color: selected ? AvColors.ink : AvColors.surface,
          borderRadius: AvRadius.allMd,
          border: Border.all(
            color: selected ? AvColors.ink : AvColors.hairline,
          ),
          boxShadow: selected ? AvShadow.level2 : AvShadow.level1,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              Fmt.weekdayShort(day.date).toUpperCase(),
              style: AvType.overline.copyWith(
                fontSize: 9,
                color:
                    selected ? AvColors.textOnInkMuted : AvColors.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${day.date.day}',
              style: AvType.tabular(AvType.metricMedium).copyWith(
                fontSize: 19,
                color: selected ? AvColors.textOnInk : AvColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 18,
              height: 3,
              decoration: BoxDecoration(
                color: day.completed ? AvColors.made : accent,
                borderRadius: AvRadius.pill,
              ),
            ),
            const SizedBox(height: 4),
            Icon(
              day.completed
                  ? Icons.check_circle_rounded
                  : switch (day.kind) {
                      PlanDayKind.session => Icons.sports_basketball_rounded,
                      PlanDayKind.recovery => Icons.self_improvement_rounded,
                      PlanDayKind.rest => Icons.bedtime_rounded,
                    },
              size: 13,
              color: day.completed
                  ? AvColors.made
                  : (selected ? AvColors.textOnInkMuted : AvColors.textFaint),
            ),
          ],
        ),
      ),
    );
  }
}
