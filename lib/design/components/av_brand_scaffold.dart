import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/av_colors.dart';
import '../../core/theme/av_theme.dart';
import '../../core/theme/av_tokens.dart';

/// The dark ink surface the product opens on.
///
/// Launch and the whole account-setup flow share it, so the app has one front
/// door rather than a branded splash followed by screens that look unrelated.
/// Past setup the workspace switches to the light canvas, where measurements
/// have to be read in a bright gym.
class AvBrandScaffold extends StatelessWidget {
  const AvBrandScaffold({
    super.key,
    required this.child,
    this.bottomBar,
    this.safeArea = true,
  });

  final Widget child;

  /// Pinned to the bottom, outside the scroll area, above the home indicator.
  final Widget? bottomBar;

  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    final body = Stack(
      children: [
        const Positioned.fill(child: AvBrandBackdrop()),
        if (bottomBar == null)
          child
        else
          Column(
            children: [
              Expanded(child: child),
              bottomBar!,
            ],
          ),
      ],
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AvTheme.inkOverlay,
      child: Theme(
        // Fields, checkboxes and rules carry their own colours, so the theme
        // has to follow the surface rather than each screen restyling them.
        data: AvTheme.onInk(Theme.of(context)),
        child: Scaffold(
          backgroundColor: AvColors.ink,
          body: DecoratedBox(
            decoration: const BoxDecoration(gradient: AvGradients.ink),
            child: safeArea ? SafeArea(child: body) : body,
          ),
        ),
      ),
    );
  }
}

/// Court arcs receding into the distance, lit from the corners by the two
/// brand colours. Painted rather than shipped as an image so it stays sharp at
/// any size and costs nothing to download.
class AvBrandBackdrop extends StatelessWidget {
  const AvBrandBackdrop({super.key});

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(painter: _BrandBackdropPainter());
}

class _BrandBackdropPainter extends CustomPainter {
  const _BrandBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = Colors.white.withValues(alpha: 0.045);

    final centre = Offset(size.width * 0.5, size.height * 1.06);
    for (var i = 0; i < 6; i++) {
      canvas.drawCircle(centre, size.width * (0.32 + i * 0.19), line);
    }

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.9, -0.85),
          radius: 1.1,
          colors: [
            AvColors.flare.withValues(alpha: 0.20),
            AvColors.flare.withValues(alpha: 0),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-1.0, 0.9),
          radius: 1.0,
          colors: [
            AvColors.insight.withValues(alpha: 0.22),
            AvColors.insight.withValues(alpha: 0),
          ],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_BrandBackdropPainter oldDelegate) => false;
}
