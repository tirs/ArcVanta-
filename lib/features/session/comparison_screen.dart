import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/metrics/metric_catalog.dart';
import '../../data/models/confidence.dart';
import '../../data/models/session.dart';
import '../../data/models/shot.dart';
import '../../design/charts/av_shot_graphics.dart';
import '../../design/components/av_indicators.dart';
import '../../design/components/av_layout.dart';
import '../../design/components/av_surface.dart';
import '../../state/stores.dart';

/// Side-by-side comparison of two attempts. The scope calls for this as the
/// main teaching tool: a good rep and a bad rep, drawn on the same axes, with
/// the differences stated as numbers rather than left to the eye.
class ComparisonScreen extends ConsumerStatefulWidget {
  const ComparisonScreen({
    super.key,
    required this.sessionId,
    required this.shotId,
  });

  final String sessionId;
  final String shotId;

  @override
  ConsumerState<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends ConsumerState<ComparisonScreen> {
  String? _referenceId;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionByIdProvider(widget.sessionId));
    if (session == null) {
      return const AvScaffold(
        title: 'Compare',
        leading: AvBackButton(),
        slivers: [
          SliverGutter(
            top: AvSpace.xxl,
            child: AvEmptyState(
              icon: Icons.search_off_rounded,
              title: 'Session not found',
              message: 'This session is no longer stored on the device.',
            ),
          ),
        ],
      );
    }

    final subject = session.shots.firstWhere(
      (s) => s.id == widget.shotId,
      orElse: () => session.shots.first,
    );
    final reference = _resolveReference(session, subject);

    return AvScaffold(
      title: 'Compare reps',
      subtitle: session.drillName,
      leading: const AvBackButton(),
      slivers: [
        SliverGutter(
          child: AvInkCard(
            padding: const EdgeInsets.all(AvSpace.md),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ShotHeader(
                        shot: subject,
                        role: 'This rep',
                        color: AvColors.flare,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 44,
                      color: AvColors.hairlineOnInk,
                    ),
                    Expanded(
                      child: _ShotHeader(
                        shot: reference,
                        role: 'Reference',
                        color: AvColors.overlaySkeleton,
                        alignEnd: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AvSpace.md),
                AvArcDiagram(
                  shot: subject,
                  comparison: reference,
                  height: 190,
                  onInk: true,
                ),
              ],
            ),
          ),
        ),
        SliverGutter(
          top: AvSpace.md,
          child: Text(
            'Choose a reference',
            style: AvType.headingSmall.primary,
          ),
        ),
        SliverGutter(
          top: AvSpace.sm,
          child: SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                AvChip(
                  label: 'Best mechanics',
                  selected: _referenceId == null,
                  accent: AvColors.insight,
                  onTap: () => setState(() => _referenceId = null),
                ),
                for (final shot in session.shots.where((s) => s.id != subject.id))
                  Padding(
                    padding: const EdgeInsets.only(left: AvSpace.xs),
                    child: AvChip(
                      label: 'Shot ${shot.index}',
                      selected: _referenceId == shot.id,
                      accent: shot.result.color,
                      onTap: () => setState(() => _referenceId = shot.id),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SliverGutter(
          top: AvSpace.lg,
          child: AvSectionHeader(
            title: 'What changed',
            subtitle: 'Only measurements this camera placement supports',
            padding: EdgeInsets.only(bottom: AvSpace.sm),
          ),
        ),
        SliverGutter(
          child: AvCard(
            child: Column(
              children: _differenceRows(session, subject, reference),
            ),
          ),
        ),
        SliverGutter(
          top: AvSpace.sm,
          child: AvCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Phase timing', style: AvType.titleMedium.primary),
                const SizedBox(height: AvSpace.sm),
                Text('This rep', style: AvType.caption.faint),
                const SizedBox(height: 6),
                AvPhaseTimeline(phases: subject.phases),
                const SizedBox(height: AvSpace.md),
                Text('Reference', style: AvType.caption.faint),
                const SizedBox(height: 6),
                AvPhaseTimeline(phases: reference.phases),
              ],
            ),
          ),
        ),
        SliverGutter(
          top: AvSpace.sm,
          child: _TakeawayCard(subject: subject, reference: reference),
        ),
      ],
    );
  }

  Shot _resolveReference(TrainingSession session, Shot subject) {
    if (_referenceId != null) {
      for (final shot in session.shots) {
        if (shot.id == _referenceId) return shot;
      }
    }
    final candidates =
        session.attempts.where((s) => s.id != subject.id).toList(growable: false);
    if (candidates.isEmpty) return subject;
    return candidates.reduce(
      (a, b) => a.mechanicsScore >= b.mechanicsScore ? a : b,
    );
  }

  List<Widget> _differenceRows(
    TrainingSession session,
    Shot subject,
    Shot reference,
  ) {
    final angle = session.calibration.angle;
    final subjectMetrics = MetricCatalog.forShot(subject, angle: angle);
    final referenceMetrics = MetricCatalog.forShot(reference, angle: angle);

    final rows = <Widget>[];
    for (var i = 0; i < subjectMetrics.length; i++) {
      final a = subjectMetrics[i].metric;
      final b = referenceMetrics[i].metric;
      if (!a.eligibleFor(angle) ||
          a.confidence == ConfidenceLevel.unavailable) {
        continue;
      }
      if (rows.isNotEmpty) rows.add(const AvSeparator());
      rows.add(_DiffRow(subject: a, reference: b));
    }

    if (rows.isEmpty) {
      rows.add(
        AvUnavailableNotice(
          metric: 'Comparison',
          reason: '${angle.label} placement did not produce measurements at '
              'high enough confidence on both attempts to compare them.',
        ),
      );
    }
    return rows;
  }
}

class _ShotHeader extends StatelessWidget {
  const _ShotHeader({
    required this.shot,
    required this.role,
    required this.color,
    this.alignEnd = false,
  });

  final Shot shot;
  final String role;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment:
              alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Container(width: 8, height: 8, color: color),
            const SizedBox(width: 6),
            Text(
              role.toUpperCase(),
              style: AvType.overline.copyWith(color: AvColors.textOnInkMuted),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Shot ${shot.index} \u00B7 ${shot.result.label}',
          style: AvType.titleMedium.copyWith(color: AvColors.textOnInk),
        ),
        Text(
          '${shot.zone.shortLabel} \u00B7 '
          '${Fmt.clock(shot.offsetFromStart)}',
          style: AvType.caption.copyWith(color: AvColors.textOnInkMuted),
        ),
      ],
    );
  }
}

class _DiffRow extends StatelessWidget {
  const _DiffRow({required this.subject, required this.reference});

  final MetricValue subject;
  final MetricValue reference;

  @override
  Widget build(BuildContext context) {
    final delta = subject.value - reference.value;
    final meaningful = delta.abs() > (subject.targetHigh == null
        ? 0.01
        : (subject.targetHigh! - (subject.targetLow ?? 0)) * 0.06);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AvSpace.sm),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(subject.label, style: AvType.titleSmall.primary),
          ),
          Expanded(
            flex: 3,
            child: Text(
              subject.formatted,
              textAlign: TextAlign.right,
              style: AvType.tabular(AvType.metricSmall).copyWith(
                color: subject.inTarget ? AvColors.textPrimary : AvColors.caution,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              reference.formatted,
              textAlign: TextAlign.right,
              style: AvType.tabular(AvType.metricSmall)
                  .copyWith(color: AvColors.textMuted),
            ),
          ),
          const SizedBox(width: AvSpace.xs),
          SizedBox(
            width: 62,
            child: Align(
              alignment: Alignment.centerRight,
              child: meaningful
                  ? AvDelta(
                      value: delta,
                      unit: subject.unit,
                      showBackground: false,
                    )
                  : Text(
                      'Same',
                      style: AvType.caption.faint,
                      textAlign: TextAlign.right,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TakeawayCard extends StatelessWidget {
  const _TakeawayCard({required this.subject, required this.reference});

  final Shot subject;
  final Shot reference;

  @override
  Widget build(BuildContext context) {
    final kneeDelta = subject.kneeFlexion - reference.kneeFlexion;
    final holdDelta = subject.followThroughMs - reference.followThroughMs;
    final entryDelta = subject.entryAngle - reference.entryAngle;

    final takeaway = kneeDelta.abs() >= 6
        ? 'Your legs were ${kneeDelta > 0 ? 'straighter' : 'deeper'} by '
            '${kneeDelta.abs().toStringAsFixed(0)} degrees on this rep. Knee '
            'depth is the strongest predictor of arc in your data.'
        : holdDelta.abs() >= 80
            ? 'You held the follow-through '
                '${holdDelta > 0 ? 'longer' : 'shorter'} by '
                '${holdDelta.abs()} milliseconds. Your makes cluster around '
                'the longer hold.'
            : entryDelta.abs() >= 3
                ? 'Entry angle differed by '
                    '${entryDelta.abs().toStringAsFixed(0)} degrees, which is '
                    'the difference between catching the front rim and '
                    'dropping through.'
                : 'These two reps are mechanically close. The difference in '
                    'outcome came from the finish at the rim rather than the '
                    'motion.';

    return AvTintCard(
      tint: AvColors.flareTint,
      borderColor: AvColors.flareSoft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AvGlyph(
            icon: Icons.lightbulb_rounded,
            color: AvColors.flareDeep,
            background: AvColors.flareSoft,
            size: 36,
          ),
          const SizedBox(width: AvSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('The takeaway', style: AvType.titleSmall.primary),
                const SizedBox(height: 3),
                Text(takeaway, style: AvType.bodySmall.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
