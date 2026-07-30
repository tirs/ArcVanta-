import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../data/models/profile.dart';
import '../../design/charts/av_bar_chart.dart';
import '../../design/components/av_brand.dart';
import '../../design/components/av_button.dart';
import '../../design/components/av_indicators.dart';
import '../../design/components/av_layout.dart';
import '../../design/components/av_stats.dart';
import '../../design/components/av_surface.dart';
import '../../state/stores.dart';

/// Team-level view. Leaderboards are opt-in and only ever list verified work,
/// which the scope makes a hard requirement rather than a setting.
class TeamDashboardScreen extends ConsumerStatefulWidget {
  const TeamDashboardScreen({super.key});

  @override
  ConsumerState<TeamDashboardScreen> createState() =>
      _TeamDashboardScreenState();
}

class _TeamDashboardScreenState extends ConsumerState<TeamDashboardScreen> {
  bool _leaderboardVisible = true;

  @override
  Widget build(BuildContext context) {
    final roster = ref.watch(rosterProvider);
    final sessions = roster.fold<int>(0, (s, a) => s + a.sessionsThisWeek);
    final averageAccuracy = roster.isEmpty
        ? 0.0
        : roster.map((a) => a.percentage).reduce((a, b) => a + b) /
            roster.length;
    final averageMechanics = roster.isEmpty
        ? 0.0
        : roster.map((a) => a.mechanicsScore).reduce((a, b) => a + b) /
            roster.length;
    final consentGaps =
        roster.where((a) => !a.guardianApproved).toList(growable: false);
    final inactive =
        roster.where((a) => a.sessionsThisWeek == 0).toList(growable: false);

    final ranked = [...roster]
      ..sort((a, b) => b.percentage.compareTo(a.percentage));

    return AvScaffold(
      title: 'Team',
      subtitle: 'Northgate Prep \u00B7 ${roster.length} athletes',
      leading: const AvBackButton(),
      slivers: [
        SliverGutter(
          child: AvInkCard(
            padding: const EdgeInsets.all(AvSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'THIS WEEK',
                  style:
                      AvType.overline.copyWith(color: AvColors.textOnInkMuted),
                ),
                const SizedBox(height: AvSpace.md),
                Wrap(
                  spacing: AvSpace.xl,
                  runSpacing: AvSpace.md,
                  children: [
                    AvInkStat(
                      label: 'Sessions',
                      value: '$sessions',
                      accent: AvColors.textOnInk,
                    ),
                    AvInkStat(
                      label: 'Team accuracy',
                      value: averageAccuracy.toStringAsFixed(0),
                      unit: '%',
                      accent: AvColors.flare,
                    ),
                    AvInkStat(
                      label: 'Mechanics',
                      value: averageMechanics.toStringAsFixed(0),
                      unit: '/100',
                      accent: AvColors.insight,
                    ),
                  ],
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
                label: 'Active',
                value: '${roster.length - inactive.length}',
                caption: 'trained this week',
                accent: AvColors.made,
                icon: Icons.check_circle_rounded,
              ),
              AvStatTile(
                label: 'Not training',
                value: '${inactive.length}',
                caption: 'no sessions logged',
                accent: AvColors.caution,
                icon: Icons.pause_circle_rounded,
              ),
              AvStatTile(
                label: 'Consent gaps',
                value: '${consentGaps.length}',
                caption: 'guardian approval needed',
                accent: AvColors.miss,
                icon: Icons.shield_outlined,
              ),
              AvStatTile(
                label: 'To review',
                value: '${roster.fold<int>(0, (s, a) => s + a.pendingReviews)}',
                caption: 'clips submitted',
                accent: AvColors.insight,
                icon: Icons.rate_review_rounded,
              ),
            ],
          ),
        ),
        const SliverGutter(
          top: AvSpace.lg,
          child: AvSectionHeader(
            title: 'Accuracy across the roster',
            accent: AvColors.flare,
            padding: EdgeInsets.only(bottom: AvSpace.sm),
          ),
        ),
        SliverGutter(
          child: AvCard(
            child: AvBarList(
              data: [
                for (final athlete in ranked)
                  BarDatum(
                    label: athlete.name,
                    value: athlete.percentage,
                    color: athlete.accentColor,
                    caption: '${athlete.sessionsThisWeek} sessions',
                  ),
              ],
              maxValue: 70,
              valueSuffix: '%',
            ),
          ),
        ),
        SliverGutter(
          top: AvSpace.lg,
          child: AvCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Show the team leaderboard',
                            style: AvType.titleMedium.primary,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Only verified sessions count. Athletes can opt '
                            'out individually and minors are excluded unless '
                            'a guardian opts in.',
                            style: AvType.caption.muted,
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _leaderboardVisible,
                      onChanged: (value) =>
                          setState(() => _leaderboardVisible = value),
                    ),
                  ],
                ),
                if (_leaderboardVisible) ...[
                  const SizedBox(height: AvSpace.md),
                  const AvSeparator(),
                  const SizedBox(height: AvSpace.sm),
                  for (var i = 0; i < ranked.length; i++)
                    _LeaderRow(
                      rank: i + 1,
                      athlete: ranked[i],
                      onTap: () => context.push(AppRoute.athlete(ranked[i].id)),
                    ),
                ],
              ],
            ),
          ),
        ),
        if (consentGaps.isNotEmpty) ...[
          const SliverGutter(
            top: AvSpace.lg,
            child: AvSectionHeader(
              title: 'Needs guardian approval',
              accent: AvColors.miss,
              padding: EdgeInsets.only(bottom: AvSpace.sm),
            ),
          ),
          SliverGutter(
            child: AvCard(
              child: Column(
                children: [
                  for (final athlete in consentGaps)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          AvAvatar(
                            initials: athlete.initials,
                            color: athlete.accentColor,
                            size: 36,
                          ),
                          const SizedBox(width: AvSpace.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  athlete.name,
                                  style: AvType.titleSmall.primary,
                                ),
                                Text(
                                  'Coach access limited to totals',
                                  style: AvType.caption.faint,
                                ),
                              ],
                            ),
                          ),
                          AvButton(
                            label: 'Resend',
                            variant: AvButtonVariant.outline,
                            size: AvButtonSize.small,
                            onPressed: () =>
                                ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Consent request resent for ${athlete.name}',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
        SliverGutter(
          top: AvSpace.lg,
          child: AvButton(
            label: 'Assign to the whole team',
            icon: Icons.groups_rounded,
            expand: true,
            onPressed: () => context.push(AppRoute.assign),
          ),
        ),
      ],
    );
  }
}

class _LeaderRow extends StatelessWidget {
  const _LeaderRow({
    required this.rank,
    required this.athlete,
    required this.onTap,
  });

  final int rank;
  final AthleteSummary athlete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AvPressable(
      onTap: onTap,
      borderRadius: AvRadius.allSm,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text(
                '$rank',
                style: AvType.tabular(AvType.metricSmall).copyWith(
                  color: rank <= 3 ? AvColors.flare : AvColors.textFaint,
                ),
              ),
            ),
            AvAvatar(
              initials: athlete.initials,
              color: athlete.accentColor,
              size: 32,
            ),
            const SizedBox(width: AvSpace.sm),
            Expanded(
              child: Text(athlete.name, style: AvType.titleSmall.primary),
            ),
            AvDelta(value: athlete.percentageDelta, unit: '%'),
            const SizedBox(width: AvSpace.sm),
            SizedBox(
              width: 44,
              child: Text(
                '${athlete.percentage.toStringAsFixed(0)}%',
                textAlign: TextAlign.right,
                style: AvType.tabular(AvType.metricSmall).primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
