import 'dart:async';

import 'package:flutter/material.dart';
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
import '../../state/app_settings.dart';
import '../../state/capture_pipeline.dart';
import '../../state/live_session.dart';
import '../../state/session_events.dart';
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

class _LiveSessionScreenState extends ConsumerState<LiveSessionScreen> {
  late bool _showSkeleton;
  late bool _showTrajectory;
  late bool _showBoxes;
  bool _statsExpanded = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    final settings = ref.read(appSettingsProvider);
    _showSkeleton = settings.showOverlays && settings.showSkeleton;
    _showTrajectory = settings.showOverlays && settings.showTrajectory;
    _showBoxes = settings.showOverlays && settings.showZones;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = ref.read(liveSessionProvider.notifier);
      controller.configure(DrillCatalog.byId(widget.drillId), widget.angle);
      controller.startCountdown();
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _finish() async {
    final controller = ref.read(liveSessionProvider.notifier);
    controller.end();
    final session = controller.finalise();
    // Committed before navigating: the summary screen reads the session back
    // out of the store, and losing a session someone just shot is the one
    // failure this app cannot have.
    await ref.read(sessionStoreProvider.notifier).addSession(session);
    await ref.read(sessionEventsProvider).recordCompleted(session);
    if (!mounted) return;
    // Placement and calibration are setup steps, not places to go back to once
    // the session is in the book. Reset to the drill list, then show the
    // summary on top of it so Back lands somewhere that makes sense.
    context.go(AppRoute.drills);
    context.push(AppRoute.session(session.id));
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
    final settings = ref.watch(appSettingsProvider);

    final pose = state.pose;

    // A cue that is only spoken leaves nothing behind for an athlete who
    // missed it, or who has the volume down. Captions off is only honoured
    // when the voice is actually delivering the cue some other way.
    final showCaptions =
        settings.captionsForAudioCoaching || !settings.spokenFeedback;

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
                overlay: pose == null
                    ? null
                    : CustomPaint(
                        painter: AnalysisOverlayPainter(
                          pose: pose,
                          ball: state.ball ?? pose[PoseJoint.rightWrist],
                          trail: state.ballTrail,
                          phase: state.phase,
                          rim: state.rim,
                          backboard: state.backboard,
                          showSkeleton: _showSkeleton,
                          showTrajectory: _showTrajectory,
                          showBoxes: _showBoxes,
                          trackingConfidence: state.trackingConfidence ?? 0,
                          textDirection: Directionality.of(context),
                          highlightRelease:
                              state.phase == ShotPhaseKind.release,
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
                    if (state.activeCue != null && showCaptions)
                      _LiveCueBanner(cue: state.activeCue!),
                    if (state.pendingConfirmation != null)
                      _ConfirmationPrompt(
                        onConfirm: (result) => ref
                            .read(liveSessionProvider.notifier)
                            .confirmPending(result),
                      ),
                    _PhaseStrip(phase: state.phase),
                    if (state.status == LiveStatus.paused || _statsExpanded)
                      _Scoreboard(
                        state: state,
                        expanded: _statsExpanded,
                        onToggle: () =>
                            setState(() => _statsExpanded = !_statsExpanded),
                      )
                    else
                      _MiniScore(
                        state: state,
                        onTap: () =>
                            setState(() => _statsExpanded = true),
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

class _TopBar extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(pipelineStatusProvider).valueOrNull?.isLive ?? false;
    final texture = ref.watch(previewTextureProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AvSpace.md, AvSpace.sm, AvSpace.md, 0),
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
                      style: AvType.tabular(
                        AvType.caption,
                      ).copyWith(color: Colors.white.withValues(alpha: 0.72)),
                    ),
                  ],
                ),
              ),
              _TrackingChip(state: state, live: live),
            ],
          ),
          const SizedBox(height: AvSpace.sm),
          // Scrolls rather than wraps: a second row of chips is what pushes
          // the controls off the bottom of a phone held sideways, and the HUD
          // has to stay one line tall whatever is in it.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: AvSpace.xs,
              children: [
                // First in the row so it can never be the chip that scrolls
                // out of sight. It is the one the athlete has to see.
                ValueListenableBuilder<int?>(
                  valueListenable: texture,
                  builder: (context, id, _) {
                    if (live && id != null) return const SizedBox.shrink();
                    return _SourceChip(
                      label: live ? 'NO PREVIEW' : 'SIMULATED',
                    );
                  },
                ),
                _OverlayToggle(
                    label: 'Skeleton',
                    active: showSkeleton,
                    color: AvColors.overlaySkeleton,
                    onTap: onToggleSkeleton,
                  ),
                  _OverlayToggle(
                    label: 'Arc',
                    active: showTrajectory,
                    color: AvColors.overlayTrace,
                    onTap: onToggleTrajectory,
                  ),
                _OverlayToggle(
                    label: 'Boxes',
                    active: showBoxes,
                    color: AvColors.overlayHoop,
                    onTap: onToggleBoxes,
                  ),
                _Telemetry(state: state),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Says plainly where what is on screen came from.
///
/// Two different admissions share one chip: the measurements are generated,
/// or they are real but the picture behind them is not the camera. Both mean
/// the athlete should not read the scene literally.
class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AvColors.caution.withValues(alpha: 0.22),
        borderRadius: AvRadius.pill,
        border: Border.all(color: AvColors.caution.withValues(alpha: 0.65)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.science_rounded,
            size: 11,
            color: AvColors.caution,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AvType.overline.copyWith(
              color: AvColors.caution,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingChip extends StatelessWidget {
  const _TrackingChip({required this.state, required this.live});

  final LiveSessionState state;

  /// Whether anything is actually tracking. A confidence score is a claim
  /// about how well the models can see the athlete, so with no models the
  /// chip has to say that rather than report the simulator's own number.
  final bool live;

  @override
  Widget build(BuildContext context) {
    final confidence = live ? state.trackingConfidence : null;
    final level = confidence == null
        ? ConfidenceLevel.low
        : ConfidenceLevel.fromScore(confidence);
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
            live
                ? (confidence == null
                      ? 'TRACKING —'
                      : 'TRACKING ${(confidence * 100).round()}')
                : 'NOT TRACKING',
            style: AvType.tabular(
              AvType.overline,
            ).copyWith(color: Colors.white, fontSize: 9),
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
          state.processedFps == null ? '— FPS' : '${state.processedFps} FPS',
          style: AvType.tabular(
            AvType.overline,
          ).copyWith(color: Colors.white.withValues(alpha: 0.7), fontSize: 9),
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
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < _tracked.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: AnimatedContainer(
                    duration: AvMotion.fast,
                    height: 3,
                    decoration: BoxDecoration(
                      color: i <= index && index >= 0
                          ? AvColors.flare
                          : Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          // The label sits over the whole strip rather than inside one segment,
          // which is a fraction of the width and would clip every long phase.
          Align(
            alignment: index < 0
                ? Alignment.center
                : Alignment(-1 + 2 * ((index + 0.5) / _tracked.length), 0),
            child: Text(
              index < 0 ? '' : _tracked[index].label.toUpperCase(),
              maxLines: 1,
              softWrap: false,
              style: AvType.overline.copyWith(
                color: AvColors.flare,
                fontSize: 8.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact score pill shown during active play so the camera is not obscured.
class _MiniScore extends StatelessWidget {
  const _MiniScore({required this.state, required this.onTap});

  final LiveSessionState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AvSpace.xl,
          vertical: AvSpace.xs,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AvSpace.md,
          vertical: AvSpace.xs,
        ),
        decoration: BoxDecoration(
          color: AvColors.scrimStrong,
          borderRadius: AvRadius.pill,
          border: Border.all(color: AvColors.scrimHairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${state.makes}',
              style: AvType.tabular(AvType.headingSmall).copyWith(
                color: Colors.white,
              ),
            ),
            Text(
              ' / ${state.attemptCount}',
              style: AvType.tabular(AvType.bodySmall).copyWith(
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: AvSpace.sm),
            Container(
              width: 1,
              height: 18,
              color: AvColors.scrimHairline,
            ),
            const SizedBox(width: AvSpace.sm),
            Text(
              state.attemptCount == 0
                  ? '\u2014'
                  : '${state.percentage.round()}%',
              style: AvType.tabular(AvType.titleMedium).copyWith(
                color: AvColors.flare,
              ),
            ),
            const SizedBox(width: AvSpace.sm),
            Icon(
              Icons.keyboard_arrow_up_rounded,
              size: 16,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ],
        ),
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
              // Read at four metres on anything from a small phone upward, so
              // both halves scale down together rather than one clipping.
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.bottomLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
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
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AvSpace.sm),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'STREAK ${state.streak}',
                            maxLines: 1,
                            style: AvType.tabular(AvType.overline).copyWith(
                              color: state.streak >= 3
                                  ? AvColors.made
                                  : Colors.white.withValues(alpha: 0.75),
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 108),
                          child: AvMeter(
                            value: state.targetProgress,
                            color: AvColors.flare,
                            trackColor: Colors.white24,
                            height: 5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'TARGET ${state.drill.targetMakes} MAKES',
                            maxLines: 1,
                            style: AvType.tabular(AvType.overline).copyWith(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 8.5,
                            ),
                          ),
                        ),
                      ],
                    ),
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
        style: AvType.tabular(
          AvType.overline,
        ).copyWith(color: Colors.white, fontSize: 9),
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
            style: AvType.tabular(
              AvType.metricSmall,
            ).copyWith(color: Colors.white, fontSize: 15),
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
          style: AvType.tabular(
            AvType.metricLarge,
          ).copyWith(color: color, fontSize: 38),
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

class _Controls extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final paused = state.status == LiveStatus.paused;
    final leftHanded = ref.watch(
      appSettingsProvider.select((s) => s.leftHandedLayout),
    );

    final corrections = [
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
    ];

    final finish = _GlassButton(
      icon: Icons.flag_rounded,
      semanticLabel: 'Finish session',
      onTap: onFinish,
      caption: 'Finish',
      highlight: true,
    );

    // Mirrored so the shot corrections sit under the thumb that is free. A
    // left-handed shooter holds the phone in the right hand between reps.
    final leading = leftHanded ? [finish] : corrections;
    final trailing = leftHanded ? corrections.reversed.toList() : [finish];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AvSpace.md,
        AvSpace.sm,
        AvSpace.md,
        AvSpace.md,
      ),
      child: Row(
        children: [
          ...leading,
          const Spacer(),
          _PrimaryControl(
            icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            label: paused ? 'Resume' : 'Pause',
            onTap: paused ? onResume : onPause,
          ),
          const Spacer(),
          ...trailing,
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
      padding: const EdgeInsets.fromLTRB(AvSpace.md, 0, AvSpace.md, AvSpace.sm),
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
                      style: AvType.titleSmall.copyWith(color: Colors.white),
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
              AvConfidenceBadge(
                level: cue.confidence,
                compact: true,
                onInk: true,
              ),
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
      padding: const EdgeInsets.fromLTRB(AvSpace.md, 0, AvSpace.md, AvSpace.sm),
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
        decoration: BoxDecoration(color: color, borderRadius: AvRadius.pill),
        child: Text(label, style: AvType.label.copyWith(color: Colors.white)),
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
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Text(
              '$value',
              style: AvType.tabular(
                AvType.metricLarge,
              ).copyWith(color: AvColors.flare, fontSize: 132),
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
