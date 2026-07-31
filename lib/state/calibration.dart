import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/calibration/calibration_solver.dart';
import '../data/calibration/court_frame.dart';
import '../data/capture/calibration_source.dart';
import 'capture_pipeline.dart';

/// Where the calibration has got to.
enum CalibrationStage {
  /// Nothing running. The athlete has not started it, or has stopped it.
  idle,

  /// The camera is open and no ring has been found yet.
  searching,

  /// A ring is in view and consistent solves are accumulating.
  settling,

  /// Enough consistent solves to trust the result.
  solved,

  /// The camera is open but the scene will not solve, and the reason is known.
  blocked,
}

/// What the calibration screen renders.
class CalibrationState {
  const CalibrationState({
    this.stage = CalibrationStage.idle,
    this.solution,
    this.settleProgress = 0,
    this.framesSeen = 0,
    this.framesWithRim = 0,
    this.jitterPx = 0,
    this.failure,
  });

  final CalibrationStage stage;

  /// The most recent successful solve. Kept while settling so the overlay can
  /// draw the ring it has found rather than waiting for the whole run.
  final CalibrationSolution? solution;

  /// 0 to 1 across the settling window.
  final double settleProgress;

  final int framesSeen;
  final int framesWithRim;

  /// How far the solved rim distance moves between frames, in effect. A steady
  /// scene converges; a hand-held phone does not, and the athlete should be
  /// told that rather than handed a number that will drift mid-session.
  final double jitterPx;

  /// Why the scene will not solve, when it will not.
  final CalibrationFailure? failure;

  bool get isRunning =>
      stage == CalibrationStage.searching ||
      stage == CalibrationStage.settling;

  bool get isSolved => stage == CalibrationStage.solved && solution != null;

  CourtFrame? get frame => solution?.frame;

  double get overall => solution?.overall ?? 0;

  CalibrationState copyWith({
    CalibrationStage? stage,
    CalibrationSolution? solution,
    double? settleProgress,
    int? framesSeen,
    int? framesWithRim,
    double? jitterPx,
    CalibrationFailure? failure,
    bool clearFailure = false,
  }) {
    return CalibrationState(
      stage: stage ?? this.stage,
      solution: solution ?? this.solution,
      settleProgress: settleProgress ?? this.settleProgress,
      framesSeen: framesSeen ?? this.framesSeen,
      framesWithRim: framesWithRim ?? this.framesWithRim,
      jitterPx: jitterPx ?? this.jitterPx,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

/// Runs the real solver over the preview and decides when to trust it.
///
/// One frame is not a calibration. A ring detected at the edge of a blur, or
/// during the half second the phone is still settling on the tripod, solves to
/// a plane that is plausible and wrong. So the controller requires a run of
/// consistent solves and reports how consistent they were, and the athlete sees
/// the same number the session will inherit.
class CalibrationController extends AutoDisposeNotifier<CalibrationState> {
  /// Consistent solves needed before the result is offered. At preview rate
  /// this is roughly a second, which is also about how long it takes a tripod
  /// to stop moving after it is let go.
  static const int requiredSolves = 24;

  /// Two solves further apart than this are not the same scene, and the run
  /// starts again.
  static const double _maxJitterM = 0.18;

  StreamSubscription<CalibrationObservation>? _subscription;
  final List<CalibrationSolution> _run = [];

  /// Conditions from the last accepted observation. The solve scores them but
  /// does not carry them, and the finished session needs the raw frame rate.
  CaptureConditions _conditions = const CaptureConditions();

  @override
  CalibrationState build() {
    ref.onDispose(_stop);
    return const CalibrationState();
  }

  Future<void> start() async {
    await _stop();
    _run.clear();
    state = const CalibrationState(stage: CalibrationStage.searching);

    final source = ref.read(calibrationSourceProvider);
    _subscription = source.observations.listen(_accept, onError: _onError);

    try {
      await source.startPreview(tripod: ref.read(tripodDeclaredProvider));
    } catch (error) {
      _onError(error);
    }
  }

  /// Accepts the current solve and hands it to the session.
  ///
  /// Separate from solving because the athlete is allowed to look at a poor
  /// score and decide to fix the setup instead.
  void commit() {
    // Only a settled solve. A partial one is real geometry and is worth
    // drawing on the overlay, but it has not yet been shown to be the same
    // answer twice, and the session would inherit it as though it had.
    if (!state.isSolved) return;
    ref.read(courtFrameProvider.notifier).set(state.frame);
    ref.read(committedCalibrationProvider.notifier).set(
      CommittedCalibration(
        solution: state.solution!,
        conditions: _conditions,
      ),
    );
  }

  Future<void> cancel() async {
    await _stop();
    state = const CalibrationState();
  }

  Future<void> _stop() async {
    await _subscription?.cancel();
    _subscription = null;
    try {
      await ref.read(calibrationSourceProvider).stopPreview();
    } catch (_) {
      // Tearing down a preview that is already gone is not a failure worth
      // surfacing; the screen is leaving either way.
    }
  }

  void _onError(Object error) {
    state = state.copyWith(
      stage: CalibrationStage.blocked,
      failure: CalibrationFailure.noRim,
    );
  }

  void _accept(CalibrationObservation observation) {
    final seen = state.framesSeen + 1;
    _conditions = observation.conditions;

    final solution = CalibrationSolver.solve(
      rim: observation.rim,
      intrinsics: observation.intrinsics,
      backboard: observation.backboard,
      conditions: observation.conditions,
      gravity: observation.gravity,
    );

    if (!solution.isUsable) {
      _run.clear();
      state = state.copyWith(
        // A missing ring is the athlete pointing the phone elsewhere, which is
        // a normal part of setting up. Anything else is a scene that will not
        // work and should say so.
        stage: solution.failure == CalibrationFailure.noRim
            ? CalibrationStage.searching
            : CalibrationStage.blocked,
        framesSeen: seen,
        settleProgress: 0,
        failure: solution.failure,
      );
      return;
    }

    final drift = _driftFrom(solution);
    if (drift > _maxJitterM) {
      // The scene moved. Everything before this described a different camera
      // position, so it is discarded rather than averaged with what follows.
      _run.clear();
    }
    _run.add(solution);

    if (_run.length > requiredSolves) {
      _run.removeAt(0);
    }

    final progress = _run.length / requiredSolves;
    final settled = _run.length >= requiredSolves;

    state = CalibrationState(
      stage: settled ? CalibrationStage.solved : CalibrationStage.settling,
      solution: settled ? _consensus() : solution,
      settleProgress: progress.clamp(0.0, 1.0),
      framesSeen: seen,
      framesWithRim: state.framesWithRim + 1,
      jitterPx: _spreadM() * 100,
    );

    if (settled) unawaited(_stop());
  }

  /// How far this solve sits from the one before it, in metres of rim distance.
  double _driftFrom(CalibrationSolution solution) {
    if (_run.isEmpty) return 0;
    final previous = _run.last.frame;
    final current = solution.frame;
    if (previous == null || current == null) return 0;
    return (previous.rimCentre - current.rimCentre).length;
  }

  /// Spread of rim distance across the run, which is the honest measure of how
  /// steady the mount was while the scene was being solved.
  double _spreadM() {
    if (_run.length < 2) return 0;
    final distances = [
      for (final solution in _run)
        if (solution.frame != null) solution.frame!.rimCentre.length,
    ];
    if (distances.length < 2) return 0;

    final mean = distances.reduce((a, b) => a + b) / distances.length;
    var variance = 0.0;
    for (final distance in distances) {
      variance += (distance - mean) * (distance - mean);
    }
    return math.sqrt(variance / distances.length);
  }

  /// The solve to keep out of the run.
  ///
  /// The median by score rather than a mean of the geometry: averaging two
  /// rotations is not a rotation, and the median is an actual observed frame
  /// that the reprojection error was actually measured against.
  CalibrationSolution _consensus() {
    final sorted = [..._run]..sort((a, b) => a.overall.compareTo(b.overall));
    return sorted[sorted.length ~/ 2];
  }
}

final calibrationProvider =
    AutoDisposeNotifierProvider<CalibrationController, CalibrationState>(
      CalibrationController.new,
    );
