import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/metrics/metric_catalog.dart';
import '../../data/models/program.dart';
import '../../data/models/session.dart';
import '../../data/models/shot.dart';
import '../../design/charts/av_court_map.dart';
import '../../design/charts/av_radar_chart.dart';
import '../../design/charts/av_shot_graphics.dart';
import '../../design/components/av_button.dart';
import '../../design/components/av_indicators.dart';
import '../../design/components/av_layout.dart';
import '../../design/components/av_stats.dart';
import '../../design/components/av_surface.dart';
import '../../state/stores.dart';
import '../shared/coaching_cue_card.dart';

/// Post-session report. Ordered the way a coach would talk through it: what
/// happened, the one thing to work on, then the evidence behind it.
class SessionSummaryScreen extends ConsumerWidget {
  const SessionSummaryScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionByIdProvider(sessionId));

    if (session == null) {
      return AvScaffold(
        title: 'Session',
        leading: const AvBackButton(),
        slivers: [
          SliverGutter(
            top: AvSpace.xxl,
            child: AvEmptyState(
              icon: Icons.search_off_rounded,
              title: 'Session not found',
              message: 'This session is no longer stored on the device.',
              action: AvButton(
                label: 'Back to history',
                variant: AvButtonVariant.outline,
                onPressed: () => context.go(AppRoute.sessions),
              ),
            ),
          ),
        ],
      );
    }

    final metrics = MetricCatalog.forSession(session);
    final angle = session.calibration.angle;

    return AvScaffold(
      title: session.drillName,
      subtitle: '${Fmt.fullDate(session.startedAt)} at '
          '${Fmt.time(session.startedAt)}',
      leading: const AvBackButton(),
      actions: [
        AvIconButton(
          icon: Icons.ios_share_rounded,
          tooltip: 'Share',
          onPressed: () => _share(context, ref, session),
        ),
      ],
      bottomBar: AvBottomBar(
        children: [
          Expanded(
            child: AvButton(
              label: 'Shot by shot',
              variant: AvButtonVariant.outline,
              size: AvButtonSize.large,
              expand: true,
              onPressed: () => context.push(AppRoute.timeline(session.id)),
            ),
          ),
          Expanded(
            child: AvButton(
              label: 'Run it again',
              size: AvButtonSize.large,
              icon: Icons.replay_rounded,
              expand: true,
              onPressed: () =>
                  context.push(AppRoute.placement(session.drillId)),
            ),
          ),
        ],
      ),
      slivers: [
        SliverGutter(child: _HeroPanel(session: session)),
        SliverGutter(
          top: AvSpace.sm,
          child: AvTileGrid(
            children: [
              AvStatTile(
                label: 'Best streak',
                value: '${session.bestStreak}',
                caption: 'consecutive makes',
                accent: AvColors.flare,
                icon: Icons.local_fire_department_rounded,
              ),
              AvStatTile(
                label: 'Mechanics',
                value: session.averageMechanics.toStringAsFixed(0),
                unit: '/100',
                caption: 'session average',
                accent: AvColors.insight,
                icon: Icons.accessibility_new_rounded,
              ),
              AvStatTile(
                label: 'Repeatability',
                value: session.consistencyScore.toStringAsFixed(0),
                unit: '/100',
                caption: 'shot to shot',
                accent: AvColors.court,
                icon: Icons.repeat_rounded,
              ),
              AvStatTile(
                label: 'Swish rate',
                value: session.swishRate.toStringAsFixed(0),
                unit: '%',
                caption: '${session.swishCount} of ${session.makeCount} makes',
                accent: AvColors.made,
                icon: Icons.sports_basketball_rounded,
              ),
            ],
          ),
        ),
        if (session.primaryCue != null) ...[
          const SliverGutter(
            top: AvSpace.lg,
            child: AvSectionHeader(
              title: 'Work on this next',
              padding: EdgeInsets.only(bottom: AvSpace.sm),
            ),
          ),
          SliverGutter(
            child: CoachingCueCard(cue: session.primaryCue!),
          ),
          for (final cue in session.cues.where(
            (c) => c.id != session.primaryCue!.id,
          ))
            SliverGutter(
              top: AvSpace.sm,
              child: CoachingCueCard(cue: cue),
            ),
        ],
        const SliverGutter(
          top: AvSpace.lg,
          child: AvSectionHeader(
            title: 'Where the shots went',
            accent: AvColors.court,
            padding: EdgeInsets.only(bottom: AvSpace.sm),
          ),
        ),
        SliverGutter(
          child: AvCard(
            child: Column(
              children: [
                AvCourtMap(
                  zones: session.zoneBreakdown,
                  shots: session.attempts,
                  mode: CourtMapMode.markers,
                ),
                const SizedBox(height: AvSpace.sm),
                const AvCourtLegend(),
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
                Text('Arrival at the rim', style: AvType.titleMedium.primary),
                const SizedBox(height: 4),
                Text(
                  'Each mark is one attempt, plotted against the centre of the '
                  'rim from above.',
                  style: AvType.caption.muted,
                ),
                const SizedBox(height: AvSpace.md),
                AvRimPlot(shots: session.attempts),
              ],
            ),
          ),
        ),
        const SliverGutter(
          top: AvSpace.lg,
          child: AvSectionHeader(
            title: 'Mechanics profile',
            subtitle: 'Session average against your personal baseline',
            accent: AvColors.insight,
            padding: EdgeInsets.only(bottom: AvSpace.sm),
          ),
        ),
        SliverGutter(
          child: AvCard(
            child: Column(
              children: [
                AvRadarChart(axes: _radarAxes(session)),
                const SizedBox(height: AvSpace.md),
                const AvSeparator(),
                const SizedBox(height: AvSpace.xs),
                for (final group in [
                  MetricGroup.arc,
                  MetricGroup.accuracy,
                  MetricGroup.mechanics,
                  MetricGroup.timing,
                ]) ...[
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AvSpace.sm,
                      bottom: 2,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AvOverline(group.label),
                    ),
                  ),
                  for (final entry in MetricCatalog.inGroup(metrics, group))
                    AvMetricRow(metric: entry.metric, angle: angle),
                ],
              ],
            ),
          ),
        ),
        if (session.bestMechanicsShot != null) ...[
          const SliverGutter(
            top: AvSpace.lg,
            child: AvSectionHeader(
              title: 'Your best rep',
              subtitle: 'Highest mechanics score of the session',
              padding: EdgeInsets.only(bottom: AvSpace.sm),
            ),
          ),
          SliverGutter(
            child: AvCard(
              onTap: () => context.push(
                AppRoute.shot(session.id, session.bestMechanicsShot!.id),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AvResultChip(
                        result: session.bestMechanicsShot!.result,
                        detail: session.bestMechanicsShot!.outcomeDetail,
                      ),
                      const SizedBox(width: AvSpace.xs),
                      Text(
                        'Shot ${session.bestMechanicsShot!.index} \u00B7 '
                        '${session.bestMechanicsShot!.zone.shortLabel}',
                        style: AvType.caption.muted,
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AvColors.textFaint,
                      ),
                    ],
                  ),
                  const SizedBox(height: AvSpace.sm),
                  AvArcDiagram(shot: session.bestMechanicsShot!),
                  const SizedBox(height: AvSpace.sm),
                  AvPhaseTimeline(phases: session.bestMechanicsShot!.phases),
                ],
              ),
            ),
          ),
        ],
        const SliverGutter(
          top: AvSpace.lg,
          child: AvSectionHeader(
            title: 'How this was measured',
            padding: EdgeInsets.only(bottom: AvSpace.sm),
          ),
        ),
        SliverGutter(child: _ProvenanceCard(session: session)),
        SliverGutter(
          top: AvSpace.sm,
          child: Row(
            children: [
              Expanded(
                child: AvButton(
                  label: 'Save highlight',
                  variant: AvButtonVariant.tonal,
                  icon: Icons.bookmark_add_rounded,
                  expand: true,
                  onPressed: () => _saveHighlight(context, ref, session),
                ),
              ),
              const SizedBox(width: AvSpace.sm),
              Expanded(
                child: AvButton(
                  label: 'Compare reps',
                  variant: AvButtonVariant.tonal,
                  icon: Icons.compare_arrows_rounded,
                  expand: true,
                  onPressed: session.bestMechanicsShot == null
                      ? null
                      : () => context.push(
                            AppRoute.compare(
                              session.id,
                              session.bestMechanicsShot!.id,
                            ),
                          ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<RadarAxis> _radarAxes(TrainingSession session) {
    final graded = session.attempts
        .where((s) => s.confidence.isAuthoritative)
        .toList(growable: false);
    if (graded.isEmpty) return const [];

    double mean(double Function(Shot) selector) =>
        graded.map(selector).reduce((a, b) => a + b) / graded.length;

    double band(double value, double low, double high) {
      final centre = (low + high) / 2;
      final span = (high - low) / 2;
      return (1 - (value - centre).abs() / (span * 2.4)).clamp(0.0, 1.0);
    }

    return [
      RadarAxis(
        label: 'Arc',
        value: band(mean((s) => s.entryAngle), 43, 50),
        baseline: 0.72,
      ),
      RadarAxis(
        label: 'Depth',
        value: band(mean((s) => s.depthCm), 0, 11),
        baseline: 0.66,
      ),
      RadarAxis(
        label: 'Alignment',
        value: band(mean((s) => s.lateralDeviationCm), -5, 5),
        baseline: 0.58,
      ),
      RadarAxis(
        label: 'Legs',
        value: band(mean((s) => s.kneeFlexion), 118, 138),
        baseline: 0.70,
      ),
      RadarAxis(
        label: 'Release',
        value: band(mean((s) => s.releaseTimeMs / 1000), 0.42, 0.68),
        baseline: 0.74,
      ),
      RadarAxis(
        label: 'Balance',
        value: (mean((s) => s.balanceScore) / 100).clamp(0.0, 1.0),
        baseline: 0.80,
      ),
    ];
  }

  void _share(BuildContext context, WidgetRef ref, TrainingSession session) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AvColors.surface,
      isScrollControlled: true,
      builder: (context) => _ShareSheet(session: session),
    );
  }

  void _saveHighlight(
    BuildContext context,
    WidgetRef ref,
    TrainingSession session,
  ) {
    ref.read(highlightStoreProvider.notifier).add(
          Highlight(
            id: 'highlight-${session.id}',
            title: '${session.bestStreak} straight \u00B7 ${session.drillName}',
            kind: HighlightKind.bestMakes,
            createdAt: DateTime.now(),
            duration: Duration(seconds: 6 * session.bestStreak.clamp(1, 8)),
            clipCount: session.bestStreak.clamp(1, 8),
            sessionId: session.id,
            visibility: HighlightVisibility.privateOnly,
            accent: AvColors.flare,
            metricsBurnedIn: true,
          ),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Highlight saved to your library')),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.session});

  final TrainingSession session;

  @override
  Widget build(BuildContext context) {
    return AvInkCard(
      padding: const EdgeInsets.all(AvSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AvSpace.xs,
            runSpacing: AvSpace.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AvPill(
                label: Fmt.duration(session.duration),
                color: AvColors.textOnInkMuted,
                icon: Icons.schedule_rounded,
                dense: true,
              ),
              AvPill(
                label: session.calibration.angle.label,
                color: AvColors.court,
                icon: Icons.videocam_rounded,
                dense: true,
              ),
              AvConfidenceBadge(
                level: session.calibration.level,
                compact: true,
                onInk: true,
              ),
            ],
          ),
          const SizedBox(height: AvSpace.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Wrap(
                  spacing: AvSpace.xl,
                  runSpacing: AvSpace.md,
                  children: [
                    AvInkStat(
                      label: 'Makes',
                      value: '${session.makeCount}',
                      unit: '/${session.attemptCount}',
                      accent: AvColors.textOnInk,
                    ),
                    AvInkStat(
                      label: 'Accuracy',
                      value: session.percentage.toStringAsFixed(0),
                      unit: '%',
                      accent: AvColors.flare,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AvSpace.sm),
              AvProgressRing(
                value: session.percentage / 100,
                size: 58,
                strokeWidth: 6,
                color: AvColors.flare,
                trackColor: AvColors.hairlineOnInk,
                child: Icon(
                  session.percentage >= 50
                      ? Icons.trending_up_rounded
                      : Icons.trending_flat_rounded,
                  color: AvColors.textOnInk,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: AvSpace.lg),
          AvOutcomeBar(
            made: session.makeCount,
            missed: session.missCount,
            uncertain: session.uncertainCount,
          ),
        ],
      ),
    );
  }
}

class _ProvenanceCard extends StatelessWidget {
  const _ProvenanceCard({required this.session});

  final TrainingSession session;

  @override
  Widget build(BuildContext context) {
    final calibration = session.calibration;
    return AvCard(
      child: Column(
        children: [
          AvKeyValue(
            label: 'Capture quality',
            value: '${(calibration.qualityScore * 100).round()} of 100',
            trailing: AvConfidenceBadge(level: calibration.level, compact: true),
          ),
          AvKeyValue(label: 'Court profile', value: calibration.courtProfile),
          AvKeyValue(
            label: 'Rim reference',
            value: '${calibration.rimHeightM.toStringAsFixed(2)} m',
          ),
          AvKeyValue(
            label: 'Frame rate',
            value: '${calibration.frameRate} fps',
          ),
          AvKeyValue(label: 'Model versions', value: session.modelVersion),
          AvKeyValue(label: 'Device', value: session.deviceName),
          AvKeyValue(
            label: 'Processing',
            value: session.processedOnDevice ? 'On device' : 'Cloud assisted',
          ),
          if (session.uncertainCount > 0) ...[
            const SizedBox(height: AvSpace.sm),
            AvUnavailableNotice(
              metric: '${session.uncertainCount} attempts were not classified',
              reason: 'The ball left the tracked area or was blocked from the '
                  'camera. These attempts are counted but excluded from '
                  'accuracy and from your trends.',
            ),
          ],
        ],
      ),
    );
  }
}

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.session});

  final TrainingSession session;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  bool _includeMechanics = true;
  bool _includeCourtMap = true;
  bool _includeVideo = false;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AvSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Share this session', style: AvType.headingSmall.primary),
            const SizedBox(height: AvSpace.xs),
            Text(
              'Choose what leaves this device. Nothing is uploaded until you '
              'confirm.',
              style: AvType.bodySmall.muted,
            ),
            const SizedBox(height: AvSpace.lg),
            _ShareToggle(
              label: 'Mechanics breakdown',
              detail: 'Joint angles, timing and balance scores',
              value: _includeMechanics,
              onChanged: (v) => setState(() => _includeMechanics = v),
            ),
            _ShareToggle(
              label: 'Court map',
              detail: 'Shot locations and zone accuracy',
              value: _includeCourtMap,
              onChanged: (v) => setState(() => _includeCourtMap = v),
            ),
            _ShareToggle(
              label: 'Video clips',
              detail: 'Raw footage of each attempt. Largest file, most '
                  'sensitive.',
              value: _includeVideo,
              onChanged: (v) => setState(() => _includeVideo = v),
            ),
            const SizedBox(height: AvSpace.md),
            AvTintCard(
              tint: AvColors.canvasSunken,
              child: Text(
                '${session.drillName} \u00B7 ${session.makeCount} of '
                '${session.attemptCount} \u00B7 '
                '${session.percentage.toStringAsFixed(0)} per cent \u00B7 '
                '${Fmt.fullDate(session.startedAt)}',
                style: AvType.caption.muted,
              ),
            ),
            const SizedBox(height: AvSpace.lg),
            Row(
              children: [
                Expanded(
                  child: AvButton(
                    label: 'Send to coach',
                    variant: AvButtonVariant.outline,
                    expand: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: AvSpace.sm),
                Expanded(
                  child: AvButton(
                    label: 'Export',
                    expand: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareToggle extends StatelessWidget {
  const _ShareToggle({
    required this.label,
    required this.detail,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String detail;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AvSpace.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AvType.titleSmall.primary),
                Text(detail, style: AvType.caption.muted),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
