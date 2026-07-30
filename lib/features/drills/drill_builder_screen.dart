import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../data/models/confidence.dart';
import '../../data/models/drill.dart';
import '../../data/models/session.dart';
import '../../data/models/shot.dart';
import '../../design/charts/av_court_map.dart';
import '../../design/components/av_button.dart';
import '../../design/components/av_indicators.dart';
import '../../design/components/av_layout.dart';
import '../../design/components/av_surface.dart';
import '../../state/stores.dart';

class DrillBuilderScreen extends ConsumerStatefulWidget {
  const DrillBuilderScreen({super.key});

  @override
  ConsumerState<DrillBuilderScreen> createState() =>
      _DrillBuilderScreenState();
}

class _DrillBuilderScreenState extends ConsumerState<DrillBuilderScreen> {
  final _name = TextEditingController();
  final _focus = TextEditingController();

  DrillCategory _category = DrillCategory.accuracy;
  DrillDifficulty _difficulty = DrillDifficulty.developing;
  ShotType _shotType = ShotType.catchAndShoot;
  CameraAngle _angle = CameraAngle.side;
  final Set<CourtZone> _zones = {CourtZone.leftWing3, CourtZone.rightWing3};
  int _targetMakes = 20;
  int _targetAttempts = 40;
  int _restSeconds = 0;
  int _timeLimitMinutes = 0;
  double _successThreshold = 45;
  bool _autoProgression = true;
  final Set<String> _prompts = {'Spot complete'};

  static const _promptOptions = [
    'Spot complete',
    'Move to next spot',
    'Streak update',
    'Arc feedback',
    'Balance feedback',
    'Time remaining',
    'Rest period start',
    'Personal best alert',
  ];

  bool get _valid => _name.text.trim().length > 2 && _zones.isNotEmpty;

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _save() {
    final drill = Drill(
      id: 'custom-${DateTime.now().millisecondsSinceEpoch}',
      name: _name.text.trim(),
      summary: _focus.text.trim().isEmpty
          ? 'Custom drill across ${_zones.length} spots.'
          : _focus.text.trim(),
      category: _category,
      difficulty: _difficulty,
      zones: _zones.toList(growable: false),
      targetMakes: _targetMakes,
      targetAttempts: _targetAttempts,
      estimatedMinutes: (_targetAttempts * 0.42).round().clamp(4, 60),
      shotType: _shotType,
      coachingFocus: _focus.text.trim().isEmpty
          ? 'Repeatable release'
          : _focus.text.trim(),
      recommendedAngle: _angle,
      successThreshold: _successThreshold,
      audioPrompts: _prompts.toList(growable: false),
      restSeconds: _restSeconds,
      timeLimitSeconds: _timeLimitMinutes == 0 ? null : _timeLimitMinutes * 60,
      isCustom: true,
      autoProgression: _autoProgression,
    );

    ref.read(drillStoreProvider.notifier).addCustom(drill);
    context.pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${drill.name} saved to your library.'),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () => context.push(AppRoute.drill(drill.id)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AvScaffold(
      title: 'Custom drill',
      subtitle: 'Define the spots, targets and capture rules',
      leading: const AvBackButton(),
      bottomBar: Container(
        padding: EdgeInsets.fromLTRB(
          AvSpace.gutter,
          AvSpace.sm,
          AvSpace.gutter,
          MediaQuery.paddingOf(context).bottom + AvSpace.sm,
        ),
        decoration: const BoxDecoration(
          color: AvColors.surface,
          border: Border(top: BorderSide(color: AvColors.hairline)),
        ),
        child: AvButton(
          label: 'Save to library',
          size: AvButtonSize.large,
          expand: true,
          onPressed: _valid ? _save : null,
        ),
      ),
      slivers: [
        SliverGutter(
          child: AvCard(
            child: Column(
              children: [
                TextField(
                  controller: _name,
                  onChanged: (_) => setState(() {}),
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Drill name',
                    hintText: 'Wing three progression',
                  ),
                ),
                const SizedBox(height: AvSpace.sm),
                TextField(
                  controller: _focus,
                  onChanged: (_) => setState(() {}),
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Coaching focus',
                    hintText: 'What should the athlete concentrate on?',
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: AvSectionHeader(
            title: 'Spots',
            subtitle: '${_zones.length} selected. Tap the court to change.',
            accent: AvColors.court,
          ),
        ),
        SliverGutter(
          child: AvCard(
            child: Column(
              children: [
                AvCourtMap(
                  zones: {
                    for (final zone in _zones) zone: const ZoneRecord(0, 10),
                  },
                  minimumSample: 1000,
                  onZoneTap: (zone) => setState(() {
                    _zones.contains(zone)
                        ? _zones.remove(zone)
                        : _zones.add(zone);
                  }),
                ),
                const SizedBox(height: AvSpace.sm),
                Wrap(
                  spacing: AvSpace.xs,
                  runSpacing: AvSpace.xs,
                  children: [
                    for (final zone in CourtZone.values)
                      AvChip(
                        label: zone.shortLabel,
                        selected: _zones.contains(zone),
                        accent: zone.isThree
                            ? AvColors.insight
                            : AvColors.court,
                        onTap: () => setState(() {
                          _zones.contains(zone)
                              ? _zones.remove(zone)
                              : _zones.add(zone);
                        }),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: AvSectionHeader(
            title: 'Targets',
            accent: AvColors.flare,
          ),
        ),
        SliverGutter(
          child: AvCard(
            child: Column(
              children: [
                _Stepper(
                  label: 'Makes required',
                  value: _targetMakes,
                  min: 1,
                  max: 200,
                  step: 1,
                  color: AvColors.made,
                  onChanged: (value) => setState(() {
                    _targetMakes = value;
                    if (_targetAttempts < _targetMakes) {
                      _targetAttempts = _targetMakes;
                    }
                  }),
                ),
                const Divider(height: AvSpace.lg),
                _Stepper(
                  label: 'Attempt cap',
                  value: _targetAttempts,
                  min: _targetMakes,
                  max: 300,
                  step: 5,
                  color: AvColors.court,
                  onChanged: (value) =>
                      setState(() => _targetAttempts = value),
                ),
                const Divider(height: AvSpace.lg),
                Row(
                  children: [
                    Expanded(
                      child: Text('Pass mark',
                          style: AvType.bodySmall.secondary),
                    ),
                    Text(
                      '${_successThreshold.toStringAsFixed(0)}%',
                      style: AvType.tabular(AvType.titleMedium).primary,
                    ),
                  ],
                ),
                Slider(
                  value: _successThreshold,
                  min: 10,
                  max: 95,
                  divisions: 17,
                  onChanged: (value) =>
                      setState(() => _successThreshold = value),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: AvSectionHeader(
            title: 'Pacing',
            accent: AvColors.caution,
          ),
        ),
        SliverGutter(
          child: AvCard(
            child: Column(
              children: [
                _Stepper(
                  label: 'Rest between attempts',
                  value: _restSeconds,
                  min: 0,
                  max: 60,
                  step: 5,
                  suffix: 's',
                  color: AvColors.caution,
                  onChanged: (value) => setState(() => _restSeconds = value),
                ),
                const Divider(height: AvSpace.lg),
                _Stepper(
                  label: 'Time limit',
                  value: _timeLimitMinutes,
                  min: 0,
                  max: 45,
                  step: 1,
                  suffix: _timeLimitMinutes == 0 ? '' : ' min',
                  zeroLabel: 'None',
                  color: AvColors.miss,
                  onChanged: (value) =>
                      setState(() => _timeLimitMinutes = value),
                ),
                const Divider(height: AvSpace.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Automatic progression',
                            style: AvType.titleSmall.primary,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Raise difficulty once the pass mark is met twice.',
                            style: AvType.caption.muted,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AvSpace.sm),
                    Switch(
                      value: _autoProgression,
                      onChanged: (value) =>
                          setState(() => _autoProgression = value),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: AvSectionHeader(
            title: 'Classification',
            accent: AvColors.insight,
          ),
        ),
        SliverGutter(
          child: AvCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Category', style: AvType.label.muted),
                const SizedBox(height: AvSpace.xs),
                Wrap(
                  spacing: AvSpace.xs,
                  runSpacing: AvSpace.xs,
                  children: [
                    for (final category in DrillCategory.values)
                      AvChip(
                        label: category.label,
                        icon: category.icon,
                        accent: category.color,
                        selected: _category == category,
                        onTap: () => setState(() => _category = category),
                      ),
                  ],
                ),
                const SizedBox(height: AvSpace.md),
                Text('Difficulty', style: AvType.label.muted),
                const SizedBox(height: AvSpace.xs),
                AvSegmented<DrillDifficulty>(
                  values: DrillDifficulty.values,
                  labels:
                      DrillDifficulty.values.map((d) => d.label).toList(),
                  selected: _difficulty,
                  accent: AvColors.insight,
                  dense: true,
                  onChanged: (value) => setState(() => _difficulty = value),
                ),
                const SizedBox(height: AvSpace.md),
                Text('Shot type', style: AvType.label.muted),
                const SizedBox(height: AvSpace.xs),
                Wrap(
                  spacing: AvSpace.xs,
                  runSpacing: AvSpace.xs,
                  children: [
                    for (final type in ShotType.values)
                      AvChip(
                        label: type.label,
                        accent: AvColors.flare,
                        selected: _shotType == type,
                        onTap: () => setState(() => _shotType = type),
                      ),
                  ],
                ),
                const SizedBox(height: AvSpace.md),
                Text('Camera placement', style: AvType.label.muted),
                const SizedBox(height: AvSpace.xs),
                AvSegmented<CameraAngle>(
                  values: CameraAngle.values,
                  labels: CameraAngle.values.map((a) => a.label).toList(),
                  selected: _angle,
                  accent: AvColors.court,
                  dense: true,
                  onChanged: (value) => setState(() => _angle = value),
                ),
                const SizedBox(height: AvSpace.xs),
                Text(_angle.description, style: AvType.caption.faint),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: AvSectionHeader(
            title: 'Audio prompts',
            accent: AvColors.made,
          ),
        ),
        SliverGutter(
          child: AvCard(
            child: Wrap(
              spacing: AvSpace.xs,
              runSpacing: AvSpace.xs,
              children: [
                for (final prompt in _promptOptions)
                  AvChip(
                    label: prompt,
                    selected: _prompts.contains(prompt),
                    accent: AvColors.made,
                    onTap: () => setState(() {
                      _prompts.contains(prompt)
                          ? _prompts.remove(prompt)
                          : _prompts.add(prompt);
                    }),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.color,
    required this.onChanged,
    this.suffix = '',
    this.zeroLabel,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final String suffix;
  final String? zeroLabel;
  final Color color;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AvType.bodySmall.secondary)),
        AvIconButton(
          icon: Icons.remove_rounded,
          size: 34,
          color: color,
          tooltip: 'Decrease $label',
          onPressed: value > min
              ? () => onChanged((value - step).clamp(min, max))
              : null,
        ),
        SizedBox(
          width: 74,
          child: Text(
            value == 0 && zeroLabel != null ? zeroLabel! : '$value$suffix',
            textAlign: TextAlign.center,
            style: AvType.tabular(AvType.titleMedium).primary,
          ),
        ),
        AvIconButton(
          icon: Icons.add_rounded,
          size: 34,
          color: color,
          tooltip: 'Increase $label',
          onPressed: value < max
              ? () => onChanged((value + step).clamp(min, max))
              : null,
        ),
      ],
    );
  }
}
