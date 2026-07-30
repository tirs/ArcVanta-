import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';

/// The standard content container: white surface, hairline edge, warm shadow.
class AvCard extends StatelessWidget {
  const AvCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AvSpace.md),
    this.borderRadius = AvRadius.allMd,
    this.color = AvColors.surface,
    this.border,
    this.shadows = AvShadow.level1,
    this.onTap,
    this.clip = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color color;
  final BoxBorder? border;
  final List<BoxShadow> shadows;
  final VoidCallback? onTap;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        border: border ?? Border.all(color: AvColors.hairline, width: 1),
        boxShadow: shadows,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        clipBehavior: clip ? Clip.antiAlias : Clip.none,
        child: Padding(padding: padding, child: child),
      ),
    );

    if (onTap == null) return content;

    return AvPressable(
      onTap: onTap,
      borderRadius: borderRadius,
      child: content,
    );
  }
}

/// Deep indigo panel used for hero content, scoreboards and focus moments.
class AvInkCard extends StatelessWidget {
  const AvInkCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AvSpace.lg),
    this.borderRadius = AvRadius.allLg,
    this.gradient = AvGradients.ink,
    this.onTap,
    this.showCourtLines = true,
    this.accent = AvColors.flare,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Gradient gradient;
  final VoidCallback? onTap;
  final bool showCourtLines;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final content = DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: borderRadius,
        boxShadow: AvShadow.onInk,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          children: [
            if (showCourtLines)
              Positioned.fill(
                child: CustomPaint(painter: _CourtArcPainter(accent: accent)),
              ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );

    if (onTap == null) return content;
    return AvPressable(
      onTap: onTap,
      borderRadius: borderRadius,
      child: content,
    );
  }
}

/// Draws the faint three-point arc and key lines that give ink panels their
/// court identity without adding visual noise.
class _CourtArcPainter extends CustomPainter {
  const _CourtArcPainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.05);

    final center = Offset(size.width * 0.86, size.height * 1.16);
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(center, size.height * (0.62 + i * 0.26), line);
    }

    final glow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              accent.withValues(alpha: 0.22),
              accent.withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.94, -size.height * 0.1),
              radius: size.height * 1.1,
            ),
          );
    canvas.drawRect(Offset.zero & size, glow);
  }

  @override
  bool shouldRepaint(_CourtArcPainter oldDelegate) =>
      oldDelegate.accent != accent;
}

/// Soft tinted panel used to group supporting information.
class AvTintCard extends StatelessWidget {
  const AvTintCard({
    super.key,
    required this.child,
    required this.tint,
    this.padding = const EdgeInsets.all(AvSpace.md),
    this.borderRadius = AvRadius.allMd,
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final Color tint;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: borderRadius,
        border: Border.all(
          color: borderColor ?? Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: child,
    );
    if (onTap == null) return content;
    return AvPressable(
      onTap: onTap,
      borderRadius: borderRadius,
      child: content,
    );
  }
}

/// Press feedback used across the product: a subtle scale plus opacity change
/// that respects the reduced-motion accessibility setting.
class AvPressable extends StatefulWidget {
  const AvPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.borderRadius = AvRadius.allMd,
    this.scale = 0.978,
    this.semanticLabel,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius borderRadius;
  final double scale;
  final String? semanticLabel;
  final bool enabled;

  @override
  State<AvPressable> createState() => _AvPressableState();
}

class _AvPressableState extends State<AvPressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final active = widget.enabled && widget.onTap != null;
    return Semantics(
      button: true,
      enabled: active,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: active ? (_) => setState(() => _down = true) : null,
        onTapUp: active ? (_) => setState(() => _down = false) : null,
        onTapCancel: active ? () => setState(() => _down = false) : null,
        onTap: active ? widget.onTap : null,
        onLongPress: active ? widget.onLongPress : null,
        child: AnimatedScale(
          scale: _down && !reduceMotion ? widget.scale : 1,
          duration: AvMotion.fast,
          curve: AvMotion.enter,
          child: AnimatedOpacity(
            opacity: active ? (_down ? 0.88 : 1) : 0.5,
            duration: AvMotion.fast,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Thin decorative rule with a coloured leading segment. Used under section
/// headings to carry the brand without adding another block of colour.
class AvRule extends StatelessWidget {
  const AvRule({super.key, this.accent = AvColors.flare, this.width = 28});

  final Color accent;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 2,
      child: Row(
        children: [
          Container(
            width: width,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: AvRadius.pill,
            ),
          ),
          const Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(color: AvColors.hairline),
            ),
          ),
        ],
      ),
    );
  }
}

/// Repeating diagonal hatch used behind empty or inactive regions.
class AvHatch extends StatelessWidget {
  const AvHatch({
    super.key,
    required this.child,
    this.color = AvColors.hairline,
    this.spacing = 9,
  });

  final Widget child;
  final Color color;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HatchPainter(color: color, spacing: spacing),
      child: child,
    );
  }
}

class _HatchPainter extends CustomPainter {
  const _HatchPainter({required this.color, required this.spacing});

  final Color color;
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final total = size.width + size.height;
    for (var x = -size.height; x < total; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HatchPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.spacing != spacing;
}

/// Circular container for a leading glyph. Keeps icon treatment consistent.
class AvGlyph extends StatelessWidget {
  const AvGlyph({
    super.key,
    required this.icon,
    required this.color,
    this.background,
    this.size = 40,
    this.iconSize,
    this.shape = BoxShape.circle,
  });

  final IconData icon;
  final Color color;
  final Color? background;
  final double size;
  final double? iconSize;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.12),
        shape: shape,
        borderRadius: shape == BoxShape.rectangle ? AvRadius.allSm : null,
      ),
      child: Icon(icon, color: color, size: iconSize ?? size * 0.5),
    );
  }
}

/// A compact numeric ring used for goal and target completion.
class AvProgressRing extends StatelessWidget {
  const AvProgressRing({
    super.key,
    required this.value,
    this.size = 56,
    this.strokeWidth = 6,
    this.color = AvColors.flare,
    this.trackColor = AvColors.hairline,
    this.child,
  });

  final double value;
  final double size;
  final double strokeWidth;
  final Color color;
  final Color trackColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          value: value.clamp(0, 1),
          strokeWidth: strokeWidth,
          color: color,
          trackColor: trackColor,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
  });

  final double value;
  final double strokeWidth;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inset = rect.deflate(strokeWidth / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawArc(inset, 0, math.pi * 2, false, track);

    if (value <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [color.withValues(alpha: 0.65), color],
      ).createShader(inset);
    canvas.drawArc(inset, -math.pi / 2, math.pi * 2 * value, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
