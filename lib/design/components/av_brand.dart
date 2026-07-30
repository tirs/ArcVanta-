import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';

/// The product mark: a rising shot arc closing on the ball.
class AvLogoMark extends StatelessWidget {
  const AvLogoMark({
    super.key,
    this.size = 44,
    this.onInk = false,
    this.progress = 1,
  });

  final double size;
  final bool onInk;

  /// Draws the arc partially, used by the launch sequence.
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: onInk ? null : AvGradients.ink,
        color: onInk ? Colors.white.withValues(alpha: 0.10) : null,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: onInk
            ? Border.all(color: Colors.white.withValues(alpha: 0.16))
            : null,
        boxShadow: onInk ? null : AvShadow.level2,
      ),
      child: CustomPaint(painter: _MarkPainter(progress: progress.clamp(0, 1))),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(w * 0.20, h * 0.76)
      ..cubicTo(w * 0.24, h * 0.24, w * 0.66, h * 0.16, w * 0.80, h * 0.44);

    final metrics = path.computeMetrics().toList();
    if (metrics.isNotEmpty) {
      final metric = metrics.first;
      final drawn = metric.extractPath(0, metric.length * progress);
      canvas.drawPath(
        drawn,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.075
          ..strokeCap = StrokeCap.round
          ..shader = const LinearGradient(
            colors: [Color(0xFFFFB27A), AvColors.flare],
          ).createShader(Offset.zero & size),
      );
    }

    final ballCentre = Offset(w * 0.735, h * 0.665);
    final ballRadius = w * 0.135;
    canvas.drawCircle(
      ballCentre,
      ballRadius,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF8A4C), AvColors.flareDeep],
        ).createShader(Rect.fromCircle(center: ballCentre, radius: ballRadius)),
    );

    final seam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.024
      ..color = Colors.white.withValues(alpha: 0.75);
    canvas.drawLine(
      ballCentre - Offset(ballRadius, 0),
      ballCentre + Offset(ballRadius, 0),
      seam,
    );
    canvas.drawArc(
      Rect.fromCircle(center: ballCentre, radius: ballRadius * 1.55),
      -math.pi * 0.78,
      math.pi * 0.56,
      false,
      seam,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Wordmark used in headers and the launch screen.
class AvWordmark extends StatelessWidget {
  const AvWordmark({super.key, this.fontSize = 20, this.onInk = false});

  final double fontSize;
  final bool onInk;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: AvType.displayMedium.copyWith(
          fontSize: fontSize,
          letterSpacing: -0.6,
          color: onInk ? AvColors.textOnInk : AvColors.textPrimary,
        ),
        children: [
          const TextSpan(text: 'ArcVanta'),
          TextSpan(
            text: ' AI',
            style: TextStyle(color: AvColors.flare),
          ),
        ],
      ),
    );
  }
}

/// Compact lockup of mark plus wordmark.
class AvBrandLockup extends StatelessWidget {
  const AvBrandLockup({
    super.key,
    this.markSize = 38,
    this.fontSize = 19,
    this.onInk = false,
    this.tagline,
  });

  final double markSize;
  final double fontSize;
  final bool onInk;
  final String? tagline;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AvLogoMark(size: markSize, onInk: onInk),
        const SizedBox(width: AvSpace.sm),
        // The mark keeps its size; the name gives way, because a squeezed
        // wordmark still reads and a clipped one does not.
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: AvWordmark(fontSize: fontSize, onInk: onInk),
              ),
              if (tagline != null)
                Text(
                  tagline!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AvType.overline.copyWith(
                    color: onInk ? AvColors.textOnInkMuted : AvColors.textFaint,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Circular athlete avatar built from initials and a personal accent colour.
class AvAvatar extends StatelessWidget {
  const AvAvatar({
    super.key,
    required this.initials,
    required this.color,
    this.size = 42,
    this.ring = false,
    this.badge,
  });

  final String initials;
  final Color color;
  final double size;
  final bool ring;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(color, Colors.white, 0.30)!,
            Color.lerp(color, Colors.black, 0.18)!,
          ],
        ),
        shape: BoxShape.circle,
        border: ring ? Border.all(color: Colors.white, width: 2.4) : null,
        boxShadow: ring ? AvShadow.glow(color) : null,
      ),
      child: Text(
        initials,
        style: AvType.headingSmall.copyWith(
          color: Colors.white,
          fontSize: size * 0.36,
          letterSpacing: 0,
        ),
      ),
    );

    if (badge == null) return avatar;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(bottom: -2, right: -2, child: badge!),
      ],
    );
  }
}
