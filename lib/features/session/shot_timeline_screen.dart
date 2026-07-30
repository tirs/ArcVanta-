import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/session.dart';
import '../../data/models/shot.dart';
import '../../design/components/av_button.dart';
import '../../design/components/av_indicators.dart';
import '../../design/components/av_layout.dart';
import '../../design/components/av_surface.dart';
import '../../state/stores.dart';

enum _TimelineFilter { all, makes, misses, uncertain, corrected }

extension on _TimelineFilter {
  String get label => switch (this) {
        _TimelineFilter.all => 'All',
        _TimelineFilter.makes => 'Makes',
        _TimelineFilter.misses => 'Misses',
        _TimelineFilter.uncertain => 'Uncertain',
        _TimelineFilter.corrected => 'Corrected',
      };

  bool matches(Shot shot) => switch (this) {
        _TimelineFilter.all => true,
        _TimelineFilter.makes => shot.isMake,
        _TimelineFilter.misses => shot.result == ShotResult.missed,
        _TimelineFilter.uncertain => shot.result == ShotResult.uncertain,
        _TimelineFilter.corrected => shot.correctedByUser,
      };
}

/// Every attempt in the session, in order, with the correction path the scope
/// requires: a result can be reclassified in two taps and the change is
/// recorded as a correction rather than an edit.
class ShotTimelineScreen extends ConsumerStatefulWidget {
  const ShotTimelineScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<ShotTimelineScreen> createState() =>
      _ShotTimelineScreenState();
}

class _ShotTimelineScreenState extends ConsumerState<ShotTimelineScreen> {
  _TimelineFilter _filter = _TimelineFilter.all;
  CourtZone? _zone;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionByIdProvider(widget.sessionId));
    if (session == null) {
      return const _MissingSession();
    }

    final shots = session.shots
        .where(_filter.matches)
        .where((s) => _zone == null || s.zone == _zone)
        .toList(growable: false);

    final zones = session.shots.map((s) => s.zone).toSet().toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return AvScaffold(
      title: 'Shot by shot',
      subtitle: '${session.drillName} \u00B7 ${session.attemptCount} attempts',
      leading: const AvBackButton(),
      slivers: [
        SliverGutter(
          child: AvCard(
            padding: const EdgeInsets.all(AvSpace.sm),
            child: Column(
              children: [
                Row(
                  children: [
                    for (final filter in _TimelineFilter.values) ...[
                      if (filter != _TimelineFilter.all)
                        const SizedBox(width: AvSpace.xxs),
                      Expanded(
                        child: _CountChip(
                          label: filter.label,
                          count: session.shots.where(filter.matches).length,
                          selected: _filter == filter,
                          onTap: () => setState(() => _filter = filter),
                        ),
                      ),
                    ],
                  ],
                ),
                if (zones.length > 1) ...[
                  const SizedBox(height: AvSpace.sm),
                  const AvSeparator(),
                  const SizedBox(height: AvSpace.sm),
                  SizedBox(
                    height: 30,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        AvChip(
                          label: 'Every spot',
                          selected: _zone == null,
                          onTap: () => setState(() => _zone = null),
                        ),
                        for (final zone in zones) ...[
                          const SizedBox(width: AvSpace.xs),
                          AvChip(
                            label: zone.shortLabel,
                            selected: _zone == zone,
                            accent: AvColors.court,
                            onTap: () => setState(
                              () => _zone = _zone == zone ? null : zone,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (shots.isEmpty)
          SliverGutter(
            top: AvSpace.xl,
            child: AvEmptyState(
              icon: Icons.filter_alt_off_rounded,
              title: 'Nothing matches',
              message: 'No attempts in this session match the current filter.',
              action: AvButton(
                label: 'Clear filters',
                variant: AvButtonVariant.outline,
                onPressed: () => setState(() {
                  _filter = _TimelineFilter.all;
                  _zone = null;
                }),
              ),
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
              itemCount: shots.length,
              separatorBuilder: (_, __) => const SizedBox(height: AvSpace.xs),
              itemBuilder: (context, index) => _ShotRow(
                shot: shots[index],
                session: session,
                onOpen: () => context.push(
                  AppRoute.shot(session.id, shots[index].id),
                ),
                onCorrect: (result) => ref
                    .read(sessionStoreProvider.notifier)
                    .correctShotResult(
                      sessionId: session.id,
                      shotId: shots[index].id,
                      result: result,
                    ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MissingSession extends StatelessWidget {
  const _MissingSession();

  @override
  Widget build(BuildContext context) {
    return const AvScaffold(
      title: 'Shot by shot',
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
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AvPressable(
      onTap: onTap,
      borderRadius: AvRadius.allSm,
      child: AnimatedContainer(
        duration: AvMotion.fast,
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? AvColors.ink : AvColors.canvasSunken,
          borderRadius: AvRadius.allSm,
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: AvType.tabular(AvType.metricSmall).copyWith(
                color: selected ? AvColors.textOnInk : AvColors.textPrimary,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AvType.overline.copyWith(
                fontSize: 8,
                letterSpacing: 0.5,
                color: selected
                    ? AvColors.textOnInkMuted
                    : AvColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShotRow extends StatelessWidget {
  const _ShotRow({
    required this.shot,
    required this.session,
    required this.onOpen,
    required this.onCorrect,
  });

  final Shot shot;
  final TrainingSession session;
  final VoidCallback onOpen;
  final ValueChanged<ShotResult> onCorrect;

  @override
  Widget build(BuildContext context) {
    return AvCard(
      padding: const EdgeInsets.fromLTRB(
        AvSpace.sm,
        AvSpace.sm,
        AvSpace.sm,
        AvSpace.xs,
      ),
      onTap: onOpen,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: shot.result.softColor,
                  borderRadius: AvRadius.allXs,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(shot.result.icon, size: 15, color: shot.result.color),
                    Text(
                      '${shot.index}',
                      style: AvType.tabular(AvType.overline).copyWith(
                        fontSize: 8,
                        color: shot.result.color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AvSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            shot.outcomeDetail.label,
                            style: AvType.titleSmall.primary,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (shot.correctedByUser) ...[
                          const SizedBox(width: AvSpace.xxs),
                          const AvPill(
                            label: 'Corrected',
                            color: AvColors.insight,
                            dense: true,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${shot.zone.shortLabel} \u00B7 '
                      '${Fmt.clock(shot.offsetFromStart)} \u00B7 '
                      'mechanics ${shot.mechanicsScore.toStringAsFixed(0)}',
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
                    shot.confidence.isAuthoritative
                        ? '${shot.entryAngle.toStringAsFixed(0)}\u00B0'
                        : '\u2014',
                    style: AvType.tabular(AvType.metricMedium)
                        .copyWith(fontSize: 17),
                  ),
                  Text('entry', style: AvType.caption.faint),
                ],
              ),
              const SizedBox(width: AvSpace.xs),
              AvConfidenceBadge(level: shot.confidence, compact: true),
            ],
          ),
          if (shot.result == ShotResult.uncertain) ...[
            const SizedBox(height: AvSpace.xs),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'The system could not see the outcome. Set it yourself.',
                    style: AvType.caption.muted,
                  ),
                ),
                AvTextAction(
                  label: 'Miss',
                  color: AvColors.miss,
                  onPressed: () => onCorrect(ShotResult.missed),
                ),
                const SizedBox(width: AvSpace.xs),
                AvTextAction(
                  label: 'Make',
                  color: AvColors.made,
                  onPressed: () => onCorrect(ShotResult.made),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
