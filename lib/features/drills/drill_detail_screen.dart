import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/session.dart';
import '../../design/charts/av_court_map.dart';
import '../../design/components/av_button.dart';
import '../../design/components/av_indicators.dart';
import '../../design/components/av_layout.dart';
import '../../design/components/av_stats.dart';
import '../../design/components/av_surface.dart';
import '../../state/stores.dart';

class DrillDetailScreen extends ConsumerWidget {
  const DrillDetailScreen({super.key, required this.drillId});

  final String drillId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drill = ref.watch(drillByIdProvider(drillId));
    final sessions = ref
        .watch(sessionStoreProvider)
        .where((s) => s.drillId == drill.id)
        .toList(growable: false);
    final accent = drill.category.color;

    final history = sessions.isEmpty
        ? null
        : sessions.map((s) => s.percentage).reduce((a, b) => a + b) /
              sessions.length;

    return AvScaffold(
      title: drill.name,
      subtitle: '${drill.category.label} \u00B7 ${drill.difficulty.label}',
      leading: const AvBackButton(),
      bottomBar: Container(
        padding: EdgeInsets.fromLTRB(
          AvSpace.gutter,
          AvSpace.sm,
          AvSpace.gutter,
          MediaQuery.paddingOf(context).bottom + AvSpace.sm,
        ),
        decoration: const BoxDecoration(
          color: AvColors.surface,
          border: Border(top: BorderSide(color: AvColors.hairline)),
        ),
        child: Row(
          children: [
            Expanded(
              child: AvButton(
                label: 'Start this drill',
                icon: Icons.play_arrow_rounded,
                size: AvButtonSize.large,
                expand: true,
                onPressed: () => context.push(AppRoute.placement(drill.id)),
              ),
            ),
          ],
        ),
      ),
      slivers: [
        SliverGutter(
          child: AvInkCard(
            accent: accent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AvGlyph(
                      icon: drill.category.icon,
                      color: accent,
                      size: 44,
                      background: accent.withValues(alpha: 0.2),
                    ),
                    const SizedBox(width: AvSpace.sm),
                    Expanded(
                      child: Text(
                        drill.coachingFocus,
                        style: AvType.headingSmall.onInk,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AvSpace.md),
                Text(drill.summary, style: AvType.bodySmall.onInkMuted),
                const SizedBox(height: AvSpace.lg),
                Wrap(
                  spacing: AvSpace.xl,
                  runSpacing: AvSpace.md,
                  children: [
                    AvInkStat(
                      label: 'Target',
                      value: '${drill.targetMakes}',
                      unit: 'makes',
                      accent: accent,
                    ),
                    AvInkStat(
                      label: 'Volume',
                      value: '${drill.targetAttempts}',
                      unit: 'attempts',
                    ),
                    AvInkStat(
                      label: 'Pass mark',
                      value: drill.successThreshold.toStringAsFixed(0),
                      unit: '%',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: AvSectionHeader(
            title: 'Shooting spots',
            subtitle: drill.movementPattern ?? 'Stationary at each spot',
            accent: accent,
          ),
        ),
        SliverGutter(
          child: AvCard(
            child: Column(
              children: [
                AvCourtMap(
                  zones: {
                    for (final zone in drill.zones)
                      zone: ZoneRecord(
                        0,
                        (drill.targetAttempts / drill.zones.length).round(),
                      ),
                  },
                  minimumSample: 1000,
                ),
                const SizedBox(height: AvSpace.sm),
                Wrap(
                  spacing: AvSpace.xs,
                  runSpacing: AvSpace.xs,
                  children: [
                    for (final zone in drill.zones)
                      AvPill(
                        label: zone.shortLabel,
                        color: zone.isThree ? AvColors.insight : AvColors.court,
                        dense: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: AvSectionHeader(
            title: 'Capture requirements',
            subtitle: 'What the pipeline needs to score this drill correctly',
            accent: AvColors.court,
          ),
        ),
        SliverGutter(
          child: AvCard(
            child: Column(
              children: [
                AvKeyValue(
                  label: 'Recommended placement',
                  value: '${drill.recommendedAngle.label} of the shooter',
                ),
                const Divider(height: 1),
                AvKeyValue(
                  label: 'Shot type recorded',
                  value: drill.shotType.label,
                ),
                const Divider(height: 1),
                AvKeyValue(
                  label: 'Rest between attempts',
                  value: drill.restSeconds == 0
                      ? 'Self-paced'
                      : '${drill.restSeconds} seconds',
                ),
                const Divider(height: 1),
                AvKeyValue(
                  label: 'Time limit',
                  value: drill.timeLimitSeconds == null
                      ? 'None'
                      : '${(drill.timeLimitSeconds! / 60).toStringAsFixed(0)} minutes',
                ),
                const Divider(height: 1),
                AvKeyValue(
                  label: 'Automatic progression',
                  value: drill.autoProgression ? 'Enabled' : 'Off',
                ),
                const SizedBox(height: AvSpace.sm),
                Container(
                  padding: const EdgeInsets.all(AvSpace.sm),
                  decoration: BoxDecoration(
                    color: AvColors.courtTint,
                    borderRadius: AvRadius.allSm,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.videocam_rounded,
                        size: 16,
                        color: AvColors.courtDeep,
                      ),
                      const SizedBox(width: AvSpace.xs),
                      Expanded(
                        child: Text(
                          drill.recommendedAngle.description,
                          style: AvType.caption.copyWith(
                            color: AvColors.courtDeep,
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
        SliverToBoxAdapter(
          child: AvSectionHeader(
            title: 'Audio prompts',
            subtitle: 'Spoken between attempts when audio feedback is on',
            accent: AvColors.caution,
          ),
        ),
        SliverGutter(
          child: AvCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < drill.audioPrompts.length; i++) ...[
                  if (i > 0) const SizedBox(height: AvSpace.xs),
                  Row(
                    children: [
                      const Icon(
                        Icons.volume_up_rounded,
                        size: 15,
                        color: AvColors.caution,
                      ),
                      const SizedBox(width: AvSpace.xs),
                      Expanded(
                        child: Text(
                          drill.audioPrompts[i],
                          style: AvType.bodySmall.secondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        if (sessions.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: AvSectionHeader(
              title: 'Your history',
              subtitle: Fmt.count(sessions.length, 'recorded session'),
              accent: AvColors.made,
            ),
          ),
          SliverGutter(
            child: AvCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AvStatTile(
                          label: 'Average accuracy',
                          value: history!.toStringAsFixed(1),
                          unit: '%',
                          accent: AvColors.flare,
                          emphasis: true,
                        ),
                      ),
                      const SizedBox(width: AvSpace.sm),
                      Expanded(
                        child: AvStatTile(
                          label: 'Best session',
                          value: sessions
                              .map((s) => s.percentage)
                              .reduce((a, b) => a > b ? a : b)
                              .toStringAsFixed(1),
                          unit: '%',
                          accent: AvColors.made,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AvSpace.sm),
                  for (final session in sessions)
                    AvKeyValue(
                      label:
                          '${session.startedAt.day}/${session.startedAt.month} '
                          '\u00B7 ${Fmt.count(session.attemptCount, 'attempt')}',
                      value:
                          '${Fmt.count(session.makeCount, 'make')} \u00B7 '
                          '${session.percentage.toStringAsFixed(0)}%',
                      trailing: AvIconButton(
                        icon: Icons.chevron_right_rounded,
                        size: 28,
                        background: Colors.transparent,
                        borderColor: null,
                        tooltip: 'Open session',
                        onPressed: () =>
                            context.push(AppRoute.session(session.id)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
