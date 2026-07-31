import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/av_colors.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../data/capture/shot_clip.dart';
import '../../data/models/pose.dart' show PoseFrame, PoseJoint, poseSkeleton;

/// Replays a recorded shot clip, animating pose skeleton and ball trajectory.
class ShotReplay extends StatefulWidget {
  const ShotReplay({super.key, required this.clip});

  final ShotClip clip;

  @override
  State<ShotReplay> createState() => _ShotReplayState();
}

class _ShotReplayState extends State<ShotReplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _playing = true;

  @override
  void initState() {
    super.initState();
    final durationMs = widget.clip.frames.isEmpty
        ? 1000
        : widget.clip.frames.last.timestampMs -
            widget.clip.frames.first.timestampMs;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: math.max(durationMs, 500)),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      _playing = !_playing;
      if (_playing) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _togglePlay,
            child: Container(
              decoration: BoxDecoration(
                color: AvColors.ink,
                borderRadius: AvRadius.allMd,
              ),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final frameIndex =
                      (_controller.value * (widget.clip.frames.length - 1))
                          .round()
                          .clamp(0, widget.clip.frames.length - 1);
                  return CustomPaint(
                    painter: _ReplayPainter(
                      clip: widget.clip,
                      currentFrame: frameIndex,
                    ),
                    size: Size.infinite,
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: AvSpace.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: AvColors.textPrimary,
              ),
              onPressed: _togglePlay,
            ),
            const SizedBox(width: AvSpace.sm),
            Text(
              widget.clip.made == true
                  ? 'Made'
                  : widget.clip.made == false
                      ? 'Missed'
                      : 'Shot',
              style: AvType.titleMedium.primary,
            ),
            const SizedBox(width: AvSpace.sm),
            Text(
              '${widget.clip.duration.inMilliseconds}ms',
              style: AvType.caption.muted,
            ),
          ],
        ),
      ],
    );
  }
}

class _ReplayPainter extends CustomPainter {
  _ReplayPainter({required this.clip, required this.currentFrame});

  final ShotClip clip;
  final int currentFrame;

  @override
  void paint(Canvas canvas, Size size) {
    if (clip.frames.isEmpty) return;

    final frame = clip.frames[currentFrame];

    _drawBallTrail(canvas, size);

    if (frame.rim != null) {
      final rimPaint = Paint()
        ..color = AvColors.overlayHoop.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRect(
        Rect.fromLTRB(
          frame.rim!.left * size.width,
          frame.rim!.top * size.height,
          frame.rim!.right * size.width,
          frame.rim!.bottom * size.height,
        ),
        rimPaint,
      );
    }

    if (frame.pose != null) {
      _drawSkeleton(canvas, size, frame.pose!);
    }

    if (frame.ball != null) {
      final ballPaint = Paint()
        ..color = AvColors.flare
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(frame.ball!.dx * size.width, frame.ball!.dy * size.height),
        8,
        ballPaint,
      );
    }

    if (currentFrame == clip.releaseFrameIndex) {
      final markerPaint = Paint()
        ..color = AvColors.made
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final centre = frame.ball ?? const Offset(0.5, 0.5);
      canvas.drawCircle(
        Offset(centre.dx * size.width, centre.dy * size.height),
        16,
        markerPaint,
      );
    }
  }

  void _drawBallTrail(Canvas canvas, Size size) {
    final trailPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final path = Path();
    var started = false;
    for (var i = 0; i <= currentFrame; i++) {
      final ball = clip.frames[i].ball;
      if (ball == null) continue;
      final point = Offset(ball.dx * size.width, ball.dy * size.height);
      if (!started) {
        path.moveTo(point.dx, point.dy);
        started = true;
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    if (started) {
      trailPaint.color = AvColors.overlayTrace.withValues(alpha: 0.7);
      canvas.drawPath(path, trailPaint);
    }
  }

  void _drawSkeleton(Canvas canvas, Size size, PoseFrame pose) {
    final jointPaint = Paint()
      ..color = AvColors.overlaySkeleton
      ..style = PaintingStyle.fill;
    final bonePaint = Paint()
      ..color = AvColors.overlaySkeleton.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    Offset? posOf(PoseJoint joint) {
      final p = pose.landmarks[joint];
      if (p == null) return null;
      return Offset(p.dx * size.width, p.dy * size.height);
    }

    for (final (from, to) in poseSkeleton) {
      final a = posOf(from);
      final b = posOf(to);
      if (a != null && b != null) {
        canvas.drawLine(a, b, bonePaint);
      }
    }

    for (final joint in PoseJoint.values) {
      final pos = posOf(joint);
      if (pos != null) {
        canvas.drawCircle(pos, 4, jointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_ReplayPainter old) => old.currentFrame != currentFrame;
}
