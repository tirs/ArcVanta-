import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/metrics/metric_catalog.dart';
import '../../data/models/program.dart';
import '../../data/store/export.dart';
import '../../data/models/session.dart';
import '../../data/models/shot.dart';
import '../../design/charts/av_court_map.dart';
import '../../design/charts/av_radar_chart.dart';
import '../../design/charts/av_shot_graphics.dart';
import '../../design/components/av_button.dart';
import '../../design/components/av_indicators.dart';
import '../../design/components/av_layout.dart';
import '../../design/components/av_states.dart';
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
    final history = ref.watch(sessionStoreProvider);

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
    final radar = _radarAxes(session, history);

    return AvScaffold(
      title: session.drillName,
      subtitle:
          '${Fmt.fullDate(session.startedAt)} at '
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
        if (session.isSimulated)
          const SliverGutter(child: AvRehearsalBanner()),
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
                caption:
                    '${session.swishCount} of '
                    '${Fmt.count(session.makeCount, 'make')}',
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
          SliverGutter(child: CoachingCueCard(cue: session.primaryCue!)),
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
        SliverGutter(
          top: AvSpace.lg,
          child: AvSectionHeader(
            title: 'Mechanics profile',
            subtitle: radar.any((a) => a.baseline != null)
                ? 'Session average against your own baseline'
                : 'Session average. A baseline appears once you have history',
            accent: AvColors.insight,
            padding: const EdgeInsets.only(bottom: AvSpace.sm),
          ),
        ),
        SliverGutter(
          child: AvCard(
            child: Column(
              children: [
                AvRadarChart(axes: radar),
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
                    padding: const EdgeInsets.only(top: AvSpace.sm, bottom: 2),
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

  /// Shots the baseline ring is drawn from.
  ///
  /// Only sessions that came before this one, so re-opening an old session
  /// shows what the athlete's form looked like at the time rather than
  /// comparing it against work they had not done yet.
  static List<Shot> _priorShots(
    List<TrainingSession> history,
    TrainingSession session,
  ) => [
    for (final past in history)
      if (past.id != session.id && past.startedAt.isBefore(session.startedAt))
        ...past.attempts.where((s) => s.confidence.isAuthoritative),
  ];

  /// The minimum history the baseline ring is allowed to be drawn from. Below
  /// this it is one warm-up's worth of shots, and a ring the athlete reads as
  /// "normal for me" should not be a single afternoon.
  static const int _minimumBaselineShots = 25;

  List<RadarAxis> _radarAxes(
    TrainingSession session,
    List<TrainingSession> history,
  ) {
    final graded = session.attempts
        .where((s) => s.confidence.isAuthoritative)
        .toList(growable: false);
    if (graded.isEmpty) return const [];

    final prior = _priorShots(history, session);
    final hasBaseline = prior.length >= _minimumBaselineShots;

    double mean(List<Shot> shots, double Function(Shot) selector) =>
        shots.map(selector).reduce((a, b) => a + b) / shots.length;

    double band(double value, double low, double high) {
      final centre = (low + high) / 2;
      final span = (high - low) / 2;
      return (1 - (value - centre).abs() / (span * 2.4)).clamp(0.0, 1.0);
    }

    RadarAxis axis(
      String label,
      double Function(Shot) selector,
      double Function(double) score,
    ) => RadarAxis(
      label: label,
      value: score(mean(graded, selector)),
      baseline: hasBaseline ? score(mean(prior, selector)) : null,
    );

    return [
      axis('Arc', (s) => s.entryAngle, (v) => band(v, 43, 50)),
      axis('Depth', (s) => s.depthCm, (v) => band(v, 0, 11)),
      axis('Alignment', (s) => s.lateralDeviationCm, (v) => band(v, -5, 5)),
      axis('Legs', (s) => s.kneeFlexion, (v) => band(v, 118, 138)),
      axis(
        'Release',
        (s) => s.releaseTimeMs / 1000,
        (v) => band(v, 0.42, 0.68),
      ),
      axis('Balance', (s) => s.balanceScore, (v) => (v / 100).clamp(0.0, 1.0)),
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
    ref
        .read(highlightStoreProvider.notifier)
        .add(
          Highlight(
            id: 'highlight-${session.id}',
            title: '${session.bestStreak} straight \u00B7 ${session.drillName}',
            kind: HighlightKind.bestMakes,
            createdAt: DateTime.now(),
            shotCount: session.bestStreak,
            sessionId: session.id,
            visibility: HighlightVisibility.privateOnly,
            accent: AvColors.flare,
          ),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved to your highlights')),
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
            trailing: AvConfidenceBadge(
              level: calibration.level,
              compact: true,
            ),
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
            value: 'On device',
          ),
          if (session.uncertainCount > 0) ...[
            const SizedBox(height: AvSpace.sm),
            AvUnavailableNotice(
              metric: session.uncertainCount == 1
                  ? '1 attempt was not classified'
                  : '${session.uncertainCount} attempts were not classified',
              reason:
                  'The ball left the tracked area or was blocked from the '
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
  bool _busy = false;

  String get _summary {
    final session = widget.session;
    return '${session.drillName} \u2014 ${session.makeCount} of '
        '${session.attemptCount} '
        '(${session.percentage.toStringAsFixed(0)}%), '
        '${Fmt.fullDate(session.startedAt)}. '
        'Measured on device with ArcVanta.';
  }

  Future<void> _shareSummary() async {
    await SharePlus.instance.share(ShareParams(text: _summary));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _shareFile() async {
    setState(() => _busy = true);
    try {
      final json = DataExport.session(
        widget.session,
        includeMechanics: _includeMechanics,
        includeShotLocations: _includeCourtMap,
        exportedAt: DateTime.now(),
      );

      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/${DataExport.sessionFileName(widget.session)}',
      );
      await file.writeAsString(json);

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: _summary),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
              'Nothing is uploaded. The file is written here and handed to '
              'whichever app you pick next.',
              style: AvType.bodySmall.muted,
            ),
            const SizedBox(height: AvSpace.lg),
            _ShareToggle(
              label: 'Mechanics breakdown',
              detail: 'Joint angles, timing and balance, shot by shot',
              value: _includeMechanics,
              onChanged: (v) => setState(() => _includeMechanics = v),
            ),
            _ShareToggle(
              label: 'Shot locations',
              detail: 'Where each attempt was taken from, and how far it missed',
              value: _includeCourtMap,
              onChanged: (v) => setState(() => _includeCourtMap = v),
            ),
            const SizedBox(height: AvSpace.md),
            AvTintCard(
              tint: AvColors.canvasSunken,
              child: Text(_summary, style: AvType.caption.muted),
            ),
            const SizedBox(height: AvSpace.lg),
            Row(
              children: [
                Expanded(
                  child: AvButton(
                    label: 'Summary only',
                    variant: AvButtonVariant.outline,
                    expand: true,
                    onPressed: _busy ? null : _shareSummary,
                  ),
                ),
                const SizedBox(width: AvSpace.sm),
                Expanded(
                  child: AvButton(
                    label: 'Share file',
                    icon: Icons.ios_share_rounded,
                    expand: true,
                    onPressed: _busy ? null : _shareFile,
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
