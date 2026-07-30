import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../data/models/profile.dart';
import '../../design/components/av_brand.dart';
import '../../design/components/av_brand_scaffold.dart';
import '../../design/components/av_button.dart';
import '../../design/components/av_indicators.dart';
import '../../design/components/av_layout.dart';
import '../../design/components/av_surface.dart';
import '../../state/app_settings.dart';

class PlayerSetupScreen extends ConsumerStatefulWidget {
  const PlayerSetupScreen({super.key});

  @override
  ConsumerState<PlayerSetupScreen> createState() => _PlayerSetupScreenState();
}

class _PlayerSetupScreenState extends ConsumerState<PlayerSetupScreen> {
  final _name = TextEditingController(text: 'Nova Reyes');
  String _ageBand = '16 to 17';
  DominantHand _hand = DominantHand.right;
  PlayerPosition _position = PlayerPosition.shootingGuard;
  SkillLevel _skill = SkillLevel.advanced;
  double _height = 185;
  double _wingspan = 191;
  int _availability = 5;
  final Set<String> _goals = {
    'Raise three-point accuracy',
    'Improve shot consistency',
  };

  static const _ageBands = [
    'Under 12',
    '12 to 13',
    '14 to 15',
    '16 to 17',
    '18 to 22',
    '23 and over',
  ];

  static const _goalOptions = [
    'Raise three-point accuracy',
    'Improve shot consistency',
    'Extend shooting range',
    'Shoot better off the dribble',
    'Hold form through fatigue',
    'Improve free throws',
    'Faster release',
    'Better landing balance',
  ];

  bool get _isMinor => _ageBand != '18 to 22' && _ageBand != '23 and over';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AvColors.flare;

    return AvBrandScaffold(
      child: Column(
        children: [
          AvPageHeader(
            onInk: true,
            title: 'Player profile',
            subtitle: 'Used to set fair targets and age-appropriate defaults.',
            leading: AvBackButton(
              onInk: true,
              onPressed: () => context.go(AppRoute.role),
            ),
          ),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AvSpace.gutter,
                AvSpace.xs,
                AvSpace.gutter,
                AvSpace.md,
              ),
              children: [
                AvInkCard(
                  raised: true,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          AvAvatar(
                            initials: _initials(_name.text),
                            color: accent,
                            size: 58,
                          ),
                          const SizedBox(width: AvSpace.md),
                          Expanded(
                            child: TextField(
                              controller: _name,
                              onChanged: (_) => setState(() {}),
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Display name',
                                hintText: 'Name or alias',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AvSpace.sm),
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 15,
                            color: AvColors.textOnInkMuted,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'An alias is fine. Nothing is public by default.',
                              style: AvType.caption.onInkMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AvSpace.md),
                _Section(
                  title: 'Age band',
                  child: Wrap(
                    spacing: AvSpace.xs,
                    runSpacing: AvSpace.xs,
                    children: [
                      for (final band in _ageBands)
                        AvChip(
                          label: band,
                          selected: _ageBand == band,
                          accent: AvColors.court,
                          onInk: true,
                          onTap: () => setState(() => _ageBand = band),
                        ),
                    ],
                  ),
                ),
                if (_isMinor) ...[
                  const SizedBox(height: AvSpace.sm),
                  AvInkCard(
                    raised: true,
                    accent: AvColors.caution,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.family_restroom_rounded,
                          size: 18,
                          color: AvColors.caution,
                        ),
                        const SizedBox(width: AvSpace.xs),
                        Expanded(
                          child: Text(
                            'A guardian will need to approve this account before '
                            'coach access, cloud review or any sharing is enabled.',
                            style: AvType.bodySmall.onInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AvSpace.md),
                _Section(
                  title: 'Shooting hand',
                  child: AvSegmented<DominantHand>(
                    values: DominantHand.values,
                    labels: DominantHand.values
                        .map((h) => '${h.label} handed')
                        .toList(),
                    selected: _hand,
                    accent: AvColors.flare,
                    onInk: true,
                    onChanged: (value) => setState(() => _hand = value),
                  ),
                ),
                const SizedBox(height: AvSpace.md),
                _Section(
                  title: 'Position',
                  child: Wrap(
                    spacing: AvSpace.xs,
                    runSpacing: AvSpace.xs,
                    children: [
                      for (final position in PlayerPosition.values)
                        AvChip(
                          label: position.label,
                          selected: _position == position,
                          accent: AvColors.insight,
                          onInk: true,
                          onTap: () => setState(() => _position = position),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AvSpace.md),
                _Section(
                  title: 'Experience level',
                  child: AvSegmented<SkillLevel>(
                    values: SkillLevel.values,
                    labels: SkillLevel.values.map((s) => s.label).toList(),
                    selected: _skill,
                    accent: AvColors.made,
                    dense: true,
                    onInk: true,
                    onChanged: (value) => setState(() => _skill = value),
                  ),
                ),
                const SizedBox(height: AvSpace.md),
                _Section(
                  title: 'Measurements',
                  child: Column(
                    children: [
                      _SliderRow(
                        label: 'Height',
                        value: _height,
                        min: 130,
                        max: 225,
                        suffix: 'cm',
                        color: AvColors.court,
                        onChanged: (value) => setState(() => _height = value),
                      ),
                      const SizedBox(height: AvSpace.sm),
                      _SliderRow(
                        label: 'Wingspan',
                        value: _wingspan,
                        min: 130,
                        max: 240,
                        suffix: 'cm',
                        color: AvColors.insight,
                        onChanged: (value) => setState(() => _wingspan = value),
                      ),
                      const SizedBox(height: AvSpace.xs),
                      Text(
                        'Used to scale release height and jump estimates. '
                        'Both are optional and can be edited later.',
                        style: AvType.caption.onInkMuted,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AvSpace.md),
                _Section(
                  title: 'Training goals',
                  subtitle: 'Pick up to three. Plans are built around these.',
                  child: Wrap(
                    spacing: AvSpace.xs,
                    runSpacing: AvSpace.xs,
                    children: [
                      for (final goal in _goalOptions)
                        AvChip(
                          label: goal,
                          selected: _goals.contains(goal),
                          accent: AvColors.flare,
                          onInk: true,
                          onTap: () => setState(() {
                            if (_goals.contains(goal)) {
                              _goals.remove(goal);
                            } else if (_goals.length < 3) {
                              _goals.add(goal);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AvSpace.md),
                _Section(
                  title: 'Weekly availability',
                  child: Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _availability.toDouble(),
                          min: 1,
                          max: 7,
                          divisions: 6,
                          label: '$_availability days',
                          onChanged: (value) =>
                              setState(() => _availability = value.round()),
                        ),
                      ),
                      SizedBox(
                        width: 66,
                        child: Text(
                          '$_availability days',
                          textAlign: TextAlign.right,
                          style: AvType.tabular(AvType.titleMedium).onInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AvSpace.gutter,
              AvSpace.sm,
              AvSpace.gutter,
              AvSpace.lg,
            ),
            child: AvButton(
              label: _isMinor ? 'Continue to guardian consent' : 'Finish setup',
              size: AvButtonSize.large,
              expand: true,
              trailingIcon: Icons.arrow_forward_rounded,
              onPressed: () {
                if (_isMinor) {
                  context.go(AppRoute.guardianConsent);
                } else {
                  ref.read(appSettingsProvider.notifier).completeOnboarding();
                  context.go(AppRoute.home);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'AV';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AvInkCard(
      raised: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AvType.titleMedium.onInk),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: AvType.caption.onInkMuted),
          ],
          const SizedBox(height: AvSpace.sm),
          child,
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String suffix;
  final Color color;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 74,
          child: Text(label, style: AvType.bodySmall.onInkMuted),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(activeTrackColor: color),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: (max - min).round(),
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 62,
          child: Text(
            '${value.round()} $suffix',
            textAlign: TextAlign.right,
            style: AvType.tabular(AvType.titleSmall).onInk,
          ),
        ),
      ],
    );
  }
}
