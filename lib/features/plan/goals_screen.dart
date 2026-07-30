import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/program.dart';
import '../../design/components/av_button.dart';
import '../../design/components/av_indicators.dart';
import '../../design/components/av_layout.dart';
import '../../design/components/av_surface.dart';
import '../../state/stores.dart';

/// Goals the athlete or coach has set, with an honest read on whether each one
/// is on pace given the time left.
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalStoreProvider);
    final active = goals.where((g) => !g.achieved).toList(growable: false);
    final achieved = goals.where((g) => g.achieved).toList(growable: false);

    return AvScaffold(
      title: 'Goals',
      subtitle: '${active.length} active \u00B7 ${achieved.length} achieved',
      leading: const AvBackButton(),
      bottomBar: AvBottomBar(
        children: [
          Expanded(
            child: AvButton(
              label: 'Set a new goal',
              size: AvButtonSize.large,
              icon: Icons.add_rounded,
              expand: true,
              onPressed: () => _createGoal(context, ref),
            ),
          ),
        ],
      ),
      slivers: [
        if (goals.isEmpty)
          const SliverGutter(
            top: AvSpace.xl,
            child: AvEmptyState(
              icon: Icons.flag_rounded,
              title: 'No goals set',
              message:
                  'A goal gives the training plan something to aim at. '
                  'Pick one number and a date.',
            ),
          ),
        if (active.isNotEmpty) ...[
          const SliverGutter(
            child: AvSectionHeader(
              title: 'In progress',
              padding: EdgeInsets.only(bottom: AvSpace.sm),
            ),
          ),
          for (final goal in active)
            SliverGutter(
              top: AvSpace.xs,
              child: _GoalCard(
                goal: goal,
                onDelete: () =>
                    ref.read(goalStoreProvider.notifier).remove(goal.id),
              ),
            ),
        ],
        if (achieved.isNotEmpty) ...[
          const SliverGutter(
            top: AvSpace.lg,
            child: AvSectionHeader(
              title: 'Achieved',
              accent: AvColors.made,
              padding: EdgeInsets.only(bottom: AvSpace.sm),
            ),
          ),
          for (final goal in achieved)
            SliverGutter(
              top: AvSpace.xs,
              child: _GoalCard(
                goal: goal,
                onDelete: () =>
                    ref.read(goalStoreProvider.notifier).remove(goal.id),
              ),
            ),
        ],
      ],
    );
  }

  void _createGoal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AvColors.surface,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: _GoalComposer(
          onSubmit: (goal) {
            ref.read(goalStoreProvider.notifier).add(goal);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.onDelete});

  final Goal goal;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final daysLeft = goal.dueAt.difference(DateTime.now()).inDays;
    final onPace = goal.progress >= 0.5 || daysLeft > 14;

    return AvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvGlyph(
                icon: goal.kind.icon,
                color: goal.kind.color,
                background: goal.kind.color.withValues(alpha: 0.12),
                size: 40,
              ),
              const SizedBox(width: AvSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.title, style: AvType.titleMedium.primary),
                    const SizedBox(height: 2),
                    Text(
                      'Set by ${goal.setBy} \u00B7 due '
                      '${Fmt.relative(goal.dueAt)}',
                      style: AvType.caption.faint,
                    ),
                  ],
                ),
              ),
              if (goal.achieved)
                const AvPill(
                  label: 'Achieved',
                  color: AvColors.made,
                  icon: Icons.check_rounded,
                  dense: true,
                )
              else
                AvIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Remove goal',
                  size: 32,
                  onPressed: onDelete,
                ),
            ],
          ),
          const SizedBox(height: AvSpace.sm),
          Text(goal.detail, style: AvType.bodySmall.muted),
          const SizedBox(height: AvSpace.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        goal.current.toStringAsFixed(
                          goal.current.truncateToDouble() == goal.current
                              ? 0
                              : 1,
                        ),
                        style: AvType.tabular(
                          AvType.metricLarge,
                        ).copyWith(fontSize: 28, color: goal.kind.color),
                      ),
                      Text(goal.unit, style: AvType.caption.muted),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AvSpace.sm),
              Text(
                'target ${goal.target.toStringAsFixed(0)}${goal.unit}',
                style: AvType.tabular(AvType.caption).faint,
              ),
            ],
          ),
          const SizedBox(height: AvSpace.xs),
          AvMeter(value: goal.progress, color: goal.kind.color),
          const SizedBox(height: AvSpace.sm),
          Row(
            children: [
              Icon(
                onPace ? Icons.trending_up_rounded : Icons.schedule_rounded,
                size: 14,
                color: onPace ? AvColors.made : AvColors.caution,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  goal.achieved
                      ? 'Hit on ${Fmt.fullDate(goal.dueAt)}.'
                      : daysLeft <= 0
                      ? 'Past the target date. Set a new one or adjust '
                            'the number.'
                      : onPace
                      ? '$daysLeft days left and on pace at the '
                            'current rate.'
                      : '$daysLeft days left. This needs a step up in '
                            'volume to land.',
                  style: AvType.caption.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalComposer extends StatefulWidget {
  const _GoalComposer({required this.onSubmit});

  final ValueChanged<Goal> onSubmit;

  @override
  State<_GoalComposer> createState() => _GoalComposerState();
}

class _GoalComposerState extends State<_GoalComposer> {
  GoalKind _kind = GoalKind.percentage;
  double _target = 45;
  int _weeks = 4;

  String get _unit => switch (_kind) {
    GoalKind.percentage => '%',
    GoalKind.volume => ' shots',
    GoalKind.mechanics => '/100',
    GoalKind.consistency => '/100',
    GoalKind.streak => ' in a row',
  };

  (double min, double max) get _bounds => switch (_kind) {
    GoalKind.percentage => (25, 70),
    GoalKind.volume => (200, 4000),
    GoalKind.mechanics => (70, 98),
    GoalKind.consistency => (60, 98),
    GoalKind.streak => (3, 25),
  };

  String get _title => switch (_kind) {
    GoalKind.percentage => 'Shoot ${_target.round()} per cent from the field',
    GoalKind.volume => 'Put up ${_target.round()} tracked attempts',
    GoalKind.mechanics => 'Hold a mechanics score of ${_target.round()}',
    GoalKind.consistency => 'Reach ${_target.round()} on repeatability',
    GoalKind.streak => 'Make ${_target.round()} in a row',
  };

  @override
  void didUpdateWidget(covariant _GoalComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _clampTarget();
  }

  void _clampTarget() {
    final (min, max) = _bounds;
    _target = _target.clamp(min, max);
  }

  @override
  Widget build(BuildContext context) {
    final (min, max) = _bounds;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AvSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Set a goal', style: AvType.headingSmall.primary),
            const SizedBox(height: AvSpace.xs),
            Text(
              'One number, one date. Goals that track a single measurement '
              'are the ones that get hit.',
              style: AvType.bodySmall.muted,
            ),
            const SizedBox(height: AvSpace.lg),
            const AvOverline('What to improve'),
            const SizedBox(height: AvSpace.xs),
            Wrap(
              spacing: AvSpace.xs,
              runSpacing: AvSpace.xs,
              children: [
                for (final kind in GoalKind.values)
                  AvChip(
                    label: kind.label,
                    icon: kind.icon,
                    selected: _kind == kind,
                    accent: kind.color,
                    onTap: () => setState(() {
                      _kind = kind;
                      _clampTarget();
                    }),
                  ),
              ],
            ),
            const SizedBox(height: AvSpace.lg),
            Row(
              children: [
                const AvOverline('Target'),
                const Spacer(),
                Text(
                  '${_target.round()}$_unit',
                  style: AvType.tabular(
                    AvType.metricMedium,
                  ).copyWith(color: _kind.color),
                ),
              ],
            ),
            Slider(
              value: _target,
              min: min,
              max: max,
              divisions: ((max - min) / (max > 100 ? 100 : 1)).round(),
              activeColor: _kind.color,
              onChanged: (value) => setState(() => _target = value),
            ),
            const SizedBox(height: AvSpace.xs),
            Row(
              children: [
                const AvOverline('Deadline'),
                const Spacer(),
                Text(
                  '$_weeks weeks',
                  style: AvType.tabular(AvType.metricSmall).primary,
                ),
              ],
            ),
            Slider(
              value: _weeks.toDouble(),
              min: 1,
              max: 16,
              divisions: 15,
              activeColor: _kind.color,
              onChanged: (value) => setState(() => _weeks = value.round()),
            ),
            const SizedBox(height: AvSpace.md),
            AvTintCard(
              tint: AvColors.canvasSunken,
              child: Text(_title, style: AvType.titleSmall.primary),
            ),
            const SizedBox(height: AvSpace.lg),
            AvButton(
              label: 'Save goal',
              size: AvButtonSize.large,
              expand: true,
              onPressed: () => widget.onSubmit(
                Goal(
                  id: 'goal-${DateTime.now().millisecondsSinceEpoch}',
                  kind: _kind,
                  title: _title,
                  detail:
                      'Tracked automatically from every session recorded '
                      'at medium confidence or better.',
                  current: 0,
                  target: _target,
                  unit: _unit,
                  dueAt: DateTime.now().add(Duration(days: _weeks * 7)),
                  setBy: 'You',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
