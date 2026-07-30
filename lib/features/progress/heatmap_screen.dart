import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../data/models/session.dart';
import '../../data/models/shot.dart';
import '../../design/charts/av_court_map.dart';
import '../../design/components/av_indicators.dart';
import '../../design/components/av_layout.dart';
import '../../design/components/av_stats.dart';
import '../../design/components/av_surface.dart';
import '../../state/stores.dart';

enum _HeatWindow { recent, month, all }

extension on _HeatWindow {
  String get label => switch (this) {
        _HeatWindow.recent => 'Last 5',
        _HeatWindow.month => '30 days',
        _HeatWindow.all => 'All time',
      };
}

/// Full-court shot chart. Zones below the reliability threshold are drawn as
/// unavailable rather than coloured from two or three attempts.
class HeatmapScreen extends ConsumerStatefulWidget {
  const HeatmapScreen({super.key});

  @override
  ConsumerState<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends ConsumerState<HeatmapScreen> {
  _HeatWindow _window = _HeatWindow.month;
  CourtMapMode _mode = CourtMapMode.heat;
  ShotType? _type;
  CourtZone? _selected;

  @override
  Widget build(BuildContext context) {
    final sessions = _sessionsInWindow(ref.watch(sessionStoreProvider));
    final shots = [
      for (final session in sessions)
        for (final shot in session.attempts)
          if (_type == null || shot.type == _type) shot,
    ];

    final zones = <CourtZone, ZoneRecord>{};
    for (final shot in shots) {
      final existing = zones[shot.zone] ?? const ZoneRecord(0, 0);
      zones[shot.zone] = ZoneRecord(
        existing.makes + (shot.isMake ? 1 : 0),
        existing.attempts + 1,
      );
    }

    final types = shots.map((s) => s.type).toSet().toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return AvScaffold(
      title: 'Court map',
      subtitle: '${shots.length} attempts across ${sessions.length} sessions',
      leading: const AvBackButton(),
      slivers: [
        SliverGutter(
          child: AvSegmented<_HeatWindow>(
            values: _HeatWindow.values,
            labels: [for (final w in _HeatWindow.values) w.label],
            selected: _window,
            onChanged: (value) => setState(() => _window = value),
          ),
        ),
        SliverGutter(
          top: AvSpace.sm,
          child: AvSegmented<CourtMapMode>(
            values: CourtMapMode.values,
            labels: const ['Zone accuracy', 'Every attempt'],
            selected: _mode,
            accent: AvColors.court,
            onChanged: (value) => setState(() => _mode = value),
            dense: true,
          ),
        ),
        if (types.length > 1)
          SliverGutter(
            top: AvSpace.sm,
            child: SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  AvChip(
                    label: 'Every shot type',
                    selected: _type == null,
                    onTap: () => setState(() => _type = null),
                  ),
                  for (final type in types)
                    Padding(
                      padding: const EdgeInsets.only(left: AvSpace.xs),
                      child: AvChip(
                        label: type.label,
                        selected: _type == type,
                        accent: AvColors.insight,
                        onTap: () => setState(
                          () => _type = _type == type ? null : type,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        SliverGutter(
          top: AvSpace.md,
          child: AvCard(
            child: Column(
              children: [
                AvCourtMap(
                  zones: zones,
                  shots: shots,
                  mode: _mode,
                  selectedZone: _selected,
                  onZoneTap: (zone) => setState(
                    () => _selected = _selected == zone ? null : zone,
                  ),
                ),
                const SizedBox(height: AvSpace.sm),
                const AvCourtLegend(),
              ],
            ),
          ),
        ),
        if (_selected != null)
          SliverGutter(
            top: AvSpace.sm,
            child: _ZoneDetail(
              zone: _selected!,
              record: zones[_selected!] ?? const ZoneRecord(0, 0),
              shots: shots.where((s) => s.zone == _selected).toList(),
            ),
          ),
        const SliverGutter(
          top: AvSpace.lg,
          child: AvSectionHeader(
            title: 'Strongest and weakest',
            padding: EdgeInsets.only(bottom: AvSpace.sm),
          ),
        ),
        SliverGutter(child: _RankedZones(zones: zones)),
        SliverGutter(
          top: AvSpace.md,
          child: AvUnavailableNotice(
            metric: 'Zones with fewer than four attempts',
            reason: 'A percentage from two or three shots is noise. Those '
                'zones stay grey until there is enough evidence to colour '
                'them honestly.',
          ),
        ),
      ],
    );
  }

  List<TrainingSession> _sessionsInWindow(List<TrainingSession> all) {
    final sorted = [...all]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return switch (_window) {
      _HeatWindow.recent => sorted.take(5).toList(growable: false),
      _HeatWindow.month => sorted
          .where(
            (s) => DateTime.now().difference(s.startedAt).inDays <= 30,
          )
          .toList(growable: false),
      _HeatWindow.all => sorted,
    };
  }
}

class _ZoneDetail extends StatelessWidget {
  const _ZoneDetail({
    required this.zone,
    required this.record,
    required this.shots,
  });

  final CourtZone zone;
  final ZoneRecord record;
  final List<Shot> shots;

  @override
  Widget build(BuildContext context) {
    final graded =
        shots.where((s) => s.confidence.isAuthoritative).toList(growable: false);

    double mean(double Function(Shot) selector) => graded.isEmpty
        ? 0
        : graded.map(selector).reduce((a, b) => a + b) / graded.length;

    return AvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(zone.label, style: AvType.headingSmall.primary),
              ),
              AvPill(
                label: zone.isThree ? 'Three' : 'Two',
                color: zone.isThree ? AvColors.insight : AvColors.court,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: AvSpace.md),
          Row(
            children: [
              Expanded(
                child: AvStatTile(
                  label: 'Accuracy',
                  value: record.attempts < 4
                      ? '\u2014'
                      : record.percentage.toStringAsFixed(0),
                  unit: record.attempts < 4 ? null : '%',
                  caption: '${record.makes} of ${record.attempts}',
                  accent: AvColors.flare,
                ),
              ),
              const SizedBox(width: AvSpace.sm),
              Expanded(
                child: AvStatTile(
                  label: 'Entry angle',
                  value: graded.isEmpty
                      ? '\u2014'
                      : mean((s) => s.entryAngle).toStringAsFixed(0),
                  unit: graded.isEmpty ? null : '\u00B0',
                  caption: 'target 43 to 50',
                  accent: AvColors.court,
                ),
              ),
              const SizedBox(width: AvSpace.sm),
              Expanded(
                child: AvStatTile(
                  label: 'Drift',
                  value: graded.isEmpty
                      ? '\u2014'
                      : mean((s) => s.lateralDeviationCm).toStringAsFixed(0),
                  unit: graded.isEmpty ? null : ' cm',
                  caption: 'left is negative',
                  accent: AvColors.insight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RankedZones extends StatelessWidget {
  const _RankedZones({required this.zones});

  final Map<CourtZone, ZoneRecord> zones;

  @override
  Widget build(BuildContext context) {
    final eligible = zones.entries
        .where((e) => e.value.attempts >= 4)
        .toList()
      ..sort((a, b) => b.value.percentage.compareTo(a.value.percentage));

    if (eligible.isEmpty) {
      return const AvEmptyState(
        icon: Icons.query_stats_rounded,
        title: 'Not enough evidence yet',
        message: 'Record at least four attempts from a spot and it will be '
            'ranked here.',
      );
    }

    final best = eligible.take(3).toList(growable: false);
    final worst = eligible.reversed.take(3).toList(growable: false);

    return AvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AvOverline('Best spots'),
          const SizedBox(height: AvSpace.xs),
          for (final entry in best)
            _ZoneRow(zone: entry.key, record: entry.value, positive: true),
          const SizedBox(height: AvSpace.md),
          const AvSeparator(),
          const SizedBox(height: AvSpace.md),
          const AvOverline('Needs work'),
          const SizedBox(height: AvSpace.xs),
          for (final entry in worst)
            _ZoneRow(zone: entry.key, record: entry.value, positive: false),
        ],
      ),
    );
  }
}

class _ZoneRow extends StatelessWidget {
  const _ZoneRow({
    required this.zone,
    required this.record,
    required this.positive,
  });

  final CourtZone zone;
  final ZoneRecord record;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            positive
                ? Icons.arrow_circle_up_rounded
                : Icons.arrow_circle_down_rounded,
            size: 16,
            color: positive ? AvColors.made : AvColors.miss,
          ),
          const SizedBox(width: AvSpace.sm),
          Expanded(child: Text(zone.label, style: AvType.titleSmall.primary)),
          Text(
            '${record.makes}/${record.attempts}',
            style: AvType.tabular(AvType.caption).faint,
          ),
          const SizedBox(width: AvSpace.sm),
          SizedBox(
            width: 44,
            child: Text(
              '${record.percentage.toStringAsFixed(0)}%',
              textAlign: TextAlign.right,
              style: AvType.tabular(AvType.metricSmall).copyWith(
                color: positive ? AvColors.made : AvColors.miss,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
