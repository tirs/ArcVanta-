import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/av_colors.dart';
import '../../core/theme/av_theme.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../data/calibration/calibration_solver.dart';
import '../../data/models/confidence.dart';
import '../../data/models/drill.dart';
import '../../data/seed/drill_catalog.dart';
import '../../design/components/av_button.dart';
import '../../design/components/av_indicators.dart';
import '../../design/components/av_layout.dart';
import '../../design/components/av_surface.dart';
import '../../data/capture/live_scene.dart';
import '../../state/calibration.dart';
import '../../data/capture/native_capture_source.dart';
import '../../state/capture_pipeline.dart';
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

/// The icon shown beside each factor the solver reports.
///
/// The labels come from `CalibrationSolver`, which owns what is measured. This
/// map only decides what it looks like, so a new factor appears in the list
/// with a neutral icon rather than not appearing at all.
const _factorIcons = <String, IconData>{
  'Court plane': Icons.grid_on_rounded,
  'Rim reference': Icons.adjust_rounded,
  'Lighting': Icons.wb_iridescent_rounded,
  'Stability': Icons.vibration_rounded,
  'Framing': Icons.crop_free_rounded,
};

class _CalibrationScreenState extends ConsumerState<CalibrationScreen>
    with SingleTickerProviderStateMixin {
  late final Drill _drill = DrillCatalog.byId(widget.drillId);
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  void _start() {
    ref.read(calibrationProvider.notifier).start();
    if (!_sweep.isAnimating) _sweep.repeat();
  }

  /// Asks for the camera, and says what to do when asking is no longer enough.
  Future<void> _requestCamera() async {
    final messenger = ScaffoldMessenger.of(context);
    final status = await ref.read(cameraPermissionRequestProvider)();
    if (!mounted) return;

    switch (status) {
      case CameraPermissionStatus.granted:
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Camera connected. Calibrate to start measuring.'),
          ),
        );
      case CameraPermissionStatus.permanentlyDenied:
        // The system will not show the dialog again, so pointing at it would
        // send the user in a circle.
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Camera access is off. Turn it on in your device settings '
              'under Apps, ArcVanta, Permissions.',
            ),
            duration: Duration(seconds: 6),
          ),
        );
      case CameraPermissionStatus.denied:
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Without the camera, sessions stay simulated.'),
          ),
        );
      case CameraPermissionStatus.unsupported:
        messenger.showSnackBar(
          const SnackBar(
            content: Text('This build has no camera pipeline.'),
          ),
        );
    }
  }

  void _startSession() {
    // The solved frame is what every measured angle is taken against, so it is
    // handed over before the session is configured rather than after.
    ref.read(calibrationProvider.notifier).commit();
    ref.read(liveSessionProvider.notifier).configure(_drill, widget.angle);
    context.pushReplacement(AppRoute.live(_drill.id, widget.angle));
  }

  /// What the athlete should do about a scene that will not solve.
  ///
  /// Every one of these is fixable by moving the phone, which is why the
  /// failure is named rather than reported as a generic error.
  (String, String) _blockedAdvice(CalibrationFailure failure) =>
      switch (failure) {
        CalibrationFailure.noRim => (
          'No ring in view',
          'Point the camera at the basket. The whole ring needs to be inside '
              'the frame, not just the front edge.',
        ),
        CalibrationFailure.rimTooSmall => (
          'Too far from the basket',
          'The ring is only a few pixels across, which is not enough to solve '
              'the court plane. Move closer or zoom in.',
        ),
        CalibrationFailure.degenerateEllipse => (
          'Ring seen edge-on',
          'From directly level with the rim the ellipse collapses to a line '
              'and the height reference is lost. Lower the phone or step back.',
        ),
        CalibrationFailure.poseUnsolvable => (
          'Cannot place the ring in space',
          'The ring outline is not clean enough to solve. Check for glare on '
              'the backboard and wipe the lens.',
        ),
        CalibrationFailure.implausibleGeometry => (
          'Solved to an impossible position',
          'The geometry puts the ring somewhere a basket cannot be, usually a '
              'reflection or a second hoop. Reframe on one basket.',
        ),
      };

  @override
  Widget build(BuildContext context) {
    final calibration = ref.watch(calibrationProvider);
    final pipeline = ref.watch(pipelineStatusProvider).valueOrNull;
    final solved = calibration.isSolved;
    final solution = calibration.solution;
    final overall = calibration.overall;
    final level = ConfidenceLevel.fromScore(overall);

    if (solved && _sweep.isAnimating) _sweep.stop();

    return AvScaffold(
      title: 'Calibration',
      subtitle: 'Step 2 of 2 \u00B7 ${widget.angle.label} view',
      leading: const AvBackButton(),
      overlayStyle: AvTheme.lightOverlay,
      bottomBar: AvBottomBar(
        note: solved
            ? Row(
                children: [
                  Icon(level.icon, size: 15, color: level.color),
                  const SizedBox(width: AvSpace.xs),
                  Expanded(
                    child: Text(
                      'Capture quality ${(overall * 100).round()} of 100. '
                      'Metrics recorded this session inherit this grade.',
                      style: AvType.caption.muted,
                    ),
                  ),
                ],
              )
            : null,
        children: [
          if (solved) ...[
            // Starting the session is the action that matters here, so when
            // both will not fit, recalibrating gives up its label rather than
            // squeezing the primary button.
            if (_roomForTwoLabels(context))
              AvButton(
                label: 'Recalibrate',
                variant: AvButtonVariant.outline,
                size: AvButtonSize.large,
                onPressed: _start,
              )
            else
              AvIconButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Recalibrate',
                size: 48,
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
                label: switch (calibration.stage) {
                  CalibrationStage.searching => 'Looking for the ring',
                  CalibrationStage.settling => 'Holding steady',
                  CalibrationStage.blocked => 'Try again',
                  _ => 'Calibrate court',
                },
                size: AvButtonSize.large,
                expand: true,
                busy: calibration.isRunning,
                onPressed: calibration.isRunning ? null : _start,
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
                      stage: calibration.stage,
                      settleProgress: calibration.settleProgress,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (pipeline != null && !pipeline.isLive)
          SliverGutter(
            top: AvSpace.md,
            child: AvTintCard(
              tint: AvColors.flareSoft,
              borderColor: AvColors.flare,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AvGlyph(
                    icon: Icons.science_rounded,
                    color: AvColors.ink,
                    background: AvColors.flareSoft,
                    size: 36,
                  ),
                  const SizedBox(width: AvSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Simulated capture',
                          style: AvType.titleSmall.primary,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${pipeline.explanation}. The geometry below is '
                          'solved for real, but from a generated scene.',
                          style: AvType.caption.muted,
                        ),
                        if (pipeline.fallbackReason ==
                            CaptureUnavailableReason
                                .cameraPermissionDenied) ...[
                          const SizedBox(height: AvSpace.sm),
                          AvButton(
                            label: 'Allow camera access',
                            size: AvButtonSize.small,
                            icon: Icons.photo_camera_outlined,
                            onPressed: _requestCamera,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        SliverGutter(
          top: AvSpace.md,
          child: _ProgressCard(state: calibration),
        ),
        if (calibration.stage == CalibrationStage.blocked &&
            calibration.failure != null)
          SliverGutter(
            top: AvSpace.sm,
            child: Builder(
              builder: (context) {
                final (title, advice) = _blockedAdvice(calibration.failure!);
                return AvTintCard(
                  tint: AvColors.missSoft,
                  borderColor: AvColors.miss,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AvGlyph(
                        icon: Icons.error_outline_rounded,
                        color: AvColors.miss,
                        background: AvColors.missSoft,
                        size: 36,
                      ),
                      const SizedBox(width: AvSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: AvType.titleSmall.primary),
                            const SizedBox(height: 2),
                            Text(advice, style: AvType.caption.muted),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        if (solved && solution != null) ...[
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
                        value: overall,
                        size: 62,
                        strokeWidth: 6,
                        color: level.color,
                        child: Text(
                          '${(overall * 100).round()}',
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
                              _verdict(overall),
                              style: AvType.headingSmall.primary,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _measuredSummary(solution),
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
                  for (final factor in solution.factors)
                    _QualityRow(
                      label: factor.label,
                      value: factor.score,
                      detail: factor.detail,
                    ),
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
          if (solution.rimHeightAssumed)
            SliverGutter(
              top: AvSpace.sm,
              child: AvTintCard(
                tint: AvColors.canvasSunken,
                borderColor: AvColors.hairline,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AvGlyph(
                      icon: Icons.straighten_rounded,
                      color: AvColors.textMuted,
                      background: AvColors.canvasSunken,
                      size: 36,
                    ),
                    const SizedBox(width: AvSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rim height assumed, not measured',
                            style: AvType.titleSmall.primary,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Every height on this court is taken from the '
                            'regulation 3.05 m. On an adjustable hoop set '
                            'lower than that, release and apex heights will '
                            'read high by the difference.',
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

  /// Whether the action bar can hold two labelled buttons side by side.
  ///
  /// Both the viewport and the text scale move this, and a 320 pt phone at the
  /// largest accessibility scale cannot hold either label at full size.
  bool _roomForTwoLabels(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    // 380 is where 'Recalibrate' and 'Start session' stop fitting together at
    // the large button size, measured rather than guessed: a 360 pt phone at
    // scale 1 overflows by six pixels.
    return width / scale > 380;
  }

  String _verdict(double overall) {
    if (overall >= 0.85) return 'Good capture setup';
    if (overall >= 0.65) return 'Usable capture setup';
    return 'Weak capture setup';
  }

  /// The one-line summary under the score.
  ///
  /// Built from what the solver actually measured rather than written in
  /// advance, so it cannot promise high confidence for a setup that did not
  /// earn it.
  String _measuredSummary(CalibrationSolution solution) {
    final distance = solution.frame?.rimCentre.length.toStringAsFixed(1);
    final error = solution.reprojectionErrorPx.isNaN
        ? null
        : solution.reprojectionErrorPx.toStringAsFixed(1);

    final weakest = solution.factors.isEmpty
        ? null
        : solution.factors.reduce((a, b) => a.score <= b.score ? a : b);

    final parts = <String>[
      if (distance != null) 'Ring solved $distance m out',
      if (error != null) 'reprojecting to $error px',
    ];
    final measured = parts.isEmpty ? 'Geometry solved' : parts.join(', ');

    if (weakest != null && weakest.score < 0.7) {
      return '$measured. ${weakest.label} is the limit here: '
          '${weakest.detail.toLowerCase()}.';
    }
    return '$measured.';
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
  const _QualityRow({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final double value;

  /// What the solver measured to arrive at this score.
  final String detail;

  @override
  Widget build(BuildContext context) {
    final level = ConfidenceLevel.fromScore(value);
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _factorIcons[label] ?? Icons.tune_rounded,
                size: 14,
                color: AvColors.textFaint,
              ),
              const SizedBox(width: AvSpace.xs),
              SizedBox(
                width: 90 * textScale.clamp(1.0, 1.6),
                child: Text(
                  label,
                  style: AvType.caption.muted,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(child: AvMeter(value: value, color: level.color)),
              const SizedBox(width: AvSpace.sm),
              SizedBox(
                // Wide enough for a perfect 100, which is the one value that
                // needs three digits and the one most likely to be clipped.
                width: 34 * textScale.clamp(1.0, 1.5),
                child: Text(
                  '${(value * 100).round()}',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  style: AvType.tabular(
                    AvType.metricSmall,
                  ).copyWith(color: AvColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            detail,
            style: AvType.caption.copyWith(
              color: AvColors.textFaint,
              fontSize: 11,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// What the calibration is doing right now, and how far through it is.
///
/// Replaces the five scripted steps that used to tick over on a timer. There
/// is only one thing actually happening — solving the same scene repeatedly
/// until the answer stops moving — so that is what is shown.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.state});

  final CalibrationState state;

  @override
  Widget build(BuildContext context) {
    return AvCard(
      padding: const EdgeInsets.all(AvSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StageGlyph(stage: state.stage),
              const SizedBox(width: AvSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_title, style: AvType.titleSmall.primary),
                    const SizedBox(height: 1),
                    Text(_detail, style: AvType.caption.muted),
                  ],
                ),
              ),
            ],
          ),
          if (state.stage == CalibrationStage.settling) ...[
            const SizedBox(height: AvSpace.sm),
            AvMeter(value: state.settleProgress, color: AvColors.flare),
          ],
          if (state.solution != null && state.stage != CalibrationStage.idle)
            ...[
              const SizedBox(height: AvSpace.sm),
              const AvSeparator(),
              const SizedBox(height: AvSpace.sm),
              Wrap(
                spacing: AvSpace.md,
                runSpacing: AvSpace.xs,
                children: [
                  for (final (label, value) in _readings)
                    _Reading(label: label, value: value),
                ],
              ),
            ],
        ],
      ),
    );
  }

  String get _title => switch (state.stage) {
    CalibrationStage.idle => 'Ready to calibrate',
    CalibrationStage.searching => 'Looking for the ring',
    CalibrationStage.settling => 'Solving the court plane',
    CalibrationStage.solved => 'Court plane locked',
    CalibrationStage.blocked => 'Cannot solve this view',
  };

  String get _detail => switch (state.stage) {
    CalibrationStage.idle =>
      'The ring is the height reference. Everything measured this session is '
          'taken against it.',
    CalibrationStage.searching =>
      'Frame the whole basket. ${state.framesSeen} frames checked so far.',
    CalibrationStage.settling =>
      'Same answer needed from a run of frames before it is trusted. Keep the '
          'phone still.',
    CalibrationStage.solved =>
      'Solved from ${state.framesWithRim} frames with the ring in view.',
    CalibrationStage.blocked =>
      'The geometry does not resolve from here.',
  };

  List<(String, String)> get _readings {
    final frame = state.solution?.frame;
    final error = state.solution?.reprojectionErrorPx;
    return [
      if (frame != null)
        ('Ring distance', '${frame.rimCentre.length.toStringAsFixed(2)} m'),
      if (error != null && !error.isNaN)
        ('Reprojection', '${error.toStringAsFixed(1)} px'),
      ('Mount drift', '${state.jitterPx.toStringAsFixed(1)} cm'),
    ];
  }
}

class _Reading extends StatelessWidget {
  const _Reading({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: AvType.overline.copyWith(color: AvColors.textFaint),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: AvType.tabular(
            AvType.metricSmall,
          ).copyWith(color: AvColors.textPrimary),
          maxLines: 1,
        ),
      ],
    );
  }
}

class _StageGlyph extends StatelessWidget {
  const _StageGlyph({required this.stage});

  final CalibrationStage stage;

  @override
  Widget build(BuildContext context) {
    final (icon, color, background) = switch (stage) {
      CalibrationStage.idle => (
        Icons.grid_on_rounded,
        AvColors.textFaint,
        AvColors.canvasSunken,
      ),
      CalibrationStage.searching => (
        Icons.search_rounded,
        AvColors.flare,
        AvColors.flareSoft,
      ),
      CalibrationStage.settling => (
        Icons.adjust_rounded,
        AvColors.flare,
        AvColors.flareSoft,
      ),
      CalibrationStage.solved => (
        Icons.check_rounded,
        AvColors.made,
        AvColors.madeSoft,
      ),
      CalibrationStage.blocked => (
        Icons.close_rounded,
        AvColors.miss,
        AvColors.missSoft,
      ),
    };

    final busy =
        stage == CalibrationStage.searching ||
        stage == CalibrationStage.settling;

    return AnimatedContainer(
      duration: AvMotion.normal,
      width: 30,
      height: 30,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Center(
        child: busy
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              )
            : Icon(icon, size: 15, color: color),
      ),
    );
  }
}

class _CalibrationOverlayPainter extends CustomPainter {
  const _CalibrationOverlayPainter({
    required this.progress,
    required this.stage,
    required this.settleProgress,
  });

  final double progress;
  final CalibrationStage stage;
  final double settleProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final scanning =
        stage == CalibrationStage.searching ||
        stage == CalibrationStage.settling;
    final complete = stage == CalibrationStage.solved;
    final found = complete || stage == CalibrationStage.settling;

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
    final rimColor = found
        ? AvColors.overlayHoop
        : stage == CalibrationStage.blocked
        ? AvColors.miss
        : Colors.white;
    canvas.drawOval(
      rim.inflate(6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = rimColor.withValues(alpha: 0.9),
    );

    // The ring fills in as the run of consistent solves builds, so the athlete
    // can see that holding still is what finishes it.
    if (stage == CalibrationStage.settling && settleProgress > 0) {
      canvas.drawArc(
        rim.inflate(6),
        -math.pi / 2,
        2 * math.pi * settleProgress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round
          ..color = AvColors.flare,
      );
    }

    _tag(
      canvas,
      Offset(rim.left, rim.top - 20),
      switch (stage) {
        CalibrationStage.solved => 'RIM 3.05 m',
        CalibrationStage.settling =>
          'LOCKING ${(settleProgress * 100).round()}%',
        CalibrationStage.blocked => 'NO SOLVE',
        _ => 'SEARCHING',
      },
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
      oldDelegate.settleProgress != settleProgress;
}
