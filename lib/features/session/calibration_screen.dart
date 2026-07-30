import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/av_colors.dart';
import '../../core/theme/av_theme.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../data/models/confidence.dart';
import '../../data/models/drill.dart';
import '../../data/seed/drill_catalog.dart';
import '../../design/components/av_button.dart';
import '../../design/components/av_indicators.dart';
import '../../design/components/av_layout.dart';
import '../../design/components/av_surface.dart';
import '../../data/capture/live_scene.dart';
import '../../state/live_session.dart';
import 'camera_stage.dart';

/// Establishes the court plane, rim position and capture quality before a
/// session starts. Every downstream measurement inherits this quality score,
/// so the result is shown plainly and the athlete can refuse to continue.
class CalibrationScreen extends ConsumerStatefulWidget {
  const CalibrationScreen({
    super.key,
    required this.drillId,
    required this.angle,
  });

  final String drillId;
  final CameraAngle angle;

  @override
  ConsumerState<CalibrationScreen> createState() => _CalibrationScreenState();
}

enum _CalibrationStage { idle, scanning, complete }

class _CalibrationScreenState extends ConsumerState<CalibrationScreen>
    with SingleTickerProviderStateMixin {
  late final Drill _drill = DrillCatalog.byId(widget.drillId);
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  _CalibrationStage _stage = _CalibrationStage.idle;
  Timer? _timer;
  int _step = 0;

  static const _steps = <_CalibrationStep>[
    _CalibrationStep(
      label: 'Locking court plane',
      detail: 'Three baseline and key lines matched against the court model.',
      icon: Icons.grid_on_rounded,
    ),
    _CalibrationStep(
      label: 'Locating rim and backboard',
      detail: 'Rim ellipse solved at 3.05 m and used as the height reference.',
      icon: Icons.adjust_rounded,
    ),
    _CalibrationStep(
      label: 'Measuring exposure',
      detail: 'Frame brightness and contrast checked across the shooting area.',
      icon: Icons.wb_iridescent_rounded,
    ),
    _CalibrationStep(
      label: 'Checking stability',
      detail: 'Motion in the static background sampled over three seconds.',
      icon: Icons.vibration_rounded,
    ),
    _CalibrationStep(
      label: 'Verifying framing',
      detail: 'Full body and rim confirmed inside the frame through the jump.',
      icon: Icons.crop_free_rounded,
    ),
  ];

  static const _quality = <String, double>{
    'Court plane': 0.96,
    'Rim reference': 0.94,
    'Lighting': 0.88,
    'Stability': 0.93,
    'Framing': 0.90,
  };

  double get _overall =>
      _quality.values.reduce((a, b) => a + b) / _quality.length;

  @override
  void dispose() {
    _timer?.cancel();
    _sweep.dispose();
    super.dispose();
  }

  void _start() {
    setState(() {
      _stage = _CalibrationStage.scanning;
      _step = 0;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 720), (timer) {
      if (!mounted) return;
      if (_step >= _steps.length - 1) {
        timer.cancel();
        setState(() => _stage = _CalibrationStage.complete);
        _sweep.stop();
      } else {
        setState(() => _step++);
      }
    });
  }

  void _startSession() {
    ref.read(liveSessionProvider.notifier).configure(_drill, widget.angle);
    context.pushReplacement(AppRoute.live(_drill.id, widget.angle));
  }

  @override
  Widget build(BuildContext context) {
    final complete = _stage == _CalibrationStage.complete;

    return AvScaffold(
      title: 'Calibration',
      subtitle: 'Step 2 of 2 \u00B7 ${widget.angle.label} view',
      leading: const AvBackButton(),
      overlayStyle: AvTheme.lightOverlay,
      bottomBar: AvBottomBar(
        note: complete
            ? Row(
                children: [
                  Icon(
                    ConfidenceLevel.fromScore(_overall).icon,
                    size: 15,
                    color: ConfidenceLevel.fromScore(_overall).color,
                  ),
                  const SizedBox(width: AvSpace.xs),
                  Expanded(
                    child: Text(
                      'Capture quality '
                      '${(_overall * 100).round()} of 100. Metrics recorded '
                      'this session inherit this grade.',
                      style: AvType.caption.muted,
                    ),
                  ),
                ],
              )
            : null,
        children: [
          if (complete) ...[
            AvButton(
              label: 'Recalibrate',
              variant: AvButtonVariant.outline,
              size: AvButtonSize.large,
              onPressed: _start,
            ),
            Expanded(
              child: AvButton(
                label: 'Start session',
                size: AvButtonSize.large,
                icon: Icons.play_arrow_rounded,
                expand: true,
                onPressed: _startSession,
              ),
            ),
          ] else
            Expanded(
              child: AvButton(
                label: _stage == _CalibrationStage.scanning
                    ? 'Calibrating'
                    : 'Calibrate court',
                size: AvButtonSize.large,
                expand: true,
                busy: _stage == _CalibrationStage.scanning,
                onPressed: _stage == _CalibrationStage.scanning ? null : _start,
              ),
            ),
        ],
      ),
      slivers: [
        SliverGutter(
          child: ClipRRect(
            borderRadius: AvRadius.allLg,
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: CameraStage(
                overlay: AnimatedBuilder(
                  animation: _sweep,
                  builder: (context, _) => CustomPaint(
                    painter: _CalibrationOverlayPainter(
                      progress: _sweep.value,
                      stage: _stage,
                      step: _step,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverGutter(
          top: AvSpace.md,
          child: AvCard(
            padding: const EdgeInsets.all(AvSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _steps.length; i++) ...[
                  if (i > 0) const SizedBox(height: AvSpace.sm),
                  _StepRow(
                    step: _steps[i],
                    state: switch (_stage) {
                      _CalibrationStage.idle => _StepState.waiting,
                      _CalibrationStage.complete => _StepState.done,
                      _CalibrationStage.scanning =>
                        i < _step
                            ? _StepState.done
                            : i == _step
                            ? _StepState.active
                            : _StepState.waiting,
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        if (complete) ...[
          const SliverGutter(
            top: AvSpace.lg,
            child: AvSectionHeader(
              title: 'Quality report',
              subtitle: 'What this setup can and cannot measure',
              padding: EdgeInsets.only(bottom: AvSpace.sm),
            ),
          ),
          SliverGutter(
            child: AvCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      AvProgressRing(
                        value: _overall,
                        size: 62,
                        strokeWidth: 6,
                        color: ConfidenceLevel.fromScore(_overall).color,
                        child: Text(
                          '${(_overall * 100).round()}',
                          style: AvType.tabular(
                            AvType.metricMedium,
                          ).copyWith(fontSize: 19),
                        ),
                      ),
                      const SizedBox(width: AvSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Good capture setup',
                              style: AvType.headingSmall.primary,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Arc, release angle and knee flexion will be '
                              'graded at high confidence from this angle.',
                              style: AvType.caption.muted,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AvSpace.md),
                  const AvSeparator(),
                  const SizedBox(height: AvSpace.sm),
                  for (final entry in _quality.entries)
                    _QualityRow(label: entry.key, value: entry.value),
                ],
              ),
            ),
          ),
          SliverGutter(
            top: AvSpace.sm,
            child: AvUnavailableNotice(
              metric: _unavailableMetric,
              reason: _unavailableReason,
            ),
          ),
          SliverGutter(
            top: AvSpace.sm,
            child: AvTintCard(
              tint: AvColors.courtTint,
              borderColor: AvColors.courtSoft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AvGlyph(
                    icon: Icons.save_rounded,
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
                          'Saved as a court profile',
                          style: AvType.titleSmall.primary,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Northgate Prep, Main Gym. Next session at this '
                          'court reuses the plane and skips straight to the '
                          'framing check.',
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
      ],
    );
  }

  String get _unavailableMetric => switch (widget.angle) {
    CameraAngle.side => 'Left and right deviation',
    CameraAngle.front => 'Release angle and arc apex',
    CameraAngle.rear => 'Knee flexion and set point height',
    CameraAngle.diagonal => 'Guide-hand separation',
  };

  String get _unavailableReason => switch (widget.angle) {
    CameraAngle.side =>
      'A side view compresses left-right error to almost nothing. Shots '
          'will be graded on depth, and horizontal accuracy is left out '
          'rather than guessed.',
    CameraAngle.front =>
      'From the front the ball travels toward the lens, so arc height '
          'cannot be separated from distance. Alignment metrics stay '
          'available at high confidence.',
    CameraAngle.rear =>
      'From behind, the lower body is occluded through the load phase. '
          'Depth and entry angle stay available at high confidence.',
    CameraAngle.diagonal =>
      'At forty-five degrees the guide hand is partially hidden behind '
          'the ball. Every other mechanic is graded at medium confidence '
          'or better.',
  };
}

class _QualityRow extends StatelessWidget {
  const _QualityRow({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final level = ConfidenceLevel.fromScore(value);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 104, child: Text(label, style: AvType.caption.muted)),
          Expanded(
            child: AvMeter(value: value, color: level.color),
          ),
          const SizedBox(width: AvSpace.sm),
          SizedBox(
            width: 26,
            child: Text(
              '${(value * 100).round()}',
              textAlign: TextAlign.right,
              style: AvType.tabular(
                AvType.metricSmall,
              ).copyWith(color: AvColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalibrationStep {
  const _CalibrationStep({
    required this.label,
    required this.detail,
    required this.icon,
  });

  final String label;
  final String detail;
  final IconData icon;
}

enum _StepState { waiting, active, done }

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.state});

  final _CalibrationStep step;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final (color, background) = switch (state) {
      _StepState.waiting => (AvColors.textFaint, AvColors.canvasSunken),
      _StepState.active => (AvColors.flare, AvColors.flareSoft),
      _StepState.done => (AvColors.made, AvColors.madeSoft),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: AvMotion.normal,
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: background, shape: BoxShape.circle),
          child: Center(
            child: state == _StepState.active
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  )
                : Icon(
                    state == _StepState.done ? Icons.check_rounded : step.icon,
                    size: 15,
                    color: color,
                  ),
          ),
        ),
        const SizedBox(width: AvSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.label,
                style: AvType.titleSmall.copyWith(
                  color: state == _StepState.waiting
                      ? AvColors.textMuted
                      : AvColors.textPrimary,
                ),
              ),
              const SizedBox(height: 1),
              Text(step.detail, style: AvType.caption.muted),
            ],
          ),
        ),
      ],
    );
  }
}

class _CalibrationOverlayPainter extends CustomPainter {
  const _CalibrationOverlayPainter({
    required this.progress,
    required this.stage,
    required this.step,
  });

  final double progress;
  final _CalibrationStage stage;
  final int step;

  @override
  void paint(Canvas canvas, Size size) {
    final scanning = stage == _CalibrationStage.scanning;
    final complete = stage == _CalibrationStage.complete;

    // Court plane mesh.
    final mesh = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = (complete ? AvColors.overlayHoop : AvColors.court).withValues(
        alpha: complete ? 0.5 : 0.34,
      );

    final vanishing = Offset(size.width * 0.5, size.height * 0.42);
    for (var i = -6; i <= 6; i++) {
      canvas.drawLine(
        vanishing,
        Offset(size.width * 0.5 + i * size.width * 0.20, size.height),
        mesh,
      );
    }
    for (var i = 1; i <= 5; i++) {
      final t = i / 6;
      final y =
          size.height * 0.42 + math.pow(t, 1.8).toDouble() * size.height * 0.58;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), mesh);
    }

    if (scanning) {
      final y = size.height * 0.42 + progress * size.height * 0.58;
      canvas.drawRect(
        Rect.fromLTRB(0, y - 26, size.width, y),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AvColors.court.withValues(alpha: 0),
              AvColors.court.withValues(alpha: 0.34),
            ],
          ).createShader(Rect.fromLTRB(0, y - 26, size.width, y)),
      );
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..strokeWidth = 2
          ..color = AvColors.court,
      );
    }

    // Rim lock.
    final rim = Rect.fromLTWH(
      LiveScene.hoop.left * size.width,
      LiveScene.hoop.top * size.height,
      LiveScene.hoop.width * size.width,
      LiveScene.hoop.height * size.height,
    );
    final rimColor = complete || step >= 1
        ? AvColors.overlayHoop
        : Colors.white;
    canvas.drawOval(
      rim.inflate(6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = rimColor.withValues(alpha: 0.9),
    );
    _tag(
      canvas,
      Offset(rim.left, rim.top - 20),
      complete || step >= 1 ? 'RIM 3.05 m' : 'SEARCHING',
      rimColor,
    );

    // Framing guide.
    final guide = Rect.fromLTWH(
      size.width * 0.10,
      size.height * 0.14,
      size.width * 0.44,
      size.height * 0.78,
    );
    final guidePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = Colors.white.withValues(alpha: 0.55);
    const dash = 9.0;
    for (final side in [
      (guide.topLeft, guide.topRight),
      (guide.bottomLeft, guide.bottomRight),
      (guide.topLeft, guide.bottomLeft),
      (guide.topRight, guide.bottomRight),
    ]) {
      final delta = side.$2 - side.$1;
      final length = delta.distance;
      final unit = delta / length;
      var travelled = 0.0;
      while (travelled < length) {
        canvas.drawLine(
          side.$1 + unit * travelled,
          side.$1 + unit * math.min(travelled + dash, length),
          guidePaint,
        );
        travelled += dash * 2;
      }
    }
    _tag(
      canvas,
      Offset(guide.left, guide.top - 20),
      'STAND HERE',
      Colors.white,
    );
  }

  void _tag(Canvas canvas, Offset position, String text, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: AvType.overline.copyWith(
          color: color == Colors.white ? AvColors.ink : Colors.white,
          fontSize: 8.5,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          position.dx,
          position.dy,
          painter.width + 10,
          painter.height + 5,
        ),
        const Radius.circular(3),
      ),
      Paint()..color = color.withValues(alpha: 0.92),
    );
    painter.paint(canvas, position + const Offset(5, 2.5));
  }

  @override
  bool shouldRepaint(_CalibrationOverlayPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.stage != stage ||
      oldDelegate.step != step;
}
