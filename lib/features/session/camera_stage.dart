import 'package:flutter/material.dart';

import '../../design/painters/gym_scene_painter.dart';

/// The camera surface the analysis overlay is composited onto.
///
/// The native capture pipeline publishes a platform texture; this widget is the
/// single place that texture is mounted so every screen that shows a preview
/// (placement guide, calibration, live session) shares identical geometry,
/// aspect handling and rounding. Until a texture is attached it renders the
/// tracked scene so layout, overlay alignment and contrast can be verified.
class CameraStage extends StatelessWidget {
  const CameraStage({
    super.key,
    this.textureId,
    this.brightness = 0.86,
    this.indoor = true,
    this.overlay,
    this.borderRadius,
  });

  /// Platform texture identifier published by the native capture session.
  final int? textureId;

  final double brightness;
  final bool indoor;
  final Widget? overlay;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final content = Stack(
      fit: StackFit.expand,
      children: [
        if (textureId != null)
          Texture(textureId: textureId!, filterQuality: FilterQuality.medium)
        else
          CustomPaint(
            painter: GymScenePainter(brightness: brightness, indoor: indoor),
          ),
        if (overlay != null) overlay!,
      ],
    );

    if (borderRadius == null) return content;
    return ClipRRect(borderRadius: borderRadius!, child: content);
  }
}
