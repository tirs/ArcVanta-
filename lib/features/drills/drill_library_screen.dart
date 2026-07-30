import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../data/models/drill.dart';
import '../../design/components/av_button.dart';
import '../../design/components/av_indicators.dart';
import '../../design/components/av_layout.dart';
import '../../design/components/av_surface.dart';
import '../../state/stores.dart';
import 'drill_tile.dart';

class DrillLibraryScreen extends ConsumerStatefulWidget {
  const DrillLibraryScreen({super.key});

  @override
  ConsumerState<DrillLibraryScreen> createState() => _DrillLibraryScreenState();
}

class _DrillLibraryScreenState extends ConsumerState<DrillLibraryScreen> {
  DrillCategory? _category;
  DrillDifficulty? _difficulty;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final drills = ref.watch(drillStoreProvider);
    final filtered = drills
        .where((drill) {
          if (_category != null && drill.category != _category) return false;
          if (_difficulty != null && drill.difficulty != _difficulty) {
            return false;
          }
          if (_query.isEmpty) return true;
          final q = _query.toLowerCase();
          return drill.name.toLowerCase().contains(q) ||
              drill.summary.toLowerCase().contains(q) ||
              drill.coachingFocus.toLowerCase().contains(q);
        })
        .toList(growable: false);

    return AvScaffold(
      title: 'Train',
      subtitle: '${drills.length} drills, each with its own capture rules',
      actions: [
        AvIconButton(
          icon: Icons.add_rounded,
          tooltip: 'Build a custom drill',
          onPressed: () => context.push(AppRoute.drillBuilder),
        ),
      ],
      slivers: [
        SliverGutter(
          child: TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Search drills and focus areas',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Clear search',
                      onPressed: () => setState(() => _query = ''),
                    ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: AvSpace.sm),
            child: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: AvSpace.gutter),
                children: [
                  AvChip(
                    label: 'All',
                    selected: _category == null,
                    accent: AvColors.ink,
                    count: drills.length,
                    onTap: () => setState(() => _category = null),
                  ),
                  for (final category in DrillCategory.values) ...[
                    const SizedBox(width: AvSpace.xs),
                    AvChip(
                      label: category.label,
                      icon: category.icon,
                      accent: category.color,
                      selected: _category == category,
                      count: drills.where((d) => d.category == category).length,
                      onTap: () => setState(
                        () =>
                            _category = _category == category ? null : category,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AvSpace.gutter,
              AvSpace.sm,
              AvSpace.gutter,
              0,
            ),
            child: Row(
              children: [
                Text('Difficulty', style: AvType.caption.faint),
                const SizedBox(width: AvSpace.xs),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        for (final level in DrillDifficulty.values) ...[
                          AvChip(
                            label: level.label,
                            selected: _difficulty == level,
                            accent: AvColors.insight,
                            onTap: () => setState(
                              () => _difficulty = _difficulty == level
                                  ? null
                                  : level,
                            ),
                          ),
                          const SizedBox(width: AvSpace.xs),
                        ],
                      ],
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
              icon: Icons.search_off_rounded,
              title: 'No drills match those filters',
              message:
                  'Clear the filters or build a custom drill with the exact '
                  'spots, targets and movement pattern you need.',
              action: AvButton(
                label: 'Build a custom drill',
                icon: Icons.add_rounded,
                onPressed: () => context.push(AppRoute.drillBuilder),
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
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: AvSpace.sm),
              itemBuilder: (context, index) => DrillTile(
                drill: filtered[index],
                onTap: () => context.push(AppRoute.drill(filtered[index].id)),
                onStart: () =>
                    context.push(AppRoute.placement(filtered[index].id)),
              ),
            ),
          ),
        SliverGutter(
          top: AvSpace.xl,
          child: AvCard(
            color: AvColors.insightTint,
            border: Border.all(color: AvColors.insight.withValues(alpha: 0.22)),
            child: Row(
              children: [
                const AvGlyph(
                  icon: Icons.build_rounded,
                  color: AvColors.insight,
                  size: 44,
                ),
                const SizedBox(width: AvSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Custom drill builder',
                        style: AvType.titleMedium.primary,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Define spots, targets, time limits, rest, movement '
                        'pattern, audio prompts and automatic progression.',
                        style: AvType.bodySmall.secondary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AvSpace.xs),
                AvIconButton(
                  icon: Icons.arrow_forward_rounded,
                  tooltip: 'Open builder',
                  onPressed: () => context.push(AppRoute.drillBuilder),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
