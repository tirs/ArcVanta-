import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/painters/gym_scene_painter.dart';
import '../../state/capture_pipeline.dart';

/// The camera surface the analysis overlay is composited onto.
///
/// The native capture pipeline publishes a platform texture; this widget is the
/// single place that texture is mounted so every screen that shows a preview
/// (placement guide, calibration, live session) shares identical geometry,
/// aspect handling and rounding.
///
/// With no texture there is no camera, and the widget falls back to a
/// schematic court. It does not label itself: both screens that mount it have
/// their own, roomier disclosure, and a badge stacked on top of those reads as
/// a fault rather than as candour.
class CameraStage extends ConsumerWidget {
  const CameraStage({
    super.key,
    this.brightness = 0.86,
    this.indoor = true,
    this.overlay,
    this.borderRadius,
  });

  final double brightness;
  final bool indoor;
  final Widget? overlay;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = Stack(
      fit: StackFit.expand,
      children: [
        ValueListenableBuilder<int?>(
          valueListenable: ref.watch(previewTextureProvider),
          builder: (context, texture, _) => texture == null
              ? CustomPaint(
                  painter: GymScenePainter(
                    brightness: brightness,
                    indoor: indoor,
                  ),
                )
              : Texture(
                  textureId: texture,
                  filterQuality: FilterQuality.medium,
                ),
        ),
        if (overlay != null) overlay!,
      ],
    );

    if (borderRadius == null) return content;
    return ClipRRect(borderRadius: borderRadius!, child: content);
  }
}
