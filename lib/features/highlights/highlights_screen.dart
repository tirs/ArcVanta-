import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
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

/// Clip library. Sharing is deliberately explicit: every reel shows exactly who
/// can see it, and changing that is a two-tap decision with the consequence
/// spelled out.
class HighlightsScreen extends ConsumerWidget {
  const HighlightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlights = ref.watch(highlightStoreProvider);

    return AvScaffold(
      title: 'Highlights',
      subtitle: '${highlights.length} reels stored on this device',
      leading: const AvBackButton(),
      slivers: [
        if (highlights.isEmpty)
          const SliverGutter(
            top: AvSpace.xl,
            child: AvEmptyState(
              icon: Icons.movie_creation_rounded,
              title: 'No reels yet',
              message: 'Save a highlight from any session summary and it will '
                  'appear here.',
            ),
          )
        else
          for (final highlight in highlights)
            SliverGutter(
              top: AvSpace.sm,
              child: _HighlightCard(
                highlight: highlight,
                onOpenSession: () =>
                    context.push(AppRoute.session(highlight.sessionId)),
                onVisibility: (visibility) => ref
                    .read(highlightStoreProvider.notifier)
                    .setVisibility(highlight.id, visibility),
                onDelete: () => ref
                    .read(highlightStoreProvider.notifier)
                    .remove(highlight.id),
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
                  icon: Icons.lock_rounded,
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
                        'Nothing here is public',
                        style: AvType.titleSmall.primary,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Clips stay on the device until you share them. For '
                        'accounts under sixteen, team visibility also '
                        'requires guardian approval.',
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
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({
    required this.highlight,
    required this.onOpenSession,
    required this.onVisibility,
    required this.onDelete,
  });

  final Highlight highlight;
  final VoidCallback onOpenSession;
  final ValueChanged<HighlightVisibility> onVisibility;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AvCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _ReelBackdrop(
                    accent: highlight.accent,
                    seed: highlight.id.hashCode,
                  ),
                ),
                Positioned(
                  left: AvSpace.md,
                  top: AvSpace.md,
                  child: Row(
                    children: [
                      AvPill(
                        label: highlight.kind.label,
                        color: highlight.accent,
                        icon: highlight.kind.icon,
                        filled: true,
                        dense: true,
                      ),
                      if (highlight.metricsBurnedIn) ...[
                        const SizedBox(width: AvSpace.xxs),
                        const AvPill(
                          label: 'Metrics on clip',
                          color: Colors.white,
                          dense: true,
                        ),
                      ],
                    ],
                  ),
                ),
                Center(
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                      boxShadow: AvShadow.level2,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 32,
                      color: AvColors.ink,
                    ),
                  ),
                ),
                Positioned(
                  right: AvSpace.md,
                  bottom: AvSpace.md,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AvColors.scrimStrong,
                      borderRadius: AvRadius.allXs,
                    ),
                    child: Text(
                      '${highlight.clipCount} clips \u00B7 '
                      '${Fmt.duration(highlight.duration)}',
                      style: AvType.tabular(AvType.caption)
                          .copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AvSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        highlight.title,
                        style: AvType.titleMedium.primary,
                      ),
                    ),
                    AvIconButton(
                      icon: Icons.delete_outline_rounded,
                      tooltip: 'Delete reel',
                      size: 32,
                      onPressed: onDelete,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  Fmt.relative(highlight.createdAt),
                  style: AvType.caption.faint,
                ),
                const SizedBox(height: AvSpace.md),
                const AvOverline('Who can see this'),
                const SizedBox(height: AvSpace.xs),
                Wrap(
                  spacing: AvSpace.xs,
                  runSpacing: AvSpace.xs,
                  children: [
                    for (final visibility in HighlightVisibility.values)
                      AvChip(
                        label: visibility.label,
                        icon: visibility.icon,
                        selected: highlight.visibility == visibility,
                        accent: switch (visibility) {
                          HighlightVisibility.privateOnly => AvColors.court,
                          HighlightVisibility.coachAndGuardian =>
                            AvColors.insight,
                          HighlightVisibility.team => AvColors.flare,
                        },
                        onTap: () => onVisibility(visibility),
                      ),
                  ],
                ),
                const SizedBox(height: AvSpace.md),
                Row(
                  children: [
                    Expanded(
                      child: AvButton(
                        label: 'Open session',
                        variant: AvButtonVariant.outline,
                        size: AvButtonSize.small,
                        expand: true,
                        onPressed: onOpenSession,
                      ),
                    ),
                    const SizedBox(width: AvSpace.xs),
                    Expanded(
                      child: AvButton(
                        label: 'Export',
                        variant: AvButtonVariant.tonal,
                        size: AvButtonSize.small,
                        icon: Icons.download_rounded,
                        expand: true,
                        onPressed: () =>
                            ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Rendering reel to your camera roll'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Poster frame for a reel. Drawn from the clip identity so each card is
/// distinct without shipping stock imagery.
class _ReelBackdrop extends CustomPainter {
  const _ReelBackdrop({required this.accent, required this.seed});

  final Color accent;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(AvColors.ink, accent, 0.30)!,
            AvColors.ink,
          ],
        ).createShader(rect),
    );

    final random = math.Random(seed);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.10);

    for (var i = 0; i < 5; i++) {
      final start = Offset(
        -size.width * 0.1,
        size.height * (0.2 + i * 0.18) + random.nextDouble() * 8,
      );
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(
          size.width * 0.5,
          start.dy - size.height * (0.28 + random.nextDouble() * 0.2),
          size.width * 1.1,
          start.dy - size.height * 0.05,
        );
      canvas.drawPath(path, stroke);
    }

    // Rim marker the arcs converge toward.
    final rim = Offset(size.width * 0.82, size.height * 0.34);
    canvas.drawOval(
      Rect.fromCenter(center: rim, width: 46, height: 12),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = accent.withValues(alpha: 0.85),
    );

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            AvColors.ink.withValues(alpha: 0.55),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_ReelBackdrop oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.seed != seed;
}
