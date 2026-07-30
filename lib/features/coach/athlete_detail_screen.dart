import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/profile.dart';
import '../../data/models/program.dart';
import '../../data/models/session.dart';
import '../../data/models/shot.dart';
import '../../design/charts/av_court_map.dart';
import '../../design/charts/av_line_chart.dart';
import '../../design/components/av_brand.dart';
import '../../design/components/av_button.dart';
import '../../design/components/av_indicators.dart';
import '../../design/components/av_layout.dart';
import '../../design/components/av_stats.dart';
import '../../design/components/av_surface.dart';
import '../../state/stores.dart';
import '../shared/session_card.dart';

/// Everything a coach needs on one athlete: trend, current work, open
/// assignments and the consent state that governs what the coach may see.
class AthleteDetailScreen extends ConsumerWidget {
  const AthleteDetailScreen({super.key, required this.athleteId});

  final String athleteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final athlete = ref.watch(athleteByIdProvider(athleteId));
    final assignments = ref
        .watch(assignmentStoreProvider)
        .where((a) => a.athleteId == athleteId)
        .toList(growable: false);
    final sessions = ref.watch(sessionStoreProvider).take(4).toList();

    final zones = <CourtZone, ZoneRecord>{};
    for (final session in sessions) {
      session.zoneBreakdown.forEach((zone, record) {
        final existing = zones[zone] ?? const ZoneRecord(0, 0);
        zones[zone] = ZoneRecord(
          existing.makes + record.makes,
          existing.attempts + record.attempts,
        );
      });
    }

    return AvScaffold(
      title: athlete.name,
      subtitle: '${athlete.position.label} \u00B7 ${athlete.ageBand}',
      leading: const AvBackButton(),
      actions: [
        AvIconButton(
          icon: Icons.chat_bubble_outline_rounded,
          tooltip: 'Message',
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Messaging opens with the team app')),
          ),
        ),
      ],
      bottomBar: AvBottomBar(
        children: [
          Expanded(
            child: AvButton(
              label: 'Review clips',
              variant: AvButtonVariant.outline,
              size: AvButtonSize.large,
              expand: true,
              onPressed: () => context.push(AppRoute.reviewQueue),
            ),
          ),
          Expanded(
            child: AvButton(
              label: 'Assign a drill',
              size: AvButtonSize.large,
              icon: Icons.add_task_rounded,
              expand: true,
              onPressed: () =>
                  context.push('${AppRoute.assign}?athlete=${athlete.id}'),
            ),
          ),
        ],
      ),
      slivers: [
        SliverGutter(child: _AthleteHeader(athlete: athlete)),
        if (!athlete.guardianApproved)
          SliverGutter(
            top: AvSpace.sm,
            child: AvTintCard(
              tint: AvColors.cautionSoft,
              borderColor: AvColors.caution,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AvGlyph(
                    icon: Icons.shield_outlined,
                    color: AvColors.cautionDeep,
                    background: AvColors.cautionSoft,
                    size: 36,
                  ),
                  const SizedBox(width: AvSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Guardian consent pending',
                          style: AvType.titleSmall.primary,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Until a guardian approves coach access you can see '
                          'totals only. Video, pose data and shot-level '
                          'measurements stay hidden.',
                          style: AvType.caption.muted,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        SliverGutter(
          top: AvSpace.sm,
          child: AvTileGrid(
            children: [
              AvStatTile(
                label: 'Accuracy',
                value: athlete.percentage.toStringAsFixed(0),
                unit: '%',
                caption: 'last thirty days',
                accent: AvColors.flare,
                delta: athlete.percentageDelta,
              ),
              AvStatTile(
                label: 'Mechanics',
                value: athlete.mechanicsScore.toStringAsFixed(0),
                unit: '/100',
                caption: 'session average',
                accent: AvColors.insight,
              ),
              AvStatTile(
                label: 'Sessions',
                value: '${athlete.sessionsThisWeek}',
                caption: 'this week',
                accent: AvColors.court,
              ),
              AvStatTile(
                label: 'Assignments',
                value:
                    '${athlete.assignmentsComplete}/${athlete.assignmentsTotal}',
                caption: 'complete',
                accent: AvColors.made,
              ),
            ],
          ),
        ),
        const SliverGutter(
          top: AvSpace.lg,
          child: AvSectionHeader(
            title: 'Current focus',
            padding: EdgeInsets.only(bottom: AvSpace.sm),
          ),
        ),
        SliverGutter(
          child: AvCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AvGlyph(
                  icon: Icons.center_focus_strong_rounded,
                  color: AvColors.court,
                  background: AvColors.courtSoft,
                  size: 38,
                ),
                const SizedBox(width: AvSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        athlete.focusArea,
                        style: AvType.titleMedium.primary,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Set from the last three sessions of measured work. '
                        'Updates automatically as the pattern changes.',
                        style: AvType.caption.muted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (athlete.guardianApproved) ...[
          const SliverGutter(
            top: AvSpace.lg,
            child: AvSectionHeader(
              title: 'Accuracy trend',
              accent: AvColors.flare,
              padding: EdgeInsets.only(bottom: AvSpace.sm),
            ),
          ),
          SliverGutter(
            child: AvCard(
              child: AvLineChart(
                series: [
                  ChartSeries(
                    label: 'Accuracy',
                    values: [
                      for (final session in sessions.reversed)
                        session.percentage,
                    ],
                    color: AvColors.flare,
                  ),
                ],
                xLabels: [
                  for (final session in sessions.reversed)
                    Fmt.date(session.startedAt),
                ],
                yUnit: '%',
                targetLine: 45,
                targetLabel: 'Team target',
              ),
            ),
          ),
          const SliverGutter(
            top: AvSpace.lg,
            child: AvSectionHeader(
              title: 'Where the work is going',
              accent: AvColors.court,
              padding: EdgeInsets.only(bottom: AvSpace.sm),
            ),
          ),
          SliverGutter(
            child: AvCard(
              child: Column(
                children: [
                  AvCourtMap(zones: zones, shots: const []),
                  const SizedBox(height: AvSpace.sm),
                  const AvCourtLegend(),
                ],
              ),
            ),
          ),
        ],
        if (assignments.isNotEmpty) ...[
          const SliverGutter(
            top: AvSpace.lg,
            child: AvSectionHeader(
              title: 'Assignments',
              accent: AvColors.insight,
              padding: EdgeInsets.only(bottom: AvSpace.sm),
            ),
          ),
          for (final assignment in assignments)
            SliverGutter(
              top: AvSpace.xs,
              child: AssignmentCard(assignment: assignment),
            ),
        ],
        if (athlete.guardianApproved) ...[
          const SliverGutter(
            top: AvSpace.lg,
            child: AvSectionHeader(
              title: 'Recent sessions',
              padding: EdgeInsets.only(bottom: AvSpace.sm),
            ),
          ),
          for (final session in sessions)
            SliverGutter(
              top: AvSpace.xs,
              child: SessionCard(
                session: session,
                onTap: () => context.push(AppRoute.session(session.id)),
              ),
            ),
        ],
      ],
    );
  }
}

class _AthleteHeader extends StatelessWidget {
  const _AthleteHeader({required this.athlete});

  final AthleteSummary athlete;

  @override
  Widget build(BuildContext context) {
    return AvInkCard(
      padding: const EdgeInsets.all(AvSpace.lg),
      accent: athlete.accentColor,
      child: Row(
        children: [
          AvAvatar(
            initials: athlete.initials,
            color: athlete.accentColor,
            size: 60,
            ring: true,
          ),
          const SizedBox(width: AvSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  athlete.name,
                  style:
                      AvType.headingMedium.copyWith(color: AvColors.textOnInk),
                ),
                const SizedBox(height: 3),
                Text(
                  '${athlete.position.label} \u00B7 ${athlete.ageBand}',
                  style:
                      AvType.caption.copyWith(color: AvColors.textOnInkMuted),
                ),
                const SizedBox(height: AvSpace.sm),
                Wrap(
                  spacing: AvSpace.xxs,
                  runSpacing: AvSpace.xxs,
                  children: [
                    AvPill(
                      label:
                          'Last session ${Fmt.relative(athlete.lastSessionAt)}',
                      color: AvColors.textOnInkMuted,
                      dense: true,
                    ),
                    if (athlete.pendingReviews > 0)
                      AvPill(
                        label: '${athlete.pendingReviews} to review',
                        color: AvColors.caution,
                        dense: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Assignment row shared by the athlete detail and review screens.
class AssignmentCard extends StatelessWidget {
  const AssignmentCard({
    super.key,
    required this.assignment,
    this.onStatusChange,
    this.showAthlete = false,
  });

  final Assignment assignment;
  final ValueChanged<AssignmentStatus>? onStatusChange;
  final bool showAthlete;

  @override
  Widget build(BuildContext context) {
    return AvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignment.drillName,
                      style: AvType.titleMedium.primary,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      showAthlete
                          ? '${assignment.athleteName} \u00B7 due '
                              '${Fmt.relative(assignment.dueAt)}'
                          : 'Set by ${assignment.assignedBy} \u00B7 due '
                              '${Fmt.relative(assignment.dueAt)}',
                      style: AvType.caption.faint,
                    ),
                  ],
                ),
              ),
              AvPill(
                label: assignment.status.label,
                color: assignment.status.color,
                dense: true,
              ),
            ],
          ),
          if (assignment.note.isNotEmpty) ...[
            const SizedBox(height: AvSpace.sm),
            Text(assignment.note, style: AvType.bodySmall.muted),
          ],
          const SizedBox(height: AvSpace.sm),
          Row(
            children: [
              Expanded(
                child: AvMeter(
                  value: assignment.progress,
                  color: assignment.status.color,
                ),
              ),
              const SizedBox(width: AvSpace.sm),
              Text(
                '${assignment.completedMakes}/${assignment.targetMakes}',
                style: AvType.tabular(AvType.caption).muted,
              ),
            ],
          ),
          if (onStatusChange != null &&
              assignment.status == AssignmentStatus.submitted) ...[
            const SizedBox(height: AvSpace.sm),
            Row(
              children: [
                Expanded(
                  child: AvButton(
                    label: 'Send back',
                    variant: AvButtonVariant.outline,
                    size: AvButtonSize.small,
                    expand: true,
                    onPressed: () =>
                        onStatusChange!(AssignmentStatus.inProgress),
                  ),
                ),
                const SizedBox(width: AvSpace.xs),
                Expanded(
                  child: AvButton(
                    label: 'Mark reviewed',
                    size: AvButtonSize.small,
                    expand: true,
                    onPressed: () =>
                        onStatusChange!(AssignmentStatus.reviewed),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
