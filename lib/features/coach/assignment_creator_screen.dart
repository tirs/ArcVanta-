import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/drill.dart';
import '../../data/models/program.dart';
import '../../design/components/av_brand.dart';
import '../../design/components/av_button.dart';
import '../../design/components/av_layout.dart';
import '../../design/components/av_states.dart';
import '../../design/components/av_surface.dart';
import '../../state/stores.dart';
import '../../state/team.dart';

/// Assign a drill to one athlete or the whole roster, with the target and note
/// the athlete will actually see before they start.
class AssignmentCreatorScreen extends ConsumerStatefulWidget {
  const AssignmentCreatorScreen({super.key, this.athleteId});

  final String? athleteId;

  @override
  ConsumerState<AssignmentCreatorScreen> createState() =>
      _AssignmentCreatorScreenState();
}

class _AssignmentCreatorScreenState
    extends ConsumerState<AssignmentCreatorScreen> {
  final _note = TextEditingController();
  late Set<String> _selected;
  Drill? _drill;
  int _targetMakes = 50;
  int _daysToComplete = 3;

  @override
  void initState() {
    super.initState();
    _selected = {if (widget.athleteId != null) widget.athleteId!};
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _valid => _selected.isNotEmpty && _drill != null;

  void _save() {
    final roster = ref.read(rosterProvider);
    final drill = _drill!;
    final due = DateTime.now().add(Duration(days: _daysToComplete));
    final store = ref.read(assignmentStoreProvider.notifier);

    for (final id in _selected) {
      final athlete = roster.firstWhere((a) => a.id == id);
      store.add(
        Assignment(
          id: 'assign-${DateTime.now().microsecondsSinceEpoch}-$id',
          drillId: drill.id,
          drillName: drill.name,
          athleteId: athlete.id,
          athleteName: athlete.name,
          assignedBy: 'You',
          dueAt: due,
          status: AssignmentStatus.assigned,
          targetMakes: _targetMakes,
          completedMakes: 0,
          note: _note.text.trim().isEmpty
              ? drill.coachingFocus
              : _note.text.trim(),
        ),
      );
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Assigned ${drill.name} to ${_selected.length} '
          '${_selected.length == 1 ? 'athlete' : 'athletes'}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roster = ref.watch(rosterProvider);
    final drills = ref.watch(drillStoreProvider);

    if (!TeamFeatures.isAvailable) return const _AssignUnavailable();

    return AvScaffold(
      title: 'New assignment',
      subtitle: 'Pick the work, the target and the date',
      leading: const AvBackButton(),
      bottomBar: AvBottomBar(
        note: _valid
            ? null
            : Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: AvColors.textFaint,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Choose at least one athlete and a drill.',
                      style: AvType.caption.faint,
                    ),
                  ),
                ],
              ),
        children: [
          Expanded(
            child: AvButton(
              label: 'Send assignment',
              size: AvButtonSize.large,
              expand: true,
              onPressed: _valid ? _save : null,
            ),
          ),
        ],
      ),
      slivers: [
        SliverGutter(
          child: Row(
            children: [
              Expanded(
                child: Text('Athletes', style: AvType.headingSmall.primary),
              ),
              AvTextAction(
                label: _selected.length == roster.length
                    ? 'Clear all'
                    : 'Select all',
                onPressed: () => setState(() {
                  _selected = _selected.length == roster.length
                      ? <String>{}
                      : roster.map((a) => a.id).toSet();
                }),
              ),
            ],
          ),
        ),
        SliverGutter(
          top: AvSpace.sm,
          child: AvCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AvSpace.md,
              vertical: AvSpace.xs,
            ),
            child: Column(
              children: [
                for (final athlete in roster)
                  _AthletePick(
                    initials: athlete.initials,
                    name: athlete.name,
                    detail:
                        '${athlete.position.abbreviation} \u00B7 '
                        '${athlete.percentage.toStringAsFixed(0)} per cent '
                        '\u00B7 ${athlete.focusArea}',
                    color: athlete.accentColor,
                    selected: _selected.contains(athlete.id),
                    onTap: () => setState(() {
                      _selected.contains(athlete.id)
                          ? _selected.remove(athlete.id)
                          : _selected.add(athlete.id);
                    }),
                  ),
              ],
            ),
          ),
        ),
        SliverGutter(
          top: AvSpace.lg,
          child: Text('Drill', style: AvType.headingSmall.primary),
        ),
        SliverGutter(
          top: AvSpace.sm,
          child: Column(
            children: [
              for (final drill in drills.take(8))
                Padding(
                  padding: const EdgeInsets.only(bottom: AvSpace.xs),
                  child: _DrillPick(
                    drill: drill,
                    selected: _drill?.id == drill.id,
                    onTap: () => setState(() {
                      _drill = drill;
                      _targetMakes = drill.targetMakes;
                    }),
                  ),
                ),
            ],
          ),
        ),
        SliverGutter(
          top: AvSpace.lg,
          child: AvCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const AvOverline('Target makes'),
                    const Spacer(),
                    Text(
                      '$_targetMakes',
                      style: AvType.tabular(
                        AvType.metricMedium,
                      ).copyWith(color: AvColors.flare),
                    ),
                  ],
                ),
                Slider(
                  value: _targetMakes.toDouble(),
                  min: 10,
                  max: 200,
                  divisions: 19,
                  onChanged: (value) =>
                      setState(() => _targetMakes = value.round()),
                ),
                const SizedBox(height: AvSpace.xs),
                Row(
                  children: [
                    const AvOverline('Due'),
                    const Spacer(),
                    Text(
                      Fmt.fullDate(
                        DateTime.now().add(Duration(days: _daysToComplete)),
                      ),
                      style: AvType.tabular(AvType.metricSmall).primary,
                    ),
                  ],
                ),
                Slider(
                  value: _daysToComplete.toDouble(),
                  min: 1,
                  max: 14,
                  divisions: 13,
                  onChanged: (value) =>
                      setState(() => _daysToComplete = value.round()),
                ),
              ],
            ),
          ),
        ),
        SliverGutter(
          top: AvSpace.sm,
          child: AvCard(
            child: TextField(
              controller: _note,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Note to the athlete',
                hintText:
                    _drill?.coachingFocus ?? 'What should they concentrate on?',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AthletePick extends StatelessWidget {
  const _AthletePick({
    required this.initials,
    required this.name,
    required this.detail,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String initials;
  final String name;
  final String detail;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AvPressable(
      onTap: onTap,
      borderRadius: AvRadius.allSm,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AvSpace.xs),
        child: Row(
          children: [
            AvAvatar(initials: initials, color: color, size: 36),
            const SizedBox(width: AvSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AvType.titleSmall.primary),
                  Text(
                    detail,
                    style: AvType.caption.faint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AvSpace.sm),
            AnimatedContainer(
              duration: AvMotion.fast,
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selected ? AvColors.flare : Colors.transparent,
                borderRadius: AvRadius.allXs,
                border: Border.all(
                  color: selected ? AvColors.flare : AvColors.hairlineStrong,
                  width: 1.6,
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 15,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _DrillPick extends StatelessWidget {
  const _DrillPick({
    required this.drill,
    required this.selected,
    required this.onTap,
  });

  final Drill drill;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AvPressable(
      onTap: onTap,
      borderRadius: AvRadius.allMd,
      child: AnimatedContainer(
        duration: AvMotion.fast,
        padding: const EdgeInsets.all(AvSpace.md),
        decoration: BoxDecoration(
          color: selected ? AvColors.flareTint : AvColors.surface,
          borderRadius: AvRadius.allMd,
          border: Border.all(
            color: selected ? AvColors.flare : AvColors.hairline,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            AvGlyph(
              icon: drill.category.icon,
              color: drill.category.color,
              background: drill.category.color.withValues(alpha: 0.12),
              size: 38,
            ),
            const SizedBox(width: AvSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(drill.name, style: AvType.titleSmall.primary),
                  const SizedBox(height: 2),
                  Text(
                    '${drill.difficulty.label} \u00B7 '
                    '${drill.targetMakes} makes \u00B7 '
                    '${drill.estimatedMinutes} min',
                    style: AvType.caption.faint,
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: AvColors.flare,
              ),
          ],
        ),
      ),
    );
  }
}

/// Creating an assignment requires somebody to send it to. Until accounts exist the form would only ever write a note to yourself.
class _AssignUnavailable extends StatelessWidget {
  const _AssignUnavailable();

  @override
  Widget build(BuildContext context) {
    return const AvScaffold(
      title: 'New assignment',
      subtitle: 'Not available in this build',
      leading: AvBackButton(),
      slivers: [
        SliverGutter(
          child: AvUnavailableFeature(
            icon: Icons.add_task_outlined,
            headline: TeamFeatures.unavailableHeadline,
            body: TeamFeatures.unavailableBody,
            footnote: 'An assignment is a message to somebody else\'s device.',
          ),
        ),
      ],
    );
  }
}
