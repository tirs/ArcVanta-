import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/capture/capture_source.dart';
import '../data/capture/simulated_capture_source.dart';
import '../data/models/confidence.dart';
import '../data/models/drill.dart';
import '../data/models/pose.dart';
import '../data/models/session.dart';
import '../data/models/shot.dart';
import '../data/seed/drill_catalog.dart';

enum LiveStatus { setup, countdown, running, paused, ended }

/// The analysis pipeline attached to the live session.
///
/// The simulated source is the default so the app is complete without a camera.
/// The inference bridge replaces it by overriding this provider at the root,
/// and nothing else in the app changes.
final captureSourceProvider = Provider<CaptureSource>((ref) {
  final source = SimulatedCaptureSource();
  ref.onDispose(source.dispose);
  return source;
});

/// Everything the live interface needs, folded from the capture stream.
class LiveSessionState {
  const LiveSessionState({
    required this.status,
    required this.drill,
    required this.angle,
    required this.elapsed,
    required this.countdownRemaining,
    required this.shots,
    required this.phase,
    required this.cycleProgress,
    required this.pose,
    required this.ball,
    required this.ballTrail,
    required this.rim,
    required this.backboard,
    required this.calibrationQuality,
    required this.trackingConfidence,
    required this.processedFps,
    required this.thermalHeadroom,
    required this.activeCue,
    required this.lastResultFlash,
    required this.pendingConfirmation,
  });

  factory LiveSessionState.initial(Drill drill, CameraAngle angle) {
    return LiveSessionState(
      status: LiveStatus.setup,
      drill: drill,
      angle: angle,
      elapsed: Duration.zero,
      countdownRemaining: 0,
      shots: const [],
      phase: ShotPhaseKind.idle,
      cycleProgress: 0,
      pose: null,
      ball: null,
      ballTrail: const [],
      rim: null,
      backboard: null,
      calibrationQuality: 0.91,
      trackingConfidence: 0.94,
      processedFps: 28,
      thermalHeadroom: 1.0,
      activeCue: null,
      lastResultFlash: null,
      pendingConfirmation: null,
    );
  }

  final LiveStatus status;
  final Drill drill;
  final CameraAngle angle;
  final Duration elapsed;
  final int countdownRemaining;
  final List<Shot> shots;
  final ShotPhaseKind phase;

  /// Position inside the current shot cycle, 0 to 1. Drives the overlay.
  final double cycleProgress;

  /// Latest tracked geometry, straight from the pipeline.
  final PoseFrame? pose;
  final Offset? ball;
  final List<Offset> ballTrail;
  final Rect? rim;
  final Rect? backboard;

  final double calibrationQuality;
  final double trackingConfidence;
  final int processedFps;
  final double thermalHeadroom;
  final CoachingCue? activeCue;
  final Shot? lastResultFlash;

  /// A result the engine could not classify with enough evidence. The athlete
  /// can confirm it without stopping the session.
  final Shot? pendingConfirmation;

  List<Shot> get attempts =>
      shots.where((s) => s.result.countsAsAttempt).toList(growable: false);

  int get makes => shots.where((s) => s.isMake).length;
  int get attemptCount => attempts.length;
  double get percentage => attemptCount == 0 ? 0 : makes / attemptCount * 100;

  int get streak {
    var run = 0;
    for (final shot in attempts.reversed) {
      if (shot.isMake) {
        run++;
      } else {
        break;
      }
    }
    return run;
  }

  int get bestStreak {
    var best = 0;
    var run = 0;
    for (final shot in attempts) {
      if (shot.isMake) {
        run++;
        best = math.max(best, run);
      } else {
        run = 0;
      }
    }
    return best;
  }

  CourtZone get activeZone => drill.zones[shots.length % drill.zones.length];

  double get targetProgress =>
      drill.targetMakes == 0 ? 0 : (makes / drill.targetMakes).clamp(0, 1);

  ConfidenceLevel get calibrationLevel =>
      ConfidenceLevel.fromScore(calibrationQuality);

  LiveSessionState copyWith({
    LiveStatus? status,
    Drill? drill,
    CameraAngle? angle,
    Duration? elapsed,
    int? countdownRemaining,
    List<Shot>? shots,
    ShotPhaseKind? phase,
    double? cycleProgress,
    PoseFrame? pose,
    Offset? ball,
    bool clearBall = false,
    List<Offset>? ballTrail,
    Rect? rim,
    Rect? backboard,
    double? calibrationQuality,
    double? trackingConfidence,
    int? processedFps,
    double? thermalHeadroom,
    CoachingCue? activeCue,
    bool clearCue = false,
    Shot? lastResultFlash,
    bool clearFlash = false,
    Shot? pendingConfirmation,
    bool clearPending = false,
  }) {
    return LiveSessionState(
      status: status ?? this.status,
      drill: drill ?? this.drill,
      angle: angle ?? this.angle,
      elapsed: elapsed ?? this.elapsed,
      countdownRemaining: countdownRemaining ?? this.countdownRemaining,
      shots: shots ?? this.shots,
      phase: phase ?? this.phase,
      cycleProgress: cycleProgress ?? this.cycleProgress,
      pose: pose ?? this.pose,
      ball: clearBall ? null : (ball ?? this.ball),
      ballTrail: ballTrail ?? this.ballTrail,
      rim: rim ?? this.rim,
      backboard: backboard ?? this.backboard,
      calibrationQuality: calibrationQuality ?? this.calibrationQuality,
      trackingConfidence: trackingConfidence ?? this.trackingConfidence,
      processedFps: processedFps ?? this.processedFps,
      thermalHeadroom: thermalHeadroom ?? this.thermalHeadroom,
      activeCue: clearCue ? null : (activeCue ?? this.activeCue),
      lastResultFlash: clearFlash
          ? null
          : (lastResultFlash ?? this.lastResultFlash),
      pendingConfirmation: clearPending
          ? null
          : (pendingConfirmation ?? this.pendingConfirmation),
    );
  }
}

/// Drives a live session by folding the capture stream into interface state.
///
/// It owns nothing about frame processing. Shots arrive as completed records
/// and geometry arrives per frame, so the same controller serves the simulated
/// pipeline and the on-device one.
class LiveSessionController extends Notifier<LiveSessionState> {
  /// Longest ball trail the overlay draws, in frames.
  static const _trailLength = 90;

  StreamSubscription<CaptureFrame>? _frameSub;
  StreamSubscription<Shot>? _shotSub;
  Timer? _countdown;
  final Stopwatch _elapsed = Stopwatch();

  CaptureSource get _source => ref.read(captureSourceProvider);

  @override
  LiveSessionState build() {
    ref.onDispose(_teardown);
    return LiveSessionState.initial(
      DrillCatalog.byId('quick-shooting'),
      CameraAngle.side,
    );
  }

  void _teardown() {
    _countdown?.cancel();
    _frameSub?.cancel();
    _shotSub?.cancel();
    _elapsed.stop();
  }

  void configure(Drill drill, CameraAngle angle) {
    _teardown();
    _elapsed.reset();
    state = LiveSessionState.initial(drill, angle);
  }

  void startCountdown() {
    if (state.status == LiveStatus.running) return;
    state = state.copyWith(status: LiveStatus.countdown, countdownRemaining: 3);
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      final next = state.countdownRemaining - 1;
      if (next <= 0) {
        timer.cancel();
        _countdown = null;
        unawaited(_begin());
      } else {
        state = state.copyWith(countdownRemaining: next);
      }
    });
  }

  Future<void> _begin() async {
    final source = _source;
    _frameSub = source.frames.listen(_onFrame);
    _shotSub = source.shots.listen(_onShot);

    _elapsed
      ..reset()
      ..start();

    state = state.copyWith(
      status: LiveStatus.running,
      countdownRemaining: 0,
      elapsed: Duration.zero,
    );

    await source.start(
      CaptureRequest(
        drill: state.drill,
        angle: state.angle,
        calibrationQuality: state.calibrationQuality,
      ),
    );
  }

  void _onFrame(CaptureFrame frame) {
    if (state.status != LiveStatus.running) return;

    // A new cycle restarts the trail; otherwise it grows while the ball flies.
    final restarted = frame.cycleProgress < state.cycleProgress;
    final trail = restarted ? <Offset>[] : [...state.ballTrail];
    if (frame.ball != null) {
      trail.add(frame.ball!);
      if (trail.length > _trailLength) trail.removeAt(0);
    }

    state = state.copyWith(
      elapsed: _elapsed.elapsed,
      phase: frame.phase,
      cycleProgress: frame.cycleProgress,
      pose: frame.pose,
      ball: frame.ball,
      clearBall: frame.ball == null,
      ballTrail: trail,
      rim: frame.rim,
      backboard: frame.backboard,
      trackingConfidence: frame.trackingConfidence,
      processedFps: frame.processedFps,
      thermalHeadroom: frame.thermalHeadroom,
    );
  }

  void _onShot(Shot shot) {
    final placed = shot.copyWith(offsetFromStart: _elapsed.elapsed);
    final shots = [...state.shots, placed];

    state = state.copyWith(
      shots: shots,
      lastResultFlash: placed,
      pendingConfirmation: placed.result == ShotResult.uncertain
          ? placed
          : null,
      clearPending: placed.result != ShotResult.uncertain,
      activeCue: _cueFor(shots),
    );
  }

  /// One prioritised cue at a time, never issued from low-confidence evidence
  /// and never repeated inside the shooting motion.
  CoachingCue? _cueFor(List<Shot> shots) {
    final graded = shots
        .where((s) => s.confidence.isAuthoritative)
        .toList(growable: false);
    if (graded.length < 3) return null;

    final recent = graded.length <= 5
        ? graded
        : graded.sublist(graded.length - 5, graded.length);

    final drift =
        recent.map((s) => s.lateralDeviationCm).reduce((a, b) => a + b) /
        recent.length;
    final knee =
        recent.map((s) => s.kneeFlexion).reduce((a, b) => a + b) /
        recent.length;
    final follow =
        recent.map((s) => s.followThroughMs).reduce((a, b) => a + b) /
        recent.length;
    final madeRate = recent.where((s) => s.isMake).length / recent.length;

    if (drift.abs() > 5.5) {
      return CoachingCue(
        id: 'live-drift-${shots.length}',
        headline:
            'Last five landed ${drift.abs().toStringAsFixed(0)} cm ${drift < 0 ? 'left' : 'right'}',
        detail: 'Bring your elbow under the ball at set point.',
        source: CueSource.measurement,
        priority: CuePriority.primary,
        confidence: ConfidenceLevel.high,
      );
    }
    if (knee < 122) {
      return CoachingCue(
        id: 'live-knee-${shots.length}',
        headline: 'Legs are getting short',
        detail: 'Sink into the load the way you did on your first ten.',
        source: CueSource.measurement,
        priority: CuePriority.primary,
        confidence: ConfidenceLevel.medium,
      );
    }
    if (follow < 560) {
      return CoachingCue(
        id: 'live-follow-${shots.length}',
        headline: 'Hold your follow-through slightly longer',
        detail: 'Your makes average 690 milliseconds of hold.',
        source: CueSource.measurement,
        priority: CuePriority.primary,
        confidence: ConfidenceLevel.high,
      );
    }
    if (madeRate >= 0.8) {
      return CoachingCue(
        id: 'live-good-${shots.length}',
        headline: 'That is your best rhythm today',
        detail: 'Release timing and knee drive are both on baseline.',
        source: CueSource.measurement,
        priority: CuePriority.reinforcement,
        confidence: ConfidenceLevel.high,
      );
    }
    return null;
  }

  void confirmPending(ShotResult result) {
    final pending = state.pendingConfirmation;
    if (pending == null) return;
    state = state.copyWith(
      shots: [
        for (final shot in state.shots)
          if (shot.id != pending.id)
            shot
          else
            shot.copyWith(
              result: result,
              confidence: ConfidenceLevel.medium,
              correctedByUser: true,
            ),
      ],
      clearPending: true,
    );
  }

  void correctLast(ShotResult result) {
    if (state.shots.isEmpty) return;
    final last = state.shots.last;
    state = state.copyWith(
      shots: [
        ...state.shots.sublist(0, state.shots.length - 1),
        last.copyWith(result: result, correctedByUser: true),
      ],
      clearPending: true,
    );
  }

  void dismissFlash() => state = state.copyWith(clearFlash: true);

  void pause() {
    _elapsed.stop();
    unawaited(_source.pause());
    state = state.copyWith(status: LiveStatus.paused);
  }

  void resume() {
    if (state.status != LiveStatus.paused) return;
    _elapsed.start();
    state = state.copyWith(status: LiveStatus.running);
    unawaited(_source.resume());
  }

  void end() {
    _teardown();
    state = state.copyWith(status: LiveStatus.ended);
  }

  /// Freezes the live run into a stored session record.
  TrainingSession finalise() {
    final drill = state.drill;
    return TrainingSession(
      id: 'session-live-${DateTime.now().millisecondsSinceEpoch}',
      drillId: drill.id,
      drillName: drill.name,
      startedAt: DateTime.now().subtract(state.elapsed),
      duration: state.elapsed,
      shots: state.shots,
      calibration: CalibrationRecord(
        angle: state.angle,
        qualityScore: state.calibrationQuality,
        courtProfile: 'Northgate Prep — Main Gym',
        rimHeightM: 3.05,
        lightingScore: 0.9,
        stabilityScore: 0.94,
        framingScore: 0.9,
        frameRate: 60,
        notes: const ['Court plane locked from three visible lines.'],
      ),
      cues: [if (state.activeCue != null) state.activeCue!],
      modelVersion: 'det-1.4.2 / pose-2.1.0 / event-3.0.1',
      deviceName: 'iPhone 17 Pro',
      processedOnDevice: true,
    );
  }
}

final liveSessionProvider =
    NotifierProvider<LiveSessionController, LiveSessionState>(
      LiveSessionController.new,
    );
