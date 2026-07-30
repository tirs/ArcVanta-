import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/av_colors.dart';
import '../../core/theme/av_theme.dart';
import '../../core/theme/av_tokens.dart';
import '../../core/theme/av_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/confidence.dart';
import '../../data/models/pose.dart';
import '../../data/models/session.dart';
import '../../data/models/shot.dart';
import '../../data/seed/drill_catalog.dart';
import '../../design/components/av_button.dart';
import '../../design/components/av_indicators.dart';
import '../../design/painters/overlay_painter.dart';
import '../../design/painters/pose_animator.dart';
import '../../state/app_settings.dart';
import '../../state/live_session.dart';
import '../../state/stores.dart';
import 'camera_stage.dart';

/// The capture screen. Everything here is designed to be read at four metres
/// while breathing hard: one figure at a time, one cue at a time, and controls
/// large enough to hit without looking.
class LiveSessionScreen extends ConsumerStatefulWidget {
  const LiveSessionScreen({
    super.key,
    required this.drillId,
    required this.angle,
  });

  final String drillId;
  final CameraAngle angle;

  @override
  ConsumerState<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends ConsumerState<LiveSessionScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _frameClock;
  final List<Offset> _trail = [];

  late bool _showSkeleton;
  late bool _showTrajectory;
  late bool _showBoxes;
  bool _statsExpanded = false;
  int _cycleMs = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    final settings = ref.read(appSettingsProvider);
    _showSkeleton = settings.showOverlays && settings.showSkeleton;
    _showTrajectory = settings.showOverlays && settings.showTrajectory;
    _showBoxes = settings.showOverlays && settings.showZones;

    _frameClock = createTicker(_onFrame)..start();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = ref.read(liveSessionProvider.notifier);
      controller.configure(DrillCatalog.byId(widget.drillId), widget.angle);
      controller.startCountdown();
    });
  }

  @override
  void dispose() {
    _frameClock.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _onFrame(Duration elapsed) {
    final state = ref.read(liveSessionProvider);
    if (state.status != LiveStatus.running) return;

    final cycleMs = (state.cycleProgress * ShotCycle.total).round();
    final flight = ShotCycle.flightProgress(cycleMs);

    if (cycleMs < _cycleMs) _trail.clear();

    if (flight != null) {
      _trail.add(PoseAnimator.ballAt(cycleMs));
      if (_trail.length > 90) _trail.removeAt(0);
    }

    setState(() => _cycleMs = cycleMs);
  }

  Future<void> _finish() async {
    final controller = ref.read(liveSessionProvider.notifier);
    controller.end();
    final session = controller.finalise();
    ref.read(sessionStoreProvider.notifier).addSession(session);
    if (!mounted) return;
    context.pushReplacement(AppRoute.session(session.id));
  }

  Future<void> _confirmDiscard() async {
    ref.read(liveSessionProvider.notifier).pause();
    final discard = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AvColors.surface,
      builder: (context) => const _DiscardSheet(),
    );
    if (!mounted) return;
    if (discard ?? false) {
      context.pop();
    } else {
      ref.read(liveSessionProvider.notifier).resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(liveSessionProvider);
    final pose = PoseAnimator.at(
      _cycleMs,
      trackingConfidence: state.trackingConfidence,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AvTheme.inkOverlay,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _confirmDiscard();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              CameraStage(
                overlay: CustomPaint(
                  painter: AnalysisOverlayPainter(
                    pose: pose,
                    ball: PoseAnimator.ballAt(_cycleMs),
                    trail: _trail,
                    phase: state.phase,
                    showSkeleton: _showSkeleton,
                    showTrajectory: _showTrajectory,
                    showBoxes: _showBoxes,
                    trackingConfidence: state.trackingConfidence,
                    textDirection: Directionality.of(context),
                    highlightRelease: state.phase == ShotPhaseKind.release,
                  ),
                ),
              ),
              const _EdgeScrim(),
              SafeArea(
                child: Column(
                  children: [
                    _TopBar(
                      state: state,
                      onClose: _confirmDiscard,
                      showSkeleton: _showSkeleton,
                      showTrajectory: _showTrajectory,
                      showBoxes: _showBoxes,
                      onToggleSkeleton: () =>
                          setState(() => _showSkeleton = !_showSkeleton),
                      onToggleTrajectory: () =>
                          setState(() => _showTrajectory = !_showTrajectory),
                      onToggleBoxes: () =>
                          setState(() => _showBoxes = !_showBoxes),
                    ),
                    const Spacer(),
                    if (state.activeCue != null)
                      _LiveCueBanner(cue: state.activeCue!),
                    if (state.pendingConfirmation != null)
                      _ConfirmationPrompt(
                        onConfirm: (result) => ref
                            .read(liveSessionProvider.notifier)
                            .confirmPending(result),
                      ),
                    _PhaseStrip(phase: state.phase),
                    _Scoreboard(
                      state: state,
                      expanded: _statsExpanded,
                      onToggle: () =>
                          setState(() => _statsExpanded = !_statsExpanded),
                    ),
                    _Controls(
                      state: state,
                      onPause: () =>
                          ref.read(liveSessionProvider.notifier).pause(),
                      onResume: () =>
                          ref.read(liveSessionProvider.notifier).resume(),
                      onCorrect: (result) => ref
                          .read(liveSessionProvider.notifier)
                          .correctLast(result),
                      onFinish: _finish,
                    ),
                  ],
                ),
              ),
              if (state.status == LiveStatus.countdown)
                _CountdownVeil(value: state.countdownRemaining),
              if (state.lastResultFlash != null)
                _ResultFlash(
                  key: ValueKey(state.lastResultFlash!.id),
                  shot: state.lastResultFlash!,
                  onDone: () =>
                      ref.read(liveSessionProvider.notifier).dismissFlash(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EdgeScrim extends StatelessWidget {
  const _EdgeScrim();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AvColors.scrimStrong.withValues(alpha: 0.72),
              Colors.transparent,
              Colors.transparent,
              AvColors.scrimStrong.withValues(alpha: 0.88),
            ],
            stops: const [0, 0.22, 0.48, 1],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.state,
    required this.onClose,
    required this.showSkeleton,
    required this.showTrajectory,
    required this.showBoxes,
    required this.onToggleSkeleton,
    required this.onToggleTrajectory,
    required this.onToggleBoxes,
  });

  final LiveSessionState state;
  final VoidCallback onClose;
  final bool showSkeleton;
  final bool showTrajectory;
  final bool showBoxes;
  final VoidCallback onToggleSkeleton;
  final VoidCallback onToggleTrajectory;
  final VoidCallback onToggleBoxes;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AvSpace.md,
        AvSpace.sm,
        AvSpace.md,
        0,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _GlassButton(
                icon: Icons.close_rounded,
                onTap: onClose,
                semanticLabel: 'End session',
              ),
              const SizedBox(width: AvSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.drill.name,
                      style: AvType.titleSmall.copyWith(color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${state.angle.label} view \u00B7 '
                      '${Fmt.clock(state.elapsed)}',
                      style: AvType.tabular(AvType.caption).copyWith(
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
              _TrackingChip(state: state),
            ],
          ),
          const SizedBox(height: AvSpace.sm),
          Row(
            children: [
              _OverlayToggle(
                label: 'Skeleton',
                active: showSkeleton,
                color: AvColors.overlaySkeleton,
                onTap: onToggleSkeleton,
              ),
              const SizedBox(width: AvSpace.xs),
              _OverlayToggle(
                label: 'Arc',
                active: showTrajectory,
                color: AvColors.overlayTrace,
                onTap: onToggleTrajectory,
              ),
              const SizedBox(width: AvSpace.xs),
              _OverlayToggle(
                label: 'Boxes',
                active: showBoxes,
                color: AvColors.overlayHoop,
                onTap: onToggleBoxes,
              ),
              const Spacer(),
              _Telemetry(state: state),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrackingChip extends StatelessWidget {
  const _TrackingChip({required this.state});

  final LiveSessionState state;

  @override
  Widget build(BuildContext context) {
    final level = ConfidenceLevel.fromScore(state.trackingConfidence);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AvColors.scrimSoft,
        borderRadius: AvRadius.pill,
        border: Border.all(color: level.color.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: level.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'TRACKING ${(state.trackingConfidence * 100).round()}',
            style: AvType.tabular(AvType.overline).copyWith(
              color: Colors.white,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class _Telemetry extends StatelessWidget {
  const _Telemetry({required this.state});

  final LiveSessionState state;

  @override
  Widget build(BuildContext context) {
    final thermal = state.thermalHeadroom;
    return Row(
      children: [
        Text(
          '${state.processedFps} FPS',
          style: AvType.tabular(AvType.overline).copyWith(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 9,
          ),
        ),
        const SizedBox(width: AvSpace.xs),
        Icon(
          thermal > 0.6
              ? Icons.thermostat_rounded
              : Icons.local_fire_department_rounded,
          size: 13,
          color: thermal > 0.6
              ? Colors.white.withValues(alpha: 0.7)
              : AvColors.caution,
        ),
        Text(
          '${(thermal * 100).round()}',
          style: AvType.tabular(AvType.overline).copyWith(
            color: thermal > 0.6
                ? Colors.white.withValues(alpha: 0.7)
                : AvColors.caution,
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

class _OverlayToggle extends StatelessWidget {
  const _OverlayToggle({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: active,
      button: true,
      label: '$label overlay',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AvMotion.fast,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? color.withValues(alpha: 0.22)
                : AvColors.scrimSoft.withValues(alpha: 0.6),
            borderRadius: AvRadius.pill,
            border: Border.all(
              color: active
                  ? color.withValues(alpha: 0.85)
                  : AvColors.scrimHairline,
            ),
          ),
          child: Text(
            label.toUpperCase(),
            style: AvType.overline.copyWith(
              color: active ? color : Colors.white.withValues(alpha: 0.6),
              fontSize: 9,
            ),
          ),
        ),
      ),
    );
  }
}

class _PhaseStrip extends StatelessWidget {
  const _PhaseStrip({required this.phase});

  final ShotPhaseKind phase;

  static const _tracked = [
    ShotPhaseKind.ready,
    ShotPhaseKind.dip,
    ShotPhaseKind.load,
    ShotPhaseKind.upward,
    ShotPhaseKind.setPoint,
    ShotPhaseKind.release,
    ShotPhaseKind.flight,
    ShotPhaseKind.landing,
  ];

  @override
  Widget build(BuildContext context) {
    final index = _tracked.indexOf(phase);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AvSpace.md,
        AvSpace.xs,
        AvSpace.md,
        AvSpace.xs,
      ),
      child: Row(
        children: [
          for (var i = 0; i < _tracked.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: AvMotion.fast,
                    height: 3,
                    decoration: BoxDecoration(
                      color: i <= index && index >= 0
                          ? AvColors.flare
                          : Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (i == index)
                    Text(
                      _tracked[i].label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: AvType.overline.copyWith(
                        color: AvColors.flare,
                        fontSize: 8.5,
                      ),
                    )
                  else
                    const SizedBox(height: 11),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Scoreboard extends StatelessWidget {
  const _Scoreboard({
    required this.state,
    required this.expanded,
    required this.onToggle,
  });

  final LiveSessionState state;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvSpace.md),
      child: GestureDetector(
        onTap: onToggle,
        child: AnimatedContainer(
          duration: AvMotion.normal,
          curve: AvMotion.emphasized,
          padding: const EdgeInsets.all(AvSpace.md),
          decoration: BoxDecoration(
            color: AvColors.scrimStrong,
            borderRadius: AvRadius.allLg,
            border: Border.all(color: AvColors.scrimHairline),
            boxShadow: AvShadow.onInk,
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _BigFigure(
                    value: '${state.makes}',
                    caption: 'of ${state.attemptCount}',
                    color: Colors.white,
                  ),
                  const SizedBox(width: AvSpace.md),
                  Container(
                    width: 1,
                    height: 38,
                    color: AvColors.scrimHairline,
                  ),
                  const SizedBox(width: AvSpace.md),
                  _BigFigure(
                    value: state.attemptCount == 0
                        ? '\u2014'
                        : '${state.percentage.round()}',
                    caption: 'per cent',
                    color: AvColors.flare,
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'STREAK ${state.streak}',
                        style: AvType.tabular(AvType.overline).copyWith(
                          color: state.streak >= 3
                              ? AvColors.made
                              : Colors.white.withValues(alpha: 0.75),
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 108,
                        child: AvMeter(
                          value: state.targetProgress,
                          color: AvColors.flare,
                          trackColor: Colors.white24,
                          height: 5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'TARGET ${state.drill.targetMakes} MAKES',
                        style: AvType.tabular(AvType.overline).copyWith(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 8.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              AnimatedSize(
                duration: AvMotion.normal,
                curve: AvMotion.emphasized,
                child: expanded
                    ? _ExpandedStats(state: state)
                    : const SizedBox(width: double.infinity),
              ),
              const SizedBox(height: AvSpace.xs),
              Icon(
                expanded
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.keyboard_arrow_up_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpandedStats extends StatelessWidget {
  const _ExpandedStats({required this.state});

  final LiveSessionState state;

  @override
  Widget build(BuildContext context) {
    final graded = state.shots
        .where((s) => s.confidence.isAuthoritative)
        .toList(growable: false);

    double average(double Function(Shot) selector) => graded.isEmpty
        ? 0
        : graded.map(selector).reduce((a, b) => a + b) / graded.length;

    return Column(
      children: [
        const SizedBox(height: AvSpace.md),
        Container(height: 1, color: AvColors.scrimHairline),
        const SizedBox(height: AvSpace.md),
        Row(
          children: [
            _MiniStat(
              label: 'Release',
              value: graded.isEmpty
                  ? '\u2014'
                  : '${average((s) => s.releaseAngle).toStringAsFixed(0)}\u00B0',
            ),
            _MiniStat(
              label: 'Entry',
              value: graded.isEmpty
                  ? '\u2014'
                  : '${average((s) => s.entryAngle).toStringAsFixed(0)}\u00B0',
            ),
            _MiniStat(
              label: 'Knee',
              value: graded.isEmpty
                  ? '\u2014'
                  : '${average((s) => s.kneeFlexion).toStringAsFixed(0)}\u00B0',
            ),
            _MiniStat(
              label: 'Drift',
              value: graded.isEmpty
                  ? '\u2014'
                  : '${average((s) => s.lateralDeviationCm).toStringAsFixed(0)} cm',
            ),
          ],
        ),
        const SizedBox(height: AvSpace.md),
        AvOutcomeBar(
          made: state.makes,
          missed: state.shots
              .where((s) => s.result == ShotResult.missed)
              .length,
          uncertain: state.shots
              .where((s) => s.result == ShotResult.uncertain)
              .length,
        ),
        const SizedBox(height: AvSpace.sm),
        SizedBox(
          height: 26,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            reverse: true,
            itemCount: state.shots.length,
            separatorBuilder: (_, __) => const SizedBox(width: 4),
            itemBuilder: (context, index) {
              final shot = state.shots[state.shots.length - 1 - index];
              return _ShotDot(shot: shot);
            },
          ),
        ),
      ],
    );
  }
}

class _ShotDot extends StatelessWidget {
  const _ShotDot({required this.shot});

  final Shot shot;

  @override
  Widget build(BuildContext context) {
    final color = switch (shot.result) {
      ShotResult.made => AvColors.made,
      ShotResult.missed => AvColors.miss,
      ShotResult.uncertain => AvColors.caution,
      ShotResult.blocked => AvColors.insight,
      ShotResult.invalid => AvColors.unavailable,
    };
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.8)),
      ),
      child: Text(
        '${shot.index}',
        style: AvType.tabular(AvType.overline)
            .copyWith(color: Colors.white, fontSize: 9),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AvType.overline.copyWith(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 8.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: AvType.tabular(AvType.metricSmall)
                .copyWith(color: Colors.white, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _BigFigure extends StatelessWidget {
  const _BigFigure({
    required this.value,
    required this.caption,
    required this.color,
  });

  final String value;
  final String caption;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: AvType.tabular(AvType.metricLarge)
              .copyWith(color: color, fontSize: 38),
        ),
        const SizedBox(height: 2),
        Text(
          caption.toUpperCase(),
          style: AvType.overline.copyWith(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.state,
    required this.onPause,
    required this.onResume,
    required this.onCorrect,
    required this.onFinish,
  });

  final LiveSessionState state;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final ValueChanged<ShotResult> onCorrect;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final paused = state.status == LiveStatus.paused;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AvSpace.md,
        AvSpace.sm,
        AvSpace.md,
        AvSpace.md,
      ),
      child: Row(
        children: [
          _GlassButton(
            icon: Icons.undo_rounded,
            semanticLabel: 'Mark last shot as a miss',
            enabled: state.shots.isNotEmpty,
            onTap: () => onCorrect(ShotResult.missed),
            caption: 'Miss',
          ),
          const SizedBox(width: AvSpace.sm),
          _GlassButton(
            icon: Icons.check_rounded,
            semanticLabel: 'Mark last shot as a make',
            enabled: state.shots.isNotEmpty,
            onTap: () => onCorrect(ShotResult.made),
            caption: 'Make',
          ),
          const Spacer(),
          _PrimaryControl(
            icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            label: paused ? 'Resume' : 'Pause',
            onTap: paused ? onResume : onPause,
          ),
          const Spacer(),
          _GlassButton(
            icon: Icons.flag_rounded,
            semanticLabel: 'Finish session',
            onTap: onFinish,
            caption: 'Finish',
            highlight: true,
          ),
        ],
      ),
    );
  }
}

class _PrimaryControl extends StatelessWidget {
  const _PrimaryControl({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            gradient: AvGradients.flare,
            shape: BoxShape.circle,
            boxShadow: AvShadow.glow(AvColors.flare),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.24),
              width: 2,
            ),
          ),
          child: Icon(icon, size: 34, color: Colors.white),
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.caption,
    this.enabled = true,
    this.highlight = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;
  final String? caption;
  final bool enabled;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final foreground = enabled
        ? (highlight ? AvColors.flare : Colors.white)
        : Colors.white.withValues(alpha: 0.35);

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AvColors.scrimSoft,
                shape: BoxShape.circle,
                border: Border.all(
                  color: highlight
                      ? AvColors.flare.withValues(alpha: 0.6)
                      : AvColors.scrimHairline,
                ),
              ),
              child: Icon(icon, size: 22, color: foreground),
            ),
            if (caption != null) ...[
              const SizedBox(height: 4),
              Text(
                caption!.toUpperCase(),
                style: AvType.overline.copyWith(
                  color: foreground,
                  fontSize: 8.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LiveCueBanner extends StatelessWidget {
  const _LiveCueBanner({required this.cue});

  final CoachingCue cue;

  @override
  Widget build(BuildContext context) {
    final accent = switch (cue.priority) {
      CuePriority.primary => AvColors.flare,
      CuePriority.supporting => AvColors.court,
      CuePriority.reinforcement => AvColors.made,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AvSpace.md,
        0,
        AvSpace.md,
        AvSpace.sm,
      ),
      child: AnimatedSwitcher(
        duration: AvMotion.normal,
        child: Container(
          key: ValueKey(cue.id),
          padding: const EdgeInsets.all(AvSpace.sm),
          decoration: BoxDecoration(
            color: AvColors.scrimStrong,
            borderRadius: AvRadius.allMd,
            border: Border(
              left: BorderSide(color: accent, width: 3),
              top: BorderSide(color: AvColors.scrimHairline),
              right: BorderSide(color: AvColors.scrimHairline),
              bottom: BorderSide(color: AvColors.scrimHairline),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.campaign_rounded, size: 18, color: accent),
              const SizedBox(width: AvSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cue.headline,
                      style:
                          AvType.titleSmall.copyWith(color: Colors.white),
                    ),
                    Text(
                      cue.detail,
                      style: AvType.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              AvConfidenceBadge(level: cue.confidence, compact: true, onInk: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmationPrompt extends StatelessWidget {
  const _ConfirmationPrompt({required this.onConfirm});

  final ValueChanged<ShotResult> onConfirm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AvSpace.md,
        0,
        AvSpace.md,
        AvSpace.sm,
      ),
      child: Container(
        padding: const EdgeInsets.all(AvSpace.sm),
        decoration: BoxDecoration(
          color: AvColors.caution.withValues(alpha: 0.16),
          borderRadius: AvRadius.allMd,
          border: Border.all(color: AvColors.caution),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.help_outline_rounded,
              size: 18,
              color: AvColors.caution,
            ),
            const SizedBox(width: AvSpace.sm),
            Expanded(
              child: Text(
                'That one was blocked from view. Did it go in?',
                style: AvType.titleSmall.copyWith(color: Colors.white),
              ),
            ),
            _MiniAction(
              label: 'No',
              color: AvColors.miss,
              onTap: () => onConfirm(ShotResult.missed),
            ),
            const SizedBox(width: AvSpace.xs),
            _MiniAction(
              label: 'Yes',
              color: AvColors.made,
              onTap: () => onConfirm(ShotResult.made),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: AvRadius.pill,
        ),
        child: Text(
          label,
          style: AvType.label.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

class _CountdownVeil extends StatelessWidget {
  const _CountdownVeil({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AvColors.scrimStrong,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'GET READY',
            style: AvType.overline.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: AvSpace.md),
          TweenAnimationBuilder<double>(
            key: ValueKey(value),
            tween: Tween(begin: 0.7, end: 1),
            duration: AvMotion.slow,
            curve: AvMotion.emphasized,
            builder: (context, scale, child) => Transform.scale(
              scale: scale,
              child: child,
            ),
            child: Text(
              '$value',
              style: AvType.tabular(AvType.metricLarge).copyWith(
                color: AvColors.flare,
                fontSize: 132,
              ),
            ),
          ),
          const SizedBox(height: AvSpace.md),
          Text(
            'Step into the framing guide',
            style: AvType.body.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultFlash extends StatefulWidget {
  const _ResultFlash({super.key, required this.shot, required this.onDone});

  final Shot shot;
  final VoidCallback onDone;

  @override
  State<_ResultFlash> createState() => _ResultFlashState();
}

class _ResultFlashState extends State<_ResultFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final made = widget.shot.isMake;
    final color = made
        ? AvColors.made
        : widget.shot.result == ShotResult.uncertain
            ? AvColors.caution
            : AvColors.miss;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final opacity = t < 0.15 ? t / 0.15 : (1 - (t - 0.15) / 0.85);
          return Opacity(
            opacity: opacity.clamp(0, 1),
            child: Align(
              alignment: const Alignment(0, -0.34),
              child: Transform.scale(
                scale: 0.9 + t * 0.16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AvSpace.lg,
                    vertical: AvSpace.sm,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: AvRadius.pill,
                    boxShadow: AvShadow.glow(color),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        made
                            ? Icons.sports_basketball_rounded
                            : widget.shot.result == ShotResult.uncertain
                                ? Icons.help_outline_rounded
                                : Icons.close_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: AvSpace.xs),
                      Text(
                        widget.shot.outcomeDetail.label.toUpperCase(),
                        style: AvType.overline.copyWith(
                          color: Colors.white,
                          fontSize: 13,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DiscardSheet extends StatelessWidget {
  const _DiscardSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AvSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Leave this session?', style: AvType.headingSmall.primary),
            const SizedBox(height: AvSpace.xs),
            Text(
              'Shots recorded so far will be discarded. Use Finish instead to '
              'save the session and see your summary.',
              style: AvType.bodySmall.muted,
            ),
            const SizedBox(height: AvSpace.lg),
            Row(
              children: [
                Expanded(
                  child: AvButton(
                    label: 'Keep shooting',
                    variant: AvButtonVariant.outline,
                    expand: true,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: AvSpace.sm),
                Expanded(
                  child: AvButton(
                    label: 'Discard',
                    variant: AvButtonVariant.danger,
                    expand: true,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
