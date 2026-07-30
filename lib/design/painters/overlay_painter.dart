import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/av_colors.dart';
import '../../core/theme/av_typography.dart';
import '../../data/capture/live_scene.dart';
import '../../data/models/pose.dart';

/// Live analysis overlay: skeleton, hand landmarks, tracked object boxes and
/// the ball trace. Everything is generated from the frame payload, never from
/// pre-made artwork.
class AnalysisOverlayPainter extends CustomPainter {
  const AnalysisOverlayPainter({
    required this.pose,
    required this.ball,
    required this.trail,
    required this.phase,
    required this.showSkeleton,
    required this.showTrajectory,
    required this.showBoxes,
    required this.trackingConfidence,
    required this.textDirection,
    this.rim,
    this.backboard,
    this.highlightRelease = false,
  });

  final PoseFrame pose;
  final Offset ball;
  final List<Offset> trail;

  /// Scene geometry as located by the pipeline. Null until it locks on.
  final Rect? rim;
  final Rect? backboard;

  final ShotPhaseKind phase;
  final bool showSkeleton;
  final bool showTrajectory;
  final bool showBoxes;
  final double trackingConfidence;
  final TextDirection textDirection;
  final bool highlightRelease;

  @override
  void paint(Canvas canvas, Size size) {
    Offset scale(Offset point) =>
        Offset(point.dx * size.width, point.dy * size.height);

    if (showBoxes) {
      if (rim != null) {
        _paintTrackedBox(canvas, size, rim!, AvColors.overlayHoop, 'RIM 0.98');
      }
      if (backboard != null) {
        _paintTrackedBox(
          canvas,
          size,
          backboard!,
          AvColors.overlayHoop.withValues(alpha: 0.55),
          'BACKBOARD',
          thin: true,
        );
      }
      _paintTrackedBox(
        canvas,
        size,
        LiveScene.playerBox(pose),
        AvColors.overlaySkeleton,
        'PLAYER 1 \u00B7 ${(pose.confidence * 100).round()}',
      );
    }

    if (showTrajectory && trail.length > 1) {
      final path = Path()..moveTo(scale(trail.first).dx, scale(trail.first).dy);
      for (var i = 1; i < trail.length; i++) {
        final point = scale(trail[i]);
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..color = AvColors.overlayTrace.withValues(alpha: 0.20),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..color = AvColors.overlayTrace,
      );

      for (var i = 0; i < trail.length; i += 4) {
        canvas.drawCircle(
          scale(trail[i]),
          1.8,
          Paint()..color = AvColors.overlayTrace.withValues(alpha: 0.65),
        );
      }
    }

    if (showSkeleton) {
      final bone = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = AvColors.overlaySkeleton.withValues(
          alpha: 0.35 + trackingConfidence * 0.55,
        );

      for (final (from, to) in poseSkeleton) {
        canvas.drawLine(scale(pose[from]), scale(pose[to]), bone);
      }

      for (final joint in PoseJoint.values) {
        final point = scale(pose[joint]);
        final major =
            joint == PoseJoint.rightWrist ||
            joint == PoseJoint.rightElbow ||
            joint == PoseJoint.rightShoulder;
        canvas.drawCircle(
          point,
          major ? 5.0 : 3.4,
          Paint()..color = AvColors.overlayJoint,
        );
        canvas.drawCircle(
          point,
          major ? 5.0 : 3.4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = major ? AvColors.flare : AvColors.overlaySkeleton,
        );
      }

      _paintHand(canvas, scale(pose[PoseJoint.rightWrist]), AvColors.flare);
      _paintHand(
        canvas,
        scale(pose[PoseJoint.leftWrist]),
        AvColors.overlaySkeleton,
      );

      _paintElbowAngle(canvas, size, scale);
    }

    // Ball.
    final ballCentre = scale(ball);
    final radius = size.width * 0.026;
    canvas.drawCircle(
      ballCentre,
      radius * 1.9,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                AvColors.overlayBall.withValues(alpha: 0.32),
                AvColors.overlayBall.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(center: ballCentre, radius: radius * 1.9),
            ),
    );
    canvas.drawCircle(
      ballCentre,
      radius,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFA766), Color(0xFFE2551D)],
        ).createShader(Rect.fromCircle(center: ballCentre, radius: radius)),
    );
    canvas.drawCircle(
      ballCentre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.85),
    );

    if (showBoxes) {
      _paintTrackedBox(
        canvas,
        size,
        Rect.fromCircle(center: ball, radius: 0.030),
        AvColors.overlayBall,
        'BALL 0.96',
        thin: true,
      );
    }

    if (highlightRelease) {
      canvas.drawCircle(
        ballCentre,
        radius * 2.6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white.withValues(alpha: 0.7),
      );
    }
  }

  void _paintHand(Canvas canvas, Offset wrist, Color color) {
    final paint = Paint()
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.9);
    for (var i = 0; i < 5; i++) {
      final angle = -math.pi * 0.85 + i * math.pi * 0.17;
      final tip = wrist + Offset(math.cos(angle), math.sin(angle)) * 11;
      canvas.drawLine(wrist, tip, paint);
      canvas.drawCircle(tip, 1.6, Paint()..color = color);
    }
  }

  void _paintElbowAngle(
    Canvas canvas,
    Size size,
    Offset Function(Offset) scale,
  ) {
    final shoulder = scale(pose[PoseJoint.rightShoulder]);
    final elbow = scale(pose[PoseJoint.rightElbow]);
    final wrist = scale(pose[PoseJoint.rightWrist]);

    final a = shoulder - elbow;
    final b = wrist - elbow;
    final angle = math.acos(
      ((a.dx * b.dx + a.dy * b.dy) / (a.distance * b.distance)).clamp(
        -1.0,
        1.0,
      ),
    );
    final degrees = angle * 180 / math.pi;

    final startAngle = math.atan2(a.dy, a.dx);
    final endAngle = math.atan2(b.dy, b.dx);
    var sweep = endAngle - startAngle;
    if (sweep > math.pi) sweep -= 2 * math.pi;
    if (sweep < -math.pi) sweep += 2 * math.pi;

    canvas.drawArc(
      Rect.fromCircle(center: elbow, radius: 20),
      startAngle,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AvColors.flare.withValues(alpha: 0.9),
    );

    final painter = TextPainter(
      text: TextSpan(
        text: '${degrees.round()}\u00B0',
        style: AvType.tabular(
          AvType.overline,
        ).copyWith(color: Colors.white, fontSize: 10, letterSpacing: 0),
      ),
      textDirection: textDirection,
    )..layout();

    final labelPos = elbow + const Offset(24, -8);
    final bg = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        labelPos.dx - 4,
        labelPos.dy - 2,
        painter.width + 8,
        painter.height + 4,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      bg,
      Paint()..color = AvColors.flareDeep.withValues(alpha: 0.85),
    );
    painter.paint(canvas, labelPos);
  }

  void _paintTrackedBox(
    Canvas canvas,
    Size size,
    Rect normalised,
    Color color,
    String label, {
    bool thin = false,
  }) {
    final rect = Rect.fromLTRB(
      normalised.left * size.width,
      normalised.top * size.height,
      normalised.right * size.width,
      normalised.bottom * size.height,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thin ? 1.4 : 2
      ..color = color;

    final corner = math.min(rect.width, rect.height) * 0.28;
    final path = Path()
      ..moveTo(rect.left, rect.top + corner)
      ..lineTo(rect.left, rect.top)
      ..lineTo(rect.left + corner, rect.top)
      ..moveTo(rect.right - corner, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.top + corner)
      ..moveTo(rect.right, rect.bottom - corner)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.right - corner, rect.bottom)
      ..moveTo(rect.left + corner, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.bottom - corner);
    canvas.drawPath(path, paint);

    if (thin) return;

    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: AvType.overline.copyWith(
          color: Colors.white,
          fontSize: 8.5,
          letterSpacing: 0.6,
        ),
      ),
      textDirection: textDirection,
    )..layout();

    final tag = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        rect.left,
        rect.top - painter.height - 7,
        painter.width + 10,
        painter.height + 5,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(tag, Paint()..color = color.withValues(alpha: 0.85));
    painter.paint(
      canvas,
      Offset(rect.left + 5, rect.top - painter.height - 4.5),
    );
  }

  @override
  bool shouldRepaint(AnalysisOverlayPainter oldDelegate) => true;
}
