import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/confidence.dart';
import '../data/models/drill.dart';
import '../data/models/pose.dart';
import '../data/models/session.dart';
import '../data/models/shot.dart';
import '../data/seed/drill_catalog.dart';
import '../data/seed/shot_factory.dart';

enum LiveStatus { setup, countdown, running, paused, ended }

/// Everything the live interface needs for one processed frame.
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

  CourtZone get activeZone =>
      drill.zones[shots.length % drill.zones.length];

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
      calibrationQuality: calibrationQuality ?? this.calibrationQuality,
      trackingConfidence: trackingConfidence ?? this.trackingConfidence,
      processedFps: processedFps ?? this.processedFps,
      thermalHeadroom: thermalHeadroom ?? this.thermalHeadroom,
      activeCue: clearCue ? null : (activeCue ?? this.activeCue),
      lastResultFlash:
          clearFlash ? null : (lastResultFlash ?? this.lastResultFlash),
      pendingConfirmation: clearPending
          ? null
          : (pendingConfirmation ?? this.pendingConfirmation),
    );
  }
}

/// Timings of one shot cycle in milliseconds. The overlay derives the skeleton,
/// ball position and phase label from a single clock so graphics stay
/// synchronised with the event stream.
abstract final class ShotCycle {
  static const int approach = 900;
  static const int ready = 620;
  static const int dip = 300;
  static const int load = 260;
  static const int upward = 220;
  static const int setPoint = 180;
  static const int release = 90;
  static const int flight = 900;
  static const int rim = 260;
  static const int landing = 380;
  static const int recovery = 1100;

  static const int total = approach +
      ready +
      dip +
      load +
      upward +
      setPoint +
      release +
      flight +
      rim +
      landing +
      recovery;

  /// Point in the cycle at which the result becomes known.
  static const int resultAt =
      approach + ready + dip + load + upward + setPoint + release + flight;

  static ShotPhaseKind phaseAt(int ms) {
    var cursor = 0;
    if (ms < (cursor += approach)) return ShotPhaseKind.possession;
    if (ms < (cursor += ready)) return ShotPhaseKind.ready;
    if (ms < (cursor += dip)) return ShotPhaseKind.dip;
    if (ms < (cursor += load)) return ShotPhaseKind.load;
    if (ms < (cursor += upward)) return ShotPhaseKind.upward;
    if (ms < (cursor += setPoint)) return ShotPhaseKind.setPoint;
    if (ms < (cursor += release)) return ShotPhaseKind.release;
    if (ms < (cursor += flight)) return ShotPhaseKind.flight;
    if (ms < (cursor += rim)) return ShotPhaseKind.rimInteraction;
    if (ms < (cursor += landing)) return ShotPhaseKind.landing;
    return ShotPhaseKind.recovery;
  }

  /// Progress inside the flight phase, or null when the ball is in hand.
  static double? flightProgress(int ms) {
    const start =
        approach + ready + dip + load + upward + setPoint + release;
    const end = start + flight + rim;
    if (ms < start || ms > end) return null;
    return ((ms - start) / (flight + rim)).clamp(0.0, 1.0);
  }
}

/// Drives a live session. In production the shot events arrive from the native
/// inference bridge; the controller's contract is the same either way — it
/// receives completed shot records and owns nothing about frame processing.
class LiveSessionController extends Notifier<LiveSessionState> {
  Timer? _ticker;
  DateTime? _startedAt;
  DateTime? _cycleStartedAt;
  int _shotSeed = 0;
  late ShotFactory _factory;

  @override
  LiveSessionState build() {
    ref.onDispose(() => _ticker?.cancel());
    return LiveSessionState.initial(
      DrillCatalog.byId('quick-shooting'),
      CameraAngle.side,
    );
  }

  void configure(Drill drill, CameraAngle angle) {
    _ticker?.cancel();
    _shotSeed = drill.id.hashCode & 0xFFFF;
    _factory = ShotFactory(
      seed: _shotSeed,
      baseAccuracy: 0.48,
      mechanicsCentre: 84.2,
      lateralBias: -4.6,
      releaseAngleCentre: 51.2,
    );
    state = LiveSessionState.initial(drill, angle);
  }

  void startCountdown() {
    if (state.status == LiveStatus.running) return;
    state = state.copyWith(status: LiveStatus.countdown, countdownRemaining: 3);
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      final next = state.countdownRemaining - 1;
      if (next <= 0) {
        timer.cancel();
        _begin();
      } else {
        state = state.copyWith(countdownRemaining: next);
      }
    });
  }

  void _begin() {
    _startedAt = DateTime.now();
    _cycleStartedAt = DateTime.now();
    state = state.copyWith(
      status: LiveStatus.running,
      countdownRemaining: 0,
      elapsed: Duration.zero,
    );
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 60), (_) => _tick());
  }

  void _tick() {
    if (state.status != LiveStatus.running) return;
    final now = DateTime.now();
    final elapsed = now.difference(_startedAt!);
    final cycleMs = now.difference(_cycleStartedAt!).inMilliseconds;

    if (cycleMs >= ShotCycle.total) {
      _cycleStartedAt = now;
      _recordShot();
      return;
    }

    state = state.copyWith(
      elapsed: elapsed,
      phase: ShotCycle.phaseAt(cycleMs),
      cycleProgress: cycleMs / ShotCycle.total,
      processedFps: 26 + (cycleMs ~/ 400) % 5,
      thermalHeadroom:
          (1.0 - elapsed.inSeconds / 5400).clamp(0.35, 1.0).toDouble(),
    );
  }

  void _recordShot() {
    final drill = state.drill;
    final generated = _factory.build(
      sessionId: 'live',
      zones: [state.activeZone],
      type: drill.shotType,
      count: 1,
      calibrationQuality: state.calibrationQuality,
    ).first;

    final shot = Shot(
      id: 'live-${state.shots.length + 1}',
      index: state.shots.length + 1,
      offsetFromStart: state.elapsed,
      result: generated.result,
      outcomeDetail: generated.outcomeDetail,
      zone: generated.zone,
      type: generated.type,
      confidence: generated.confidence,
      releaseAngle: generated.releaseAngle,
      entryAngle: generated.entryAngle,
      apexHeightM: generated.apexHeightM,
      releaseHeightM: generated.releaseHeightM,
      ballSpeedMs: generated.ballSpeedMs,
      flightTimeMs: generated.flightTimeMs,
      lateralDeviationCm: generated.lateralDeviationCm,
      depthCm: generated.depthCm,
      elbowAngle: generated.elbowAngle,
      kneeFlexion: generated.kneeFlexion,
      guideHandSeparationCm: generated.guideHandSeparationCm,
      releaseTimeMs: generated.releaseTimeMs,
      followThroughMs: generated.followThroughMs,
      landingDriftCm: generated.landingDriftCm,
      balanceScore: generated.balanceScore,
      mechanicsScore: generated.mechanicsScore,
      trajectory: generated.trajectory,
      phases: generated.phases,
    );

    final shots = [...state.shots, shot];

    state = state.copyWith(
      shots: shots,
      lastResultFlash: shot,
      pendingConfirmation:
          shot.result == ShotResult.uncertain ? shot : null,
      clearPending: shot.result != ShotResult.uncertain,
      activeCue: _cueFor(shots),
      trackingConfidence:
          (0.86 + (shot.confidence == ConfidenceLevel.high ? 0.1 : -0.06))
              .clamp(0.4, 0.99),
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
    final knee = recent.map((s) => s.kneeFlexion).reduce((a, b) => a + b) /
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
    _ticker?.cancel();
    state = state.copyWith(status: LiveStatus.paused);
  }

  void resume() {
    if (state.status != LiveStatus.paused) return;
    _startedAt = DateTime.now().subtract(state.elapsed);
    _cycleStartedAt = DateTime.now();
    state = state.copyWith(status: LiveStatus.running);
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 60), (_) => _tick());
  }

  void end() {
    _ticker?.cancel();
    state = state.copyWith(status: LiveStatus.ended);
  }

  /// Freezes the live run into a stored session record.
  TrainingSession finalise() {
    final drill = state.drill;
    return TrainingSession(
      id: 'session-live-${DateTime.now().millisecondsSinceEpoch}',
      drillId: drill.id,
      drillName: drill.name,
      startedAt: _startedAt ?? DateTime.now(),
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
      cues: [
        if (state.activeCue != null) state.activeCue!,
      ],
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

/// Geometry of the tracked scene in normalised preview coordinates.
abstract final class LiveScene {
  static const Rect hoop = Rect.fromLTWH(0.700, 0.212, 0.132, 0.030);
  static const Rect backboard = Rect.fromLTWH(0.688, 0.098, 0.180, 0.118);
  static Offset get rimCentre => hoop.center;

  static Rect playerBox(PoseFrame pose) {
    var left = 1.0, top = 1.0, right = 0.0, bottom = 0.0;
    for (final point in pose.landmarks.values) {
      left = math.min(left, point.dx);
      top = math.min(top, point.dy);
      right = math.max(right, point.dx);
      bottom = math.max(bottom, point.dy);
    }
    return Rect.fromLTRB(left - 0.045, top - 0.055, right + 0.045,
        bottom + 0.025);
  }
}
