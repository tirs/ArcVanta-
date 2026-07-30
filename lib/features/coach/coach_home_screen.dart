import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/profile.dart';
import '../../design/components/av_brand.dart';
import '../../design/components/av_button.dart';
import '../../design/components/av_indicators.dart';
import '../../design/components/av_layout.dart';
import '../../design/components/av_stats.dart';
import '../../design/components/av_surface.dart';
import '../../state/stores.dart';

enum _RosterSort { attention, name, accuracy, volume }

extension on _RosterSort {
  String get label => switch (this) {
        _RosterSort.attention => 'Attention',
        _RosterSort.name => 'Name',
        _RosterSort.accuracy => 'Accuracy',
        _RosterSort.volume => 'Volume',
      };
}

/// The coach's roster. Sorted by who needs attention first, because a coach
/// opens this between drills and has about ten seconds.
class CoachHomeScreen extends ConsumerStatefulWidget {
  const CoachHomeScreen({super.key});

  @override
  ConsumerState<CoachHomeScreen> createState() => _CoachHomeScreenState();
}

class _CoachHomeScreenState extends ConsumerState<CoachHomeScreen> {
  _RosterSort _sort = _RosterSort.attention;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final roster = ref.watch(rosterProvider);
    final assignments = ref.watch(assignmentStoreProvider);
    final pending = roster.fold<int>(0, (sum, a) => sum + a.pendingReviews);

    final visible = roster
        .where(
          (a) => _query.isEmpty ||
              a.name.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList()
      ..sort((a, b) => switch (_sort) {
            _RosterSort.attention => _attentionScore(b)
                .compareTo(_attentionScore(a)),
            _RosterSort.name => a.name.compareTo(b.name),
            _RosterSort.accuracy => b.percentage.compareTo(a.percentage),
            _RosterSort.volume =>
              b.sessionsThisWeek.compareTo(a.sessionsThisWeek),
          });

    return AvScaffold(
      title: 'Roster',
      subtitle: '${roster.length} athletes \u00B7 $pending clips to review',
      actions: [
        AvIconButton(
          icon: Icons.insights_rounded,
          tooltip: 'Team dashboard',
          onPressed: () => context.push(AppRoute.team),
        ),
        AvIconButton(
          icon: Icons.rate_review_rounded,
          tooltip: 'Review queue',
          badgeCount: pending,
          onPressed: () => context.push(AppRoute.reviewQueue),
        ),
      ],
      slivers: [
        SliverGutter(
          child: AvInkCard(
            padding: const EdgeInsets.all(AvSpace.md),
            child: Wrap(
              spacing: AvSpace.lg,
              runSpacing: AvSpace.md,
              children: [
                AvInkStat(
                  label: 'Sessions',
                  value:
                      '${roster.fold<int>(0, (s, a) => s + a.sessionsThisWeek)}',
                  unit: ' this week',
                  accent: AvColors.textOnInk,
                ),
                AvInkStat(
                  label: 'To review',
                  value: '$pending',
                  accent: AvColors.caution,
                ),
                AvInkStat(
                  label: 'Assignments open',
                  value:
                      '${assignments.where((a) => a.status.index < 3).length}',
                  accent: AvColors.flare,
                ),
              ],
            ),
          ),
        ),
        SliverGutter(
          top: AvSpace.md,
          child: TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              hintText: 'Find an athlete',
              prefixIcon: Icon(Icons.search_rounded, size: 20),
            ),
          ),
        ),
        SliverGutter(
          top: AvSpace.sm,
          child: AvSegmented<_RosterSort>(
            values: _RosterSort.values,
            labels: [for (final sort in _RosterSort.values) sort.label],
            selected: _sort,
            onChanged: (value) => setState(() => _sort = value),
            dense: true,
          ),
        ),
        if (visible.isEmpty)
          const SliverGutter(
            top: AvSpace.xl,
            child: AvEmptyState(
              icon: Icons.person_search_rounded,
              title: 'No athletes match',
              message: 'Try a different name, or clear the search.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AvSpace.gutter,
              AvSpace.md,
              AvSpace.gutter,
              0,
            ),
            sliver: SliverList.separated(
              itemCount: visible.length,
              separatorBuilder: (_, __) => const SizedBox(height: AvSpace.sm),
              itemBuilder: (context, index) => _AthleteRow(
                athlete: visible[index],
                onTap: () => context.push(AppRoute.athlete(visible[index].id)),
                onAssign: () => context.push(
                  '${AppRoute.assign}?athlete=${visible[index].id}',
                ),
              ),
            ),
          ),
        SliverGutter(
          top: AvSpace.lg,
          child: AvButton(
            label: 'Assign a drill to the group',
            variant: AvButtonVariant.outline,
            icon: Icons.assignment_add,
            expand: true,
            onPressed: () => context.push(AppRoute.assign),
          ),
        ),
      ],
    );
  }

  double _attentionScore(AthleteSummary athlete) {
    var score = athlete.pendingReviews * 10.0;
    if (athlete.percentageDelta < 0) score += athlete.percentageDelta.abs() * 2;
    if (athlete.sessionsThisWeek == 0) score += 15;
    if (!athlete.guardianApproved) score += 25;
    score += (1 - athlete.assignmentProgress) * 8;
    return score;
  }
}

class _AthleteRow extends StatelessWidget {
  const _AthleteRow({
    required this.athlete,
    required this.onTap,
    required this.onAssign,
  });

  final AthleteSummary athlete;
  final VoidCallback onTap;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    return AvCard(
      onTap: onTap,
      child: Column(
        children: [
          Row(
            children: [
              AvAvatar(
                initials: athlete.initials,
                color: athlete.accentColor,
                size: 46,
              ),
              const SizedBox(width: AvSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AvSpace.xs,
                      runSpacing: AvSpace.xxs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          athlete.name,
                          style: AvType.titleMedium.primary,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!athlete.guardianApproved)
                          const AvPill(
                            label: 'Consent pending',
                            color: AvColors.caution,
                            dense: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${athlete.position.abbreviation} \u00B7 '
                      '${athlete.ageBand} \u00B7 last session '
                      '${Fmt.relative(athlete.lastSessionAt)}',
                      style: AvType.caption.faint,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AvSpace.xs),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${athlete.percentage.toStringAsFixed(0)}%',
                    style: AvType.tabular(AvType.metricMedium)
                        .copyWith(fontSize: 19),
                  ),
                  AvDelta(value: athlete.percentageDelta, unit: '%'),
                ],
              ),
            ],
          ),
          const SizedBox(height: AvSpace.sm),
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  label: 'Sessions',
                  value: '${athlete.sessionsThisWeek}',
                  caption: 'this week',
                ),
              ),
              Expanded(
                child: _MiniMetric(
                  label: 'Mechanics',
                  value: athlete.mechanicsScore.toStringAsFixed(0),
                  caption: 'of 100',
                ),
              ),
              Expanded(
                child: _MiniMetric(
                  label: 'Assignments',
                  value:
                      '${athlete.assignmentsComplete}/${athlete.assignmentsTotal}',
                  caption: 'complete',
                ),
              ),
              if (athlete.pendingReviews > 0)
                AvPill(
                  label: '${athlete.pendingReviews} to review',
                  color: AvColors.insight,
                  icon: Icons.play_circle_outline_rounded,
                  dense: true,
                )
              else
                AvIconButton(
                  icon: Icons.add_task_rounded,
                  tooltip: 'Assign a drill',
                  size: 34,
                  onPressed: onAssign,
                ),
            ],
          ),
          const SizedBox(height: AvSpace.sm),
          Row(
            children: [
              const Icon(
                Icons.center_focus_strong_rounded,
                size: 14,
                color: AvColors.court,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  athlete.focusArea,
                  style: AvType.caption.muted,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AvType.overline.copyWith(
            fontSize: 8.5,
            color: AvColors.textFaint,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AvType.tabular(AvType.metricSmall).primary,
        ),
        Text(
          caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AvType.caption.faint,
        ),
      ],
    );
  }
}
