import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/capture/live_scene.dart';

/// Renders the tracked scene behind the analysis overlay.
///
/// On a device this sits beneath the native camera texture. It is drawn rather
/// than shipped as artwork so the geometry matches the coordinates the overlay
/// uses for the rim, backboard and floor plane, and so the composition scales
/// to any preview aspect ratio.
class GymScenePainter extends CustomPainter {
  const GymScenePainter({required this.brightness, this.indoor = true});

  /// 0 to 1. Drives the exposure of the scene, used by the lighting check.
  final double brightness;
  final bool indoor;

  static const double horizon = 0.42;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final exposure = brightness.clamp(0.25, 1.0);

    final wallTop = indoor
        ? Color.lerp(
            const Color(0xFF11131F),
            const Color(0xFF2C3145),
            exposure,
          )!
        : Color.lerp(
            const Color(0xFF13233A),
            const Color(0xFF4E7CA8),
            exposure,
          )!;
    final wallBottom = indoor
        ? Color.lerp(
            const Color(0xFF1A1D2C),
            const Color(0xFF3C4358),
            exposure,
          )!
        : Color.lerp(
            const Color(0xFF1B3350),
            const Color(0xFF6E9AC4),
            exposure,
          )!;

    canvas.drawRect(
      Rect.fromLTRB(0, 0, size.width, size.height * horizon),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [wallTop, wallBottom],
        ).createShader(rect),
    );

    _paintFloor(canvas, size, exposure);
    _paintCourtLines(canvas, size);
    _paintHoop(canvas, size, exposure);
    _paintLighting(canvas, size, exposure);
  }

  void _paintFloor(Canvas canvas, Size size, double exposure) {
    final floorRect = Rect.fromLTRB(
      0,
      size.height * horizon,
      size.width,
      size.height,
    );
    final near = Color.lerp(
      const Color(0xFF3A2A1C),
      const Color(0xFFB98A55),
      exposure,
    )!;
    final far = Color.lerp(
      const Color(0xFF241A12),
      const Color(0xFF7C5B38),
      exposure,
    )!;

    canvas.drawRect(
      floorRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [far, near],
        ).createShader(floorRect),
    );

    // Board seams converging toward the vanishing point.
    final vanishing = Offset(size.width * 0.5, size.height * horizon);
    final seam = Paint()
      ..strokeWidth = 1
      ..color = Colors.black.withValues(alpha: 0.10);
    for (var i = -14; i <= 14; i++) {
      final x = size.width * 0.5 + i * size.width * 0.13;
      canvas.drawLine(vanishing, Offset(x, size.height), seam);
    }
  }

  void _paintCourtLines(Canvas canvas, Size size) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height * 0.006
      ..color = Colors.white.withValues(alpha: 0.34);

    // Baseline running across the near floor.
    canvas.drawLine(
      Offset(0, size.height * 0.845),
      Offset(size.width, size.height * 0.815),
      line,
    );

    // Three-point arc in perspective.
    final arc = Path()
      ..moveTo(size.width * -0.05, size.height * 0.98)
      ..cubicTo(
        size.width * 0.26,
        size.height * 0.55,
        size.width * 0.74,
        size.height * 0.55,
        size.width * 1.05,
        size.height * 0.96,
      );
    canvas.drawPath(arc, line);

    // Key edge.
    final key = Path()
      ..moveTo(size.width * 0.60, size.height * 0.84)
      ..lineTo(size.width * 0.655, size.height * 0.60)
      ..lineTo(size.width * 0.845, size.height * 0.60);
    canvas.drawPath(key, line);
  }

  void _paintHoop(Canvas canvas, Size size, double exposure) {
    final board = Rect.fromLTWH(
      LiveScene.backboard.left * size.width,
      LiveScene.backboard.top * size.height,
      LiveScene.backboard.width * size.width,
      LiveScene.backboard.height * size.height,
    );
    final rim = Rect.fromLTWH(
      LiveScene.hoop.left * size.width,
      LiveScene.hoop.top * size.height,
      LiveScene.hoop.width * size.width,
      LiveScene.hoop.height * size.height,
    );

    // Support arm and post.
    final post = Paint()
      ..strokeWidth = size.width * 0.016
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(
        const Color(0xFF1A1C26),
        const Color(0xFF4C5164),
        exposure,
      )!;
    canvas.drawLine(
      Offset(board.right + size.width * 0.02, board.center.dy),
      Offset(board.right + size.width * 0.09, size.height * 0.86),
      post,
    );

    // Glass backboard.
    canvas.drawRRect(
      RRect.fromRectAndRadius(board, const Radius.circular(3)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.16 * exposure + 0.05),
            Colors.white.withValues(alpha: 0.05),
          ],
        ).createShader(board),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(board, const Radius.circular(3)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.6),
    );

    // Inner square.
    final inner = Rect.fromCenter(
      center: Offset(board.center.dx, board.bottom - board.height * 0.28),
      width: board.width * 0.36,
      height: board.height * 0.40,
    );
    canvas.drawRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.7),
    );

    // Rim.
    canvas.drawOval(
      rim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.height * 0.008
        ..color = const Color(0xFFE8642A),
    );

    // Net strands.
    final net = Paint()
      ..strokeWidth = 1.1
      ..color = Colors.white.withValues(alpha: 0.65);
    const strands = 11;
    final netDepth = rim.height * 3.6;
    for (var i = 0; i < strands; i++) {
      final t = i / (strands - 1);
      final angle = math.pi * t;
      final top = Offset(
        rim.center.dx + math.cos(angle) * rim.width / 2,
        rim.center.dy + math.sin(angle) * rim.height / 2,
      );
      final bottom = Offset(
        rim.center.dx + math.cos(angle) * rim.width * 0.24,
        rim.center.dy + netDepth,
      );
      canvas.drawLine(top, bottom, net);
    }
    for (var row = 1; row <= 3; row++) {
      final t = row / 4;
      final path = Path();
      for (var i = 0; i < strands; i++) {
        final s = i / (strands - 1);
        final angle = math.pi * s;
        final rx = rim.width / 2 * (1 - t) + rim.width * 0.24 * t;
        final point = Offset(
          rim.center.dx + math.cos(angle) * rx,
          rim.center.dy + math.sin(angle) * rim.height / 2 + netDepth * t,
        );
        i == 0
            ? path.moveTo(point.dx, point.dy)
            : path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.4),
      );
    }
  }

  void _paintLighting(Canvas canvas, Size size, double exposure) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.2, -0.9),
          radius: 1.3,
          colors: [
            Colors.white.withValues(alpha: 0.12 * exposure),
            Colors.transparent,
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 1.05,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.42)],
          stops: const [0.55, 1.0],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(GymScenePainter oldDelegate) =>
      oldDelegate.brightness != brightness || oldDelegate.indoor != indoor;
}
