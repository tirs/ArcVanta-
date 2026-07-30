import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/program.dart';
import '../../data/models/progress.dart';
import '../../data/seed/seed_data.dart';
import '../../design/charts/av_court_map.dart';
import '../../design/charts/av_line_chart.dart';
import '../../design/components/av_brand.dart';
import '../../design/components/av_button.dart';
import '../../design/components/av_indicators.dart';
import '../../design/components/av_layout.dart';
import '../../design/components/av_surface.dart';
import '../../state/stores.dart';
import '../shared/coaching_cue_card.dart';
import '../shared/session_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(playerProfileProvider);
    final sessions = ref.watch(sessionStoreProvider);
    final plan = ref.watch(trainingPlanProvider);
    final goals = ref.watch(goalStoreProvider);
    final assignments = ref.watch(assignmentStoreProvider);
    final unread = ref.watch(unreadNotificationCountProvider);
    final week = ref.watch(progressProvider(TrendRange.week));

    final latest = sessions.first;
    final today = _todayPlanDay(plan);
    final myAssignments = assignments
        .where((a) => a.athleteId == profile.id)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: AvColors.canvas,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AvSpace.gutter,
                  AvSpace.md,
                  AvSpace.gutter,
                  AvSpace.md,
                ),
                child: Row(
                  children: [
                    AvAvatar(
                      initials: profile.initials,
                      color: profile.accentColor,
                      size: 46,
                    ),
                    const SizedBox(width: AvSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_greeting(), style: AvType.caption.muted),
                          Text(
                            profile.displayName,
                            style: AvType.headingMedium.primary,
                          ),
                        ],
                      ),
                    ),
                    AvIconButton(
                      icon: Icons.notifications_none_rounded,
                      tooltip: 'Notifications',
                      badgeCount: unread,
                      onPressed: () => context.push(AppRoute.notifications),
                    ),
                  ],
                ),
              ),
            ),
            SliverGutter(child: _StartCard(planDay: today)),
            SliverGutter(
              top: AvSpace.md,
              child: _WeekStrip(points: week),
            ),
            if (latest.primaryCue != null)
              SliverGutter(
                top: AvSpace.md,
                child: CoachingCueCard(
                  cue: latest.primaryCue!,
                  onDrillTap: (drillId) =>
                      context.push(AppRoute.drill(drillId)),
                ),
              ),
            SliverToBoxAdapter(
              child: AvSectionHeader(
                title: 'Last session',
                subtitle:
                    '${latest.drillName} \u00B7 ${Fmt.relative(latest.startedAt, now: SeedData.today.add(const Duration(hours: 11)))}',
                accent: AvColors.flare,
                action: AvTextAction(
                  label: 'All sessions',
                  onPressed: () => context.push(AppRoute.sessions),
                ),
              ),
            ),
            SliverGutter(
              child: SessionCard(
                session: latest,
                onTap: () => context.push(AppRoute.session(latest.id)),
              ),
            ),
            SliverToBoxAdapter(
              child: AvSectionHeader(
                title: 'Where the shots fell',
                subtitle: 'Zone accuracy from your last session',
                accent: AvColors.court,
                action: AvTextAction(
                  label: 'Full chart',
                  onPressed: () => context.push(AppRoute.heatmap),
                ),
              ),
            ),
            SliverGutter(
              child: AvCard(
                child: Column(
                  children: [
                    AvCourtMap(
                      zones: latest.zoneBreakdown,
                      onZoneTap: (_) => context.push(AppRoute.heatmap),
                    ),
                    const SizedBox(height: AvSpace.sm),
                    const AvCourtLegend(),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: AvSectionHeader(
                title: 'Goals',
                subtitle:
                    '${goals.where((g) => g.achieved).length} of ${goals.length} reached',
                accent: AvColors.insight,
                action: AvTextAction(
                  label: 'Manage',
                  onPressed: () => context.push(AppRoute.goals),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: AvCarousel(
                height: 148,
                children: [
                  for (final goal in goals)
                    SizedBox(width: 224, child: _GoalCard(goal: goal)),
                ],
              ),
            ),
            if (myAssignments.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: AvSectionHeader(
                  title: 'From your coach',
                  subtitle: profile.coachName,
                  accent: AvColors.made,
                ),
              ),
              SliverGutter(
                child: Column(
                  children: [
                    for (final assignment in myAssignments)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AvSpace.sm),
                        child: _AssignmentCard(
                          assignment: assignment,
                          onTap: () =>
                              context.push(AppRoute.drill(assignment.drillId)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: AvSectionHeader(
                title: 'Quick access',
                accent: AvColors.caution,
              ),
            ),
            SliverGutter(
              bottom: AvSpace.xxl,
              child: AvTileGrid(
                aspectRatio: 1.85,
                children: [
                  _QuickTile(
                    label: 'Training plan',
                    icon: Icons.event_note_rounded,
                    color: AvColors.insight,
                    onTap: () => context.push(AppRoute.plan),
                  ),
                  _QuickTile(
                    label: 'Highlights',
                    icon: Icons.movie_creation_outlined,
                    color: AvColors.flare,
                    onTap: () => context.push(AppRoute.highlights),
                  ),
                  _QuickTile(
                    label: 'Shot chart',
                    icon: Icons.grid_on_rounded,
                    color: AvColors.court,
                    onTap: () => context.push(AppRoute.heatmap),
                  ),
                  _QuickTile(
                    label: 'Subscription',
                    icon: Icons.workspace_premium_outlined,
                    color: AvColors.made,
                    onTap: () => context.push(AppRoute.subscription),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.paddingOf(context).bottom + 96,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static PlanDay? _todayPlanDay(TrainingPlan plan) {
    for (final day in plan.days) {
      if (!day.completed && day.kind != PlanDayKind.rest) return day;
    }
    return plan.days.isEmpty ? null : plan.days.last;
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }
}

class _StartCard extends ConsumerWidget {
  const _StartCard({required this.planDay});

  final PlanDay? planDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drills = ref.watch(drillStoreProvider);
    final scheduled = planDay == null || planDay!.drillIds.isEmpty
        ? drills.first
        : drills.firstWhere(
            (d) => d.id == planDay!.drillIds.first,
            orElse: () => drills.first,
          );

    return AvInkCard(
      padding: const EdgeInsets.all(AvSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AvColors.flare.withValues(alpha: 0.18),
                    borderRadius: AvRadius.pill,
                  ),
                  child: Text(
                    planDay == null
                        ? 'READY WHEN YOU ARE'
                        : 'NEXT IN YOUR PLAN',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AvType.overline.copyWith(color: AvColors.flare),
                  ),
                ),
              ),
              const SizedBox(width: AvSpace.sm),
              Text(
                '${scheduled.estimatedMinutes} min',
                style: AvType.label.onInkMuted,
              ),
            ],
          ),
          const SizedBox(height: AvSpace.md),
          Text(
            planDay?.title ?? 'Quick Session',
            style: AvType.displayMedium.onInk,
          ),
          const SizedBox(height: 6),
          Text(
            planDay?.focus ?? scheduled.coachingFocus,
            style: AvType.bodySmall.onInkMuted,
          ),
          const SizedBox(height: AvSpace.lg),
          Row(
            children: [
              _StartMeta(
                icon: Icons.sports_basketball_rounded,
                label: scheduled.name,
              ),
              const SizedBox(width: AvSpace.md),
              _StartMeta(
                icon: scheduled.recommendedAngle.icon,
                label: '${scheduled.recommendedAngle.label} placement',
              ),
            ],
          ),
          const SizedBox(height: AvSpace.lg),
          Row(
            children: [
              Expanded(
                child: AvButton(
                  label: 'Start session',
                  icon: Icons.play_arrow_rounded,
                  size: AvButtonSize.large,
                  expand: true,
                  onPressed: () =>
                      context.push(AppRoute.placement(scheduled.id)),
                ),
              ),
              const SizedBox(width: AvSpace.sm),
              AvIconButton(
                icon: Icons.tune_rounded,
                tooltip: 'Choose a different drill',
                size: 56,
                background: Colors.white.withValues(alpha: 0.10),
                borderColor: Colors.white.withValues(alpha: 0.16),
                color: Colors.white,
                onPressed: () => context.go(AppRoute.train),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StartMeta extends StatelessWidget {
  const _StartMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AvColors.textOnInkMuted),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: AvType.caption.onInkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.points});

  final List<ProgressPoint> points;

  @override
  Widget build(BuildContext context) {
    final attempts = points.fold<int>(0, (sum, p) => sum + p.attempts);
    final makes = points.fold<int>(0, (sum, p) => sum + p.makes);
    final sessions = points.where((p) => p.trained).length;
    final percentage = attempts == 0 ? 0.0 : makes / attempts * 100;
    final mechanics = points.where((p) => p.trained).toList();
    final mechanicsAvg = mechanics.isEmpty
        ? 0.0
        : mechanics.map((p) => p.mechanicsScore).reduce((a, b) => a + b) /
              mechanics.length;

    return AvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'This week',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AvType.titleMedium.primary,
                ),
              ),
              const SizedBox(width: AvSpace.xs),
              Text('$sessions sessions', style: AvType.caption.faint),
            ],
          ),
          const SizedBox(height: AvSpace.sm),
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  label: 'Makes',
                  value: '$makes',
                  accent: AvColors.made,
                ),
              ),
              _Divider(),
              Expanded(
                child: _MiniMetric(
                  label: 'Attempts',
                  value: '$attempts',
                  accent: AvColors.court,
                ),
              ),
              _Divider(),
              Expanded(
                child: _MiniMetric(
                  label: 'Accuracy',
                  value: percentage.toStringAsFixed(0),
                  unit: '%',
                  accent: AvColors.flare,
                ),
              ),
              _Divider(),
              Expanded(
                child: _MiniMetric(
                  label: 'Mechanics',
                  value: mechanicsAvg.toStringAsFixed(0),
                  accent: AvColors.insight,
                ),
              ),
            ],
          ),
          const SizedBox(height: AvSpace.md),
          AvSparkline(
            values: points
                .map((p) => p.trained ? p.percentage : double.nan)
                .toList(growable: false),
            color: AvColors.flare,
            height: 40,
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: AvColors.hairline,
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.accent,
    this.unit,
  });

  final String label;
  final String value;
  final String? unit;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  style: AvType.metricMedium.copyWith(color: accent),
                ),
              ),
            ),
            if (unit != null)
              Text(
                unit!,
                style: AvType.label.copyWith(
                  color: accent.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AvType.overline.faint,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    return AvCard(
      onTap: () => context.push(AppRoute.goals),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              AvGlyph(icon: goal.kind.icon, color: goal.kind.color, size: 30),
              const Spacer(),
              if (goal.achieved)
                const AvPill(
                  label: 'Reached',
                  color: AvColors.made,
                  icon: Icons.check_rounded,
                  dense: true,
                ),
            ],
          ),
          Text(
            goal.title,
            style: AvType.titleSmall.primary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${goal.current.toStringAsFixed(goal.current % 1 == 0 ? 0 : 1)}${goal.unit}',
                    style: AvType.metricMedium.copyWith(color: goal.kind.color),
                  ),
                  Text(
                    '  of ${goal.target.toStringAsFixed(goal.target % 1 == 0 ? 0 : 1)}${goal.unit}',
                    style: AvType.caption.faint,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              AvMeter(value: goal.progress, color: goal.kind.color, height: 6),
            ],
          ),
        ],
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({required this.assignment, required this.onTap});

  final Assignment assignment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AvCard(
      onTap: onTap,
      child: Row(
        children: [
          AvProgressRing(
            value: assignment.progress,
            size: 46,
            strokeWidth: 5,
            color: assignment.status.color,
            child: Text(
              '${(assignment.progress * 100).round()}',
              style: AvType.tabular(AvType.label).primary,
            ),
          ),
          const SizedBox(width: AvSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        assignment.drillName,
                        style: AvType.titleMedium.primary,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    AvPill(
                      label: assignment.status.label,
                      color: assignment.status.color,
                      dense: true,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${assignment.completedMakes} of ${assignment.targetMakes} makes \u00B7 due '
                  '${Fmt.relative(assignment.dueAt, now: SeedData.today)}',
                  style: AvType.caption.muted,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AvColors.textFaint),
        ],
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AvCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AvSpace.sm),
      child: Row(
        children: [
          AvGlyph(icon: icon, color: color, size: 36),
          const SizedBox(width: AvSpace.xs),
          Expanded(
            child: Text(
              label,
              style: AvType.titleSmall.primary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
