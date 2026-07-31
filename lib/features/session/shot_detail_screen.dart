import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/metrics/metric_catalog.dart';
import '../../data/models/confidence.dart';
import '../../data/models/session.dart';
import '../../data/models/shot.dart';
import '../../design/charts/av_shot_graphics.dart';
import '../../design/components/av_button.dart';
import '../../design/components/av_indicators.dart';
import '../../design/components/av_layout.dart';
import '../../design/components/av_stats.dart';
import '../../design/components/av_surface.dart';
import '../../state/live_session.dart';
import '../../state/stores.dart';
import 'shot_replay.dart';

/// One attempt in full: the arc, the phase breakdown, every eligible
/// measurement and the reasoning behind the result the system recorded.
class ShotDetailScreen extends ConsumerWidget {
  const ShotDetailScreen({
    super.key,
    required this.sessionId,
    required this.shotId,
  });

  final String sessionId;
  final String shotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionByIdProvider(sessionId));
    final shot = session?.shots.where((s) => s.id == shotId).firstOrNull;

    if (session == null || shot == null) {
      return const AvScaffold(
        title: 'Shot',
        leading: AvBackButton(),
        slivers: [
          SliverGutter(
            top: AvSpace.xxl,
            child: AvEmptyState(
              icon: Icons.search_off_rounded,
              title: 'Shot not found',
              message: 'This attempt is no longer stored on the device.',
            ),
          ),
        ],
      );
    }

    final angle = session.calibration.angle;
    final metrics = MetricCatalog.forShot(
      shot,
      angle: angle,
      baselines: MetricCatalog.sessionBaselines(session),
    );
    final index = session.shots.indexOf(shot);
    final previous = index > 0 ? session.shots[index - 1] : null;
    final next = index < session.shots.length - 1
        ? session.shots[index + 1]
        : null;

    return AvScaffold(
      title: 'Shot ${shot.index}',
      subtitle: '${session.drillName} \u00B7 ${shot.zone.label}',
      leading: const AvBackButton(),
      actions: [
        AvIconButton(
          icon: Icons.compare_arrows_rounded,
          tooltip: 'Compare',
          onPressed: () => context.push(AppRoute.compare(session.id, shot.id)),
        ),
      ],
      bottomBar: AvBottomBar(
        children: [
          Expanded(
            child: AvButton(
              label: 'Previous',
              variant: AvButtonVariant.outline,
              icon: Icons.chevron_left_rounded,
              expand: true,
              onPressed: previous == null
                  ? null
                  : () => context.pushReplacement(
                      AppRoute.shot(session.id, previous.id),
                    ),
            ),
          ),
          Expanded(
            child: AvButton(
              label: 'Next',
              variant: AvButtonVariant.outline,
              trailingIcon: Icons.chevron_right_rounded,
              expand: true,
              onPressed: next == null
                  ? null
                  : () => context.pushReplacement(
                      AppRoute.shot(session.id, next.id),
                    ),
            ),
          ),
        ],
      ),
      slivers: [
        SliverGutter(
          child: _OutcomePanel(shot: shot, session: session),
        ),
        _ShotReplayCard(shotIndex: index),
        SliverGutter(
          top: AvSpace.sm,
          child: AvCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Flight path', style: AvType.titleMedium.primary),
                    const Spacer(),
                    AvPill(
                      label: '${shot.flightTimeMs} ms',
                      color: AvColors.court,
                      dense: true,
                    ),
                  ],
                ),
                const SizedBox(height: AvSpace.sm),
                AvArcDiagram(shot: shot, height: 200),
              ],
            ),
          ),
        ),
        SliverGutter(
          top: AvSpace.sm,
          child: AvCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Phase breakdown', style: AvType.titleMedium.primary),
                const SizedBox(height: 4),
                Text(
                  'Durations measured from the pose stream at '
                  '${session.calibration.frameRate} frames per second.',
                  style: AvType.caption.muted,
                ),
                const SizedBox(height: AvSpace.md),
                AvPhaseTimeline(phases: shot.phases),
              ],
            ),
          ),
        ),
        for (final group in MetricGroup.values.where(
          (g) => g != MetricGroup.outcome,
        )) ...[
          SliverGutter(
            top: AvSpace.lg,
            child: AvSectionHeader(
              title: group.label,
              subtitle: group.description,
              accent: switch (group) {
                MetricGroup.arc => AvColors.flare,
                MetricGroup.accuracy => AvColors.court,
                MetricGroup.mechanics => AvColors.insight,
                MetricGroup.timing => AvColors.made,
                MetricGroup.outcome => AvColors.flare,
              },
              padding: const EdgeInsets.only(bottom: AvSpace.sm),
            ),
          ),
          SliverGutter(
            child: AvCard(
              child: Column(
                children: [
                  for (final entry in MetricCatalog.inGroup(metrics, group))
                    AvMetricRow(
                      metric: entry.metric,
                      angle: angle,
                      onTap: () => _explain(context, entry.metric, angle),
                    ),
                ],
              ),
            ),
          ),
        ],
        const SliverGutter(
          top: AvSpace.lg,
          child: AvSectionHeader(
            title: 'Why this result',
            padding: EdgeInsets.only(bottom: AvSpace.sm),
          ),
        ),
        SliverGutter(
          child: _EvidenceCard(shot: shot, session: session),
        ),
        SliverGutter(
          top: AvSpace.sm,
          child: _CorrectionCard(
            shot: shot,
            onCorrect: (result) => ref
                .read(sessionStoreProvider.notifier)
                .correctShotResult(
                  sessionId: session.id,
                  shotId: shot.id,
                  result: result,
                ),
          ),
        ),
      ],
    );
  }

  void _explain(BuildContext context, MetricValue metric, CameraAngle angle) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AvColors.surface,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AvSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(metric.label, style: AvType.headingSmall.primary),
              const SizedBox(height: AvSpace.xs),
              Text(metric.description, style: AvType.bodySmall.muted),
              const SizedBox(height: AvSpace.md),
              AvKeyValue(
                label: 'This shot',
                value: metric.eligibleFor(angle)
                    ? metric.formatted
                    : 'Not measurable from ${angle.label.toLowerCase()}',
              ),
              if (metric.targetLow != null && metric.targetHigh != null)
                AvKeyValue(
                  label: 'Target range',
                  value:
                      '${metric.targetLow!.toStringAsFixed(1)}'
                      '\u2013${metric.targetHigh!.toStringAsFixed(1)}'
                      '${metric.unit}',
                ),
              if (metric.personalBaseline != null)
                AvKeyValue(
                  label: 'Your session average',
                  value:
                      '${metric.personalBaseline!.toStringAsFixed(1)}${metric.unit}',
                ),
              AvKeyValue(
                label: 'Measurable from',
                value: metric.eligibleAngles
                    .map((a) => a.label.toLowerCase())
                    .join(', '),
              ),
              const SizedBox(height: AvSpace.md),
              AvTintCard(
                tint: metric.confidence.softColor,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      metric.confidence.icon,
                      size: 16,
                      color: metric.confidence.color,
                    ),
                    const SizedBox(width: AvSpace.xs),
                    Expanded(
                      child: Text(
                        metric.confidence.explanation,
                        style: AvType.caption.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutcomePanel extends StatelessWidget {
  const _OutcomePanel({required this.shot, required this.session});

  final Shot shot;
  final TrainingSession session;

  @override
  Widget build(BuildContext context) {
    return AvInkCard(
      padding: const EdgeInsets.all(AvSpace.lg),
      accent: shot.result.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvGlyph(
                icon: shot.result.icon,
                color: shot.result.color,
                background: shot.result.color.withValues(alpha: 0.18),
                size: 44,
              ),
              const SizedBox(width: AvSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shot.outcomeDetail.label,
                      style: AvType.headingMedium.copyWith(
                        color: AvColors.textOnInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${shot.type.label} \u00B7 '
                      '${Fmt.clock(shot.offsetFromStart)} into the session',
                      style: AvType.caption.copyWith(
                        color: AvColors.textOnInkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              AvConfidenceBadge(
                level: shot.confidence,
                compact: true,
                onInk: true,
              ),
            ],
          ),
          const SizedBox(height: AvSpace.lg),
          Wrap(
            spacing: AvSpace.lg,
            runSpacing: AvSpace.md,
            children: [
              AvInkStat(
                label: 'Entry',
                value: shot.entryAngle.toStringAsFixed(0),
                unit: '\u00B0',
                accent: AvColors.flare,
              ),
              AvInkStat(
                label: 'Apex',
                value: shot.apexHeightM.toStringAsFixed(1),
                unit: ' m',
                accent: AvColors.court,
              ),
              AvInkStat(
                label: 'Mechanics',
                value: shot.mechanicsScore.toStringAsFixed(0),
                unit: '/100',
                accent: AvColors.insight,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.shot, required this.session});

  final Shot shot;
  final TrainingSession session;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      'Ball tracked continuously from release to the rim plane over '
          '${shot.flightTimeMs} milliseconds.',
      if (shot.isMake)
        'Downward crossing of the rim plane detected inside the hoop '
            'circle, ${shot.outcomeDetail.label.toLowerCase()}.'
      else if (shot.result == ShotResult.missed)
        'Contact registered at the ${shot.outcomeDetail.label.toLowerCase()} '
            'with no subsequent downward crossing inside the hoop.'
      else
        'The ball left the tracked region before a rim crossing could be '
            'confirmed.',
      'Pose landmarks held above threshold for '
          '${shot.confidence == ConfidenceLevel.high ? 'the full motion' : 'most of the motion'}.',
      'Court plane locked at capture quality '
          '${(session.calibration.qualityScore * 100).round()} of 100.',
    ];

    return AvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0) const SizedBox(height: AvSpace.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AvColors.court,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AvSpace.sm),
                Expanded(child: Text(lines[i], style: AvType.bodySmall.muted)),
              ],
            ),
          ],
          const SizedBox(height: AvSpace.md),
          const AvSeparator(),
          const SizedBox(height: AvSpace.sm),
          Text(
            'Model versions ${session.modelVersion}',
            style: AvType.caption.faint,
          ),
        ],
      ),
    );
  }
}

class _CorrectionCard extends StatelessWidget {
  const _CorrectionCard({required this.shot, required this.onCorrect});

  final Shot shot;
  final ValueChanged<ShotResult> onCorrect;

  @override
  Widget build(BuildContext context) {
    return AvTintCard(
      tint: AvColors.insightTint,
      borderColor: AvColors.insightSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AvGlyph(
                icon: Icons.edit_note_rounded,
                color: AvColors.insightDeep,
                background: AvColors.insightSoft,
                size: 34,
              ),
              const SizedBox(width: AvSpace.sm),
              Expanded(
                child: Text(
                  shot.correctedByUser
                      ? 'You corrected this result'
                      : 'Disagree with this result?',
                  style: AvType.titleSmall.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AvSpace.xs),
          Text(
            'Corrections are kept separate from model output. They update your '
            'totals on this device and stay here.',
            style: AvType.caption.muted,
          ),
          const SizedBox(height: AvSpace.sm),
          Row(
            children: [
              Expanded(
                child: AvButton(
                  label: 'It was a miss',
                  variant: AvButtonVariant.outline,
                  size: AvButtonSize.small,
                  expand: true,
                  onPressed: shot.result == ShotResult.missed
                      ? null
                      : () => onCorrect(ShotResult.missed),
                ),
              ),
              const SizedBox(width: AvSpace.xs),
              Expanded(
                child: AvButton(
                  label: 'It went in',
                  variant: AvButtonVariant.outline,
                  size: AvButtonSize.small,
                  expand: true,
                  onPressed: shot.result == ShotResult.made
                      ? null
                      : () => onCorrect(ShotResult.made),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShotReplayCard extends ConsumerWidget {
  const _ShotReplayCard({required this.shotIndex});

  final int shotIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clips = ref.read(liveSessionProvider.notifier).clips;
    final clip = clips
        .where((c) => c.shotIndex == shotIndex)
        .firstOrNull;

    if (clip == null || clip.frames.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverGutter(
      top: AvSpace.sm,
      child: AvCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Shot Replay', style: AvType.titleMedium.primary),
                const Spacer(),
                const AvPill(
                  label: 'AI tracked',
                  color: AvColors.insight,
                  dense: true,
                ),
              ],
            ),
            const SizedBox(height: AvSpace.sm),
            SizedBox(
              height: 280,
              child: ShotReplay(clip: clip),
            ),
          ],
        ),
      ),
    );
  }
}
