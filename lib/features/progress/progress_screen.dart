import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/progress.dart';
import '../../data/models/session.dart';
import '../../data/models/shot.dart';
import '../../design/charts/av_bar_chart.dart';
import '../../design/charts/av_line_chart.dart';
import '../../design/components/av_button.dart';
import '../../design/components/av_indicators.dart';
import '../../design/components/av_layout.dart';
import '../../design/components/av_stats.dart';
import '../../design/components/av_surface.dart';
import '../../state/stores.dart';

enum _TrendMetric { accuracy, mechanics, consistency, entryAngle, volume }

extension on _TrendMetric {
  String get label => switch (this) {
    _TrendMetric.accuracy => 'Accuracy',
    _TrendMetric.mechanics => 'Mechanics',
    _TrendMetric.consistency => 'Repeatability',
    _TrendMetric.entryAngle => 'Entry angle',
    _TrendMetric.volume => 'Volume',
  };

  String get unit => switch (this) {
    _TrendMetric.accuracy => '%',
    _TrendMetric.mechanics => '',
    _TrendMetric.consistency => '',
    _TrendMetric.entryAngle => '\u00B0',
    _TrendMetric.volume => '',
  };

  Color get color => switch (this) {
    _TrendMetric.accuracy => AvColors.flare,
    _TrendMetric.mechanics => AvColors.insight,
    _TrendMetric.consistency => AvColors.court,
    _TrendMetric.entryAngle => AvColors.made,
    _TrendMetric.volume => AvColors.caution,
  };

  double? get target => switch (this) {
    _TrendMetric.accuracy => 45,
    _TrendMetric.mechanics => 88,
    _TrendMetric.consistency => 80,
    _TrendMetric.entryAngle => 45,
    _TrendMetric.volume => null,
  };

  double read(ProgressPoint point) => switch (this) {
    _TrendMetric.accuracy => point.percentage,
    _TrendMetric.mechanics => point.mechanicsScore,
    _TrendMetric.consistency => point.consistencyScore,
    _TrendMetric.entryAngle => point.averageEntryAngle,
    _TrendMetric.volume => point.attempts.toDouble(),
  };
}

/// Long-range view of whether training is working. Every headline number is
/// paired with an explanation of what moved it, because a change in camera
/// placement can look exactly like a change in skill.
class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  TrendRange _range = TrendRange.month;
  _TrendMetric _metric = _TrendMetric.accuracy;

  @override
  Widget build(BuildContext context) {
    final points = ref.watch(progressProvider(_range));
    final records = ref.watch(personalRecordsProvider);
    final explanations = ref.watch(trendExplanationsProvider);
    final sessions = ref.watch(sessionStoreProvider);

    // Every panel below is a reading of recorded work. With nothing recorded
    // the page is a grid of zeros and blank axes, which reads like a bug
    // rather than a starting point.
    if (sessions.isEmpty) return _awaitingHistory(context);

    final trained = points.where((p) => p.trained).toList(growable: false);
    final values = [for (final p in trained) _metric.read(p)];
    final labels = _axisLabels(trained);

    return AvScaffold(
      title: 'Progress',
      subtitle: 'What has actually changed, and why',
      actions: [
        AvIconButton(
          icon: Icons.grid_on_rounded,
          tooltip: 'Court heatmap',
          onPressed: () => context.push(AppRoute.heatmap),
        ),
        AvIconButton(
          icon: Icons.history_rounded,
          tooltip: 'Session history',
          onPressed: () => context.push(AppRoute.sessions),
        ),
      ],
      slivers: [
        SliverGutter(
          child: AvSegmented<TrendRange>(
            values: TrendRange.values,
            labels: [for (final r in TrendRange.values) r.label],
            selected: _range,
            onChanged: (value) => setState(() => _range = value),
          ),
        ),
        SliverGutter(
          top: AvSpace.md,
          child: _SummaryPanel(points: trained, range: _range),
        ),
        SliverGutter(
          top: AvSpace.md,
          child: SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final metric in _TrendMetric.values)
                  Padding(
                    padding: EdgeInsets.only(
                      left: metric == _TrendMetric.accuracy ? 0 : AvSpace.xs,
                    ),
                    child: AvChip(
                      label: metric.label,
                      selected: _metric == metric,
                      accent: metric.color,
                      onTap: () => setState(() => _metric = metric),
                    ),
                  ),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _metric.label,
                        style: AvType.titleMedium.primary,
                      ),
                    ),
                    if (values.length >= 4)
                      AvDelta(
                        value: _changeOverRange(values),
                        unit: _metric.unit,
                      ),
                  ],
                ),
                const SizedBox(height: AvSpace.md),
                if (values.length < 2)
                  const AvUnavailableNotice(
                    metric: 'Trend line',
                    reason:
                        'At least two sessions inside this range are '
                        'needed before a trend means anything.',
                  )
                else
                  AvLineChart(
                    series: [
                      ChartSeries(
                        label: _metric.label,
                        values: values,
                        color: _metric.color,
                      ),
                    ],
                    xLabels: labels,
                    yUnit: _metric.unit,
                    targetLine: _metric.target,
                    targetLabel: _metric.target == null ? null : 'Target',
                  ),
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
                Text('Work volume', style: AvType.titleMedium.primary),
                const SizedBox(height: 4),
                Text(
                  'Attempts per session across the range.',
                  style: AvType.caption.muted,
                ),
                const SizedBox(height: AvSpace.md),
                AvColumnChart(
                  values: [
                    for (final point in trained) point.attempts.toDouble(),
                  ],
                  labels: labels,
                  color: AvColors.canvasSunken,
                  highlightColor: AvColors.flare,
                  highlightIndex: trained.isEmpty ? null : trained.length - 1,
                ),
              ],
            ),
          ),
        ),
        const SliverGutter(
          top: AvSpace.lg,
          child: AvSectionHeader(
            title: 'Why these numbers moved',
            subtitle: 'Performance change separated from setup change',
            accent: AvColors.insight,
            padding: EdgeInsets.only(bottom: AvSpace.sm),
          ),
        ),
        for (final explanation in explanations)
          SliverGutter(
            top: AvSpace.xs,
            child: _ExplanationCard(explanation: explanation),
          ),
        const SliverGutter(
          top: AvSpace.lg,
          child: AvSectionHeader(
            title: 'Accuracy by spot',
            accent: AvColors.court,
            padding: EdgeInsets.only(bottom: AvSpace.sm),
          ),
        ),
        SliverGutter(
          child: AvCard(
            child: Column(
              children: [
                AvBarList(
                  data: _zoneBars(sessions),
                  maxValue: 100,
                  valueSuffix: '%',
                ),
                const SizedBox(height: AvSpace.sm),
                AvButton(
                  label: 'Open full court map',
                  variant: AvButtonVariant.tonal,
                  icon: Icons.map_rounded,
                  expand: true,
                  onPressed: () => context.push(AppRoute.heatmap),
                ),
              ],
            ),
          ),
        ),
        const SliverGutter(
          top: AvSpace.lg,
          child: AvSectionHeader(
            title: 'Personal records',
            accent: AvColors.made,
            padding: EdgeInsets.only(bottom: AvSpace.sm),
          ),
        ),
        SliverGutter(
          child: AvTileGrid(
            aspectRatio: 1.25,
            children: [
              for (final record in records) _RecordTile(record: record),
            ],
          ),
        ),
        SliverGutter(
          top: AvSpace.lg,
          child: AvTintCard(
            tint: AvColors.courtTint,
            borderColor: AvColors.courtSoft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AvGlyph(
                  icon: Icons.shield_moon_rounded,
                  color: AvColors.courtDeep,
                  background: AvColors.courtSoft,
                  size: 36,
                ),
                const SizedBox(width: AvSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trends exclude low-confidence work',
                        style: AvType.titleSmall.primary,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Sessions recorded handheld, in poor light or with a '
                        'partial court view are stored and visible, but they '
                        'never move a trend line.',
                        style: AvType.caption.muted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _awaitingHistory(BuildContext context) {
    return AvScaffold(
      title: 'Progress',
      subtitle: 'What has actually changed, and why',
      slivers: [
        SliverGutter(
          top: AvSpace.lg,
          child: AvEmptyState(
            icon: Icons.timeline_rounded,
            title: 'Nothing to compare yet',
            message:
                'Trends need at least two recorded sessions. Run one, then '
                'another, and this page will show what moved between them.',
            action: AvButton(
              label: 'Start a session',
              icon: Icons.play_arrow_rounded,
              onPressed: () => context.go(AppRoute.drills),
            ),
          ),
        ),
      ],
    );
  }

  double _changeOverRange(List<double> values) {
    if (values.length < 4) return 0;
    final half = values.length ~/ 2;
    final early = values.take(half).reduce((a, b) => a + b) / half;
    final late =
        values.skip(half).reduce((a, b) => a + b) / (values.length - half);
    return late - early;
  }

  List<String> _axisLabels(List<ProgressPoint> points) {
    if (points.isEmpty) return const [];
    final step = (points.length / 5).ceil().clamp(1, points.length);
    return [
      for (var i = 0; i < points.length; i++)
        i % step == 0 || i == points.length - 1 ? Fmt.date(points[i].date) : '',
    ];
  }

  List<BarDatum> _zoneBars(List<TrainingSession> sessions) {
    final totals = <CourtZone, (int makes, int attempts)>{};
    for (final session in sessions) {
      session.zoneBreakdown.forEach((zone, record) {
        final existing = totals[zone] ?? (0, 0);
        totals[zone] = (
          existing.$1 + record.makes,
          existing.$2 + record.attempts,
        );
      });
    }

    final bars = <BarDatum>[];
    totals.forEach((zone, value) {
      if (value.$2 < 4) return;
      final percentage = value.$1 / value.$2 * 100;
      bars.add(
        BarDatum(
          label: zone.shortLabel,
          value: percentage,
          color: percentage >= 45
              ? AvColors.made
              : percentage >= 33
              ? AvColors.caution
              : AvColors.miss,
          caption: '${value.$1}/${value.$2}',
        ),
      );
    });
    bars.sort((a, b) => b.value.compareTo(a.value));
    return bars;
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.points, required this.range});

  final List<ProgressPoint> points;
  final TrendRange range;

  @override
  Widget build(BuildContext context) {
    final attempts = points.fold<int>(0, (sum, p) => sum + p.attempts);
    final makes = points.fold<int>(0, (sum, p) => sum + p.makes);
    final accuracy = attempts == 0 ? 0.0 : makes / attempts * 100;
    final mechanics = points.isEmpty
        ? 0.0
        : points.map((p) => p.mechanicsScore).reduce((a, b) => a + b) /
              points.length;

    return AvInkCard(
      padding: const EdgeInsets.all(AvSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'LAST ${range.label.toUpperCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AvType.overline.copyWith(
                    color: AvColors.textOnInkMuted,
                  ),
                ),
              ),
              const SizedBox(width: AvSpace.xs),
              AvPill(
                label: Fmt.count(points.length, 'session'),
                color: AvColors.textOnInkMuted,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: AvSpace.md),
          Wrap(
            spacing: AvSpace.xl,
            runSpacing: AvSpace.md,
            children: [
              AvInkStat(
                label: 'Accuracy',
                value: accuracy.toStringAsFixed(0),
                unit: '%',
                accent: AvColors.flare,
              ),
              AvInkStat(
                label: 'Attempts',
                value: Fmt.compactCount(attempts),
                accent: AvColors.textOnInk,
              ),
              AvInkStat(
                label: 'Mechanics',
                value: mechanics.toStringAsFixed(0),
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

class _ExplanationCard extends StatelessWidget {
  const _ExplanationCard({required this.explanation});

  final TrendExplanation explanation;

  @override
  Widget build(BuildContext context) {
    final setupShare = (explanation.attributedToSetup * 100).round();

    return AvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  explanation.metric,
                  style: AvType.titleMedium.primary,
                ),
              ),
              AvDelta(value: explanation.change),
            ],
          ),
          const SizedBox(height: AvSpace.xs),
          Text(explanation.summary, style: AvType.bodySmall.muted),
          const SizedBox(height: AvSpace.sm),
          for (final factor in explanation.contributingFactors)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: SizedBox(
                      width: 5,
                      height: 5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AvColors.insight,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AvSpace.sm),
                  Expanded(child: Text(factor, style: AvType.caption.muted)),
                ],
              ),
            ),
          const SizedBox(height: AvSpace.sm),
          const AvSeparator(),
          const SizedBox(height: AvSpace.sm),
          Row(
            children: [
              Icon(
                setupShare >= 30
                    ? Icons.warning_amber_rounded
                    : Icons.verified_rounded,
                size: 15,
                color: setupShare >= 30 ? AvColors.caution : AvColors.made,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  setupShare == 0
                      ? 'None of this movement is explained by camera setup.'
                      : '$setupShare per cent of this movement is explained '
                            'by camera setup rather than performance.',
                  style: AvType.caption.muted,
                ),
              ),
              const SizedBox(width: AvSpace.xs),
              Text(
                'n=${explanation.sampleSize}',
                style: AvType.tabular(AvType.caption).faint,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record});

  final PersonalRecord record;

  @override
  Widget build(BuildContext context) {
    return AvCard(
      padding: const EdgeInsets.all(AvSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  record.label.toUpperCase(),
                  style: AvType.overline.copyWith(color: AvColors.textMuted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (record.verified)
                const Icon(
                  Icons.verified_rounded,
                  size: 14,
                  color: AvColors.made,
                ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                record.value,
                style: AvType.tabular(
                  AvType.metricLarge,
                ).copyWith(fontSize: 26),
              ),
              Text(record.unit, style: AvType.caption.muted),
            ],
          ),
          Text(
            '${record.context} \u00B7 ${Fmt.relative(record.achievedAt)}',
            style: AvType.caption.faint,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
