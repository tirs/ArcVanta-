import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/session.dart';
import '../../design/charts/av_line_chart.dart';
import '../../design/components/av_button.dart';
import '../../design/components/av_indicators.dart';
import '../../design/components/av_layout.dart';
import '../../design/components/av_surface.dart';
import '../../state/stores.dart';
import '../shared/session_card.dart';

enum _HistorySort { newest, accuracy, volume }

extension on _HistorySort {
  String get label => switch (this) {
    _HistorySort.newest => 'Newest',
    _HistorySort.accuracy => 'Accuracy',
    _HistorySort.volume => 'Volume',
  };
}

/// Every stored session, grouped by month, with the totals a player actually
/// checks: how much work went in and whether it is trending the right way.
class SessionHistoryScreen extends ConsumerStatefulWidget {
  const SessionHistoryScreen({super.key});

  @override
  ConsumerState<SessionHistoryScreen> createState() =>
      _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends ConsumerState<SessionHistoryScreen> {
  _HistorySort _sort = _HistorySort.newest;
  String? _drillFilter;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(sessionStoreProvider);
    final drills = {for (final s in all) s.drillId: s.drillName};

    final filtered =
        all
            .where((s) => _drillFilter == null || s.drillId == _drillFilter)
            .toList()
          ..sort(
            (a, b) => switch (_sort) {
              _HistorySort.newest => b.startedAt.compareTo(a.startedAt),
              _HistorySort.accuracy => b.percentage.compareTo(a.percentage),
              _HistorySort.volume => b.attemptCount.compareTo(a.attemptCount),
            },
          );

    final grouped = <String, List<TrainingSession>>{};
    for (final session in filtered) {
      final key = Fmt.monthYear(session.startedAt);
      grouped.putIfAbsent(key, () => []).add(session);
    }

    final totalShots = all.fold<int>(0, (sum, s) => sum + s.attemptCount);
    final totalMakes = all.fold<int>(0, (sum, s) => sum + s.makeCount);
    final totalTime = all.fold<Duration>(
      Duration.zero,
      (sum, s) => sum + s.duration,
    );

    return AvScaffold(
      title: 'Session history',
      subtitle: '${all.length} sessions stored on this device',
      leading: const AvBackButton(),
      slivers: [
        SliverGutter(
          child: AvInkCard(
            padding: const EdgeInsets.all(AvSpace.md),
            child: Column(
              children: [
                Row(
                  children: [
                    _HistoryStat(
                      label: 'Attempts',
                      value: Fmt.compactCount(totalShots),
                    ),
                    _HistoryStat(
                      label: 'Makes',
                      value: Fmt.compactCount(totalMakes),
                      accent: AvColors.made,
                    ),
                    _HistoryStat(
                      label: 'Accuracy',
                      value: totalShots == 0
                          ? '\u2014'
                          : '${(totalMakes / totalShots * 100).round()}%',
                      accent: AvColors.flare,
                    ),
                    _HistoryStat(
                      label: 'On court',
                      value: '${totalTime.inHours}h',
                    ),
                  ],
                ),
                const SizedBox(height: AvSpace.md),
                AvSparkline(
                  values: [
                    for (final session in all.reversed) session.percentage,
                  ],
                  color: AvColors.flare,
                  height: 44,
                ),
              ],
            ),
          ),
        ),
        SliverGutter(
          top: AvSpace.md,
          child: Row(
            children: [
              Expanded(
                child: AvSegmented<_HistorySort>(
                  values: _HistorySort.values,
                  labels: [for (final sort in _HistorySort.values) sort.label],
                  selected: _sort,
                  onChanged: (value) => setState(() => _sort = value),
                  dense: true,
                ),
              ),
            ],
          ),
        ),
        if (drills.length > 1)
          SliverGutter(
            top: AvSpace.sm,
            child: SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  AvChip(
                    label: 'All drills',
                    selected: _drillFilter == null,
                    onTap: () => setState(() => _drillFilter = null),
                  ),
                  for (final entry in drills.entries)
                    Padding(
                      padding: const EdgeInsets.only(left: AvSpace.xs),
                      child: AvChip(
                        label: entry.value,
                        selected: _drillFilter == entry.key,
                        accent: AvColors.court,
                        onTap: () => setState(
                          () => _drillFilter = _drillFilter == entry.key
                              ? null
                              : entry.key,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (filtered.isEmpty)
          SliverGutter(
            top: AvSpace.xl,
            child: AvEmptyState(
              icon: Icons.history_rounded,
              title: 'No sessions yet',
              message:
                  'Sessions you record are stored here, on the device, '
                  'until you choose to back them up.',
              action: AvButton(
                label: 'Browse drills',
                onPressed: () => context.go(AppRoute.train),
              ),
            ),
          )
        else
          for (final entry in grouped.entries) ...[
            SliverGutter(
              top: AvSpace.lg,
              child: Row(
                children: [
                  AvOverline(entry.key),
                  const SizedBox(width: AvSpace.sm),
                  Expanded(
                    child: Container(height: 1, color: AvColors.hairline),
                  ),
                  const SizedBox(width: AvSpace.sm),
                  Text(
                    '${entry.value.length}',
                    style: AvType.tabular(AvType.caption).faint,
                  ),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AvSpace.gutter,
                AvSpace.sm,
                AvSpace.gutter,
                0,
              ),
              sliver: SliverList.separated(
                itemCount: entry.value.length,
                separatorBuilder: (_, __) => const SizedBox(height: AvSpace.sm),
                itemBuilder: (context, index) => SessionCard(
                  session: entry.value[index],
                  onTap: () =>
                      context.push(AppRoute.session(entry.value[index].id)),
                ),
              ),
            ),
          ],
      ],
    );
  }
}

class _HistoryStat extends StatelessWidget {
  const _HistoryStat({
    required this.label,
    required this.value,
    this.accent = AvColors.textOnInk,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AvType.tabular(AvType.metricMedium).copyWith(color: accent),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: AvType.overline.copyWith(
              color: AvColors.textOnInkMuted,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}
