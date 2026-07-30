import 'dart:async';

import '../models/shot.dart';
import '../seed/shot_factory.dart';
import 'capture_source.dart';
import 'live_scene.dart';
import 'shot_cycle.dart';
import 'simulated_pose.dart';

/// A [CaptureSource] that plays a plausible session without a camera.
///
/// It exists so the whole product can be built, demonstrated and tested before
/// the inference bridge lands, and so the screens are never written against a
/// pipeline that only works on a device. Timings come from [ShotCycle] and the
/// measurements from [ShotFactory], both deterministic for a given drill.
class SimulatedCaptureSource implements CaptureSource {
  SimulatedCaptureSource({
    this.frameInterval = const Duration(milliseconds: 60),
  });

  /// How often a frame is emitted. Tests shorten this; the default is roughly
  /// the rate the interface is designed to redraw at.
  final Duration frameInterval;

  final _frames = StreamController<CaptureFrame>.broadcast();
  final _shots = StreamController<Shot>.broadcast();

  Timer? _clock;
  ShotFactory? _factory;
  CaptureRequest? _request;
  Stopwatch? _cycle;
  int _shotCount = 0;
  double _trackingConfidence = 0.94;

  @override
  Stream<CaptureFrame> get frames => _frames.stream;

  @override
  Stream<Shot> get shots => _shots.stream;

  @override
  Future<void> start(CaptureRequest request) async {
    _request = request;
    _factory = ShotFactory(
      seed: request.drill.id.hashCode & 0xFFFF,
      baseAccuracy: 0.48,
      mechanicsCentre: 84.2,
      lateralBias: -4.6,
      releaseAngleCentre: 51.2,
    );
    _shotCount = 0;
    _trackingConfidence = 0.94;
    _cycle = Stopwatch()..start();
    _startClock();
  }

  @override
  Future<void> pause() async {
    _clock?.cancel();
    _clock = null;
    _cycle?.stop();
  }

  @override
  Future<void> resume() async {
    if (_request == null || _clock != null) return;
    _cycle?.start();
    _startClock();
  }

  @override
  Future<void> stop() async {
    _clock?.cancel();
    _clock = null;
    _cycle?.stop();
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _frames.close();
    await _shots.close();
  }

  void _startClock() {
    _clock = Timer.periodic(frameInterval, (_) => _emit());
  }

  void _emit() {
    final request = _request;
    final cycle = _cycle;
    if (request == null || cycle == null) return;

    var cycleMs = cycle.elapsedMilliseconds;
    if (cycleMs >= ShotCycle.total) {
      cycle
        ..reset()
        ..start();
      cycleMs = 0;
      _emitShot();
    }

    final phase = ShotCycle.phaseAt(cycleMs);
    final inFlight = ShotCycle.flightProgress(cycleMs) != null;

    _frames.add(
      CaptureFrame(
        phase: phase,
        cycleProgress: cycleMs / ShotCycle.total,
        pose: PoseAnimator.at(cycleMs, trackingConfidence: _trackingConfidence),
        ball: inFlight ? PoseAnimator.ballAt(cycleMs) : null,
        rim: LiveScene.hoop,
        backboard: LiveScene.backboard,
        trackingConfidence: _trackingConfidence,
        processedFps: 26 + (cycleMs ~/ 400) % 5,
        thermalHeadroom: _thermalHeadroom,
      ),
    );
  }

  /// Sustained capture warms the device, so the simulation drains headroom on
  /// the same curve the interface is built to warn about.
  double get _thermalHeadroom {
    final seconds = _shotCount * ShotCycle.total / 1000;
    return (1.0 - seconds / 5400).clamp(0.35, 1.0).toDouble();
  }

  void _emitShot() {
    final request = _request!;
    final zones = request.drill.zones;
    final generated = _factory!
        .build(
          sessionId: 'live',
          zones: [zones[_shotCount % zones.length]],
          type: request.drill.shotType,
          count: 1,
          calibrationQuality: request.calibrationQuality,
        )
        .first;

    _shotCount++;
    _trackingConfidence =
        (0.86 + (generated.confidence.isAuthoritative ? 0.1 : -0.06)).clamp(
          0.4,
          0.99,
        );

    _shots.add(generated.copyWith(id: 'live-$_shotCount', index: _shotCount));
  }
}

/// A source that emits nothing until it is told to.
///
/// Screens under test mount against this and drive frames and shots explicitly,
/// so no test depends on a timer or on wall-clock timing.
class ScriptedCaptureSource implements CaptureSource {
  final _frames = StreamController<CaptureFrame>.broadcast();
  final _shots = StreamController<Shot>.broadcast();

  CaptureRequest? request;
  bool running = false;

  @override
  Stream<CaptureFrame> get frames => _frames.stream;

  @override
  Stream<Shot> get shots => _shots.stream;

  void emitFrame(CaptureFrame frame) => _frames.add(frame);

  void emitShot(Shot shot) => _shots.add(shot);

  /// A representative frame at a point in the shot cycle, so a test can put the
  /// interface into a known state without waiting for anything.
  static CaptureFrame frameAt(int cycleMs, {double trackingConfidence = 0.94}) {
    return CaptureFrame(
      phase: ShotCycle.phaseAt(cycleMs),
      cycleProgress: cycleMs / ShotCycle.total,
      pose: PoseAnimator.at(cycleMs, trackingConfidence: trackingConfidence),
      ball: ShotCycle.flightProgress(cycleMs) == null
          ? null
          : PoseAnimator.ballAt(cycleMs),
      rim: LiveScene.hoop,
      backboard: LiveScene.backboard,
      trackingConfidence: trackingConfidence,
      processedFps: 28,
      thermalHeadroom: 1,
    );
  }

  @override
  Future<void> start(CaptureRequest request) async {
    this.request = request;
    running = true;
  }

  @override
  Future<void> pause() async => running = false;

  @override
  Future<void> resume() async => running = true;

  @override
  Future<void> stop() async => running = false;

  @override
  Future<void> dispose() async {
    await _frames.close();
    await _shots.close();
  }
}
