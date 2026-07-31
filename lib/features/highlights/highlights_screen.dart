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

/// Saved moments from past sessions.
///
/// A highlight marks a stretch of a session worth returning to; it is a
/// bookmark into recorded measurements, not a rendered video, because this
/// build does not write video files. Visibility is still shown on every card,
/// so the rule stays visible for when sharing does exist.
class HighlightsScreen extends ConsumerWidget {
  const HighlightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlights = ref.watch(highlightStoreProvider);

    return AvScaffold(
      title: 'Highlights',
      subtitle: '${highlights.length} saved on this device',
      leading: const AvBackButton(),
      slivers: [
        if (highlights.isEmpty)
          const SliverGutter(
            top: AvSpace.xl,
            child: AvEmptyState(
              icon: Icons.bookmark_added_rounded,
              title: 'Nothing saved yet',
              message:
                  'Mark a moment from any session summary and it will wait '
                  'for you here.',
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
                        'A highlight is a bookmark into a session, not a video '
                        'clip. It stays on this device, and sending one to a '
                        'coach needs an account service this build does not '
                        'include.',
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
    required this.onDelete,
  });

  final Highlight highlight;
  final VoidCallback onOpenSession;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AvCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AvPressable(
            onTap: onOpenSession,
            semanticLabel: 'Open the session behind ${highlight.title}',
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _HighlightBackdrop(
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
                      // Opens the session behind the highlight. It is not a
                      // player: this build stores measurements, not footage.
                      child: const Icon(
                        Icons.insights_rounded,
                        size: 30,
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
                        Fmt.count(highlight.shotCount, 'shot'),
                        style: AvType.tabular(
                          AvType.caption,
                        ).copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
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
                      tooltip: 'Delete highlight',
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
                Row(
                  children: [
                    const AvPill(
                      label: 'Only you',
                      color: AvColors.court,
                      icon: Icons.lock_rounded,
                      dense: true,
                    ),
                    const SizedBox(width: AvSpace.xs),
                    Expanded(
                      child: Text(
                        'Sharing a highlight with anyone else needs an account '
                        'service this build does not include.',
                        style: AvType.caption.faint,
                      ),
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

/// Card artwork, drawn from the highlight's own identity so each one is
/// distinct without shipping stock imagery.
class _HighlightBackdrop extends CustomPainter {
  const _HighlightBackdrop({required this.accent, required this.seed});

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
          colors: [Color.lerp(AvColors.ink, accent, 0.30)!, AvColors.ink],
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
          colors: [Colors.transparent, AvColors.ink.withValues(alpha: 0.55)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_HighlightBackdrop oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.seed != seed;
}
