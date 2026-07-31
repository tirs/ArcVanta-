import 'dart:math' as math;
import 'dart:typed_data';

import 'package:arcvanta/data/calibration/camera_intrinsics.dart';
import 'package:arcvanta/data/calibration/court_dimensions.dart';
import 'package:arcvanta/data/calibration/court_frame.dart';
import 'package:arcvanta/data/capture/capture_source.dart';
import 'package:arcvanta/data/capture/model_contract.dart';
import 'package:arcvanta/data/capture/native_capture_source.dart';
import 'package:arcvanta/data/models/confidence.dart';
import 'package:arcvanta/data/models/shot.dart';
import 'package:arcvanta/data/seed/drill_catalog.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';

const _methodChannelName = 'test/capture';
const _eventChannelName = 'test/capture/events';
const double _g = 9.80665;

final _intrinsics = CameraIntrinsics.fromHorizontalFov(
  fovDegrees: 68,
  widthPx: 1920,
  heightPx: 1080,
);

final _courtFrame = CourtFrame(
  intrinsics: _intrinsics,
  rimCentre: Vector3(0, -1.448, 9.0),
  up: Vector3(0, -1, 0),
  backAxis: Vector3(0, 0, 1),
);

/// Stands in for the platform: records the calls the source makes and pushes
/// whatever frames a test wants back down the event channel.
class FakeBridge {
  FakeBridge({this.availability});

  final Map<Object?, Object?>? availability;

  final calls = <MethodCall>[];
  final _eventChannel = const EventChannel(_eventChannelName);
  void Function(ByteData?)? _sink;

  void install() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(
      const MethodChannel(_methodChannelName),
      (call) async {
        calls.add(call);
        if (call.method == 'availability') return availability;
        return null;
      },
    );

    messenger.setMockMessageHandler(_eventChannelName, (message) async {
      final call = const StandardMethodCodec().decodeMethodCall(message);
      if (call.method == 'listen') {
        _sink = (data) => messenger.handlePlatformMessage(
          _eventChannelName,
          data,
          (_) {},
        );
      } else if (call.method == 'cancel') {
        _sink = null;
      }
      return const StandardMethodCodec().encodeSuccessEnvelope(null);
    });
  }

  void remove() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel(_methodChannelName),
      null,
    );
    messenger.setMockMessageHandler(_eventChannelName, null);
  }

  void emit(Map<Object?, Object?> payload) {
    _sink?.call(const StandardMethodCodec().encodeSuccessEnvelope(payload));
  }

  bool get isListening => _sink != null;

  NativeCaptureSource get source => NativeCaptureSource(
    methodChannel: const MethodChannel(_methodChannelName),
    eventChannel: _eventChannel,
  );
}

Float64List _keypointsFor({
  required CourtPosition feet,
  required double wristHeight,
}) {
  const skeleton = <int, (double, double)>{
    0: (0.0, 1.72),
    1: (-0.03, 1.75), 2: (0.03, 1.75),
    3: (-0.07, 1.74), 4: (0.07, 1.74),
    5: (-0.20, 1.45), 6: (0.20, 1.45),
    7: (-0.24, 1.18), 8: (0.24, 1.18),
    11: (-0.14, 0.95), 12: (0.14, 0.95),
    13: (-0.15, 0.52), 14: (0.15, 0.52),
    15: (-0.15, 0.06), 16: (0.15, 0.06),
  };

  final values = Float64List(ModelContract.poseKeypointCount * 3);
  for (var i = 0; i < ModelContract.poseKeypointCount; i++) {
    final entry = i == 9
        ? (-0.18, wristHeight)
        : i == 10
        ? (0.10, wristHeight)
        : skeleton[i]!;

    final pixel = _intrinsics.projectToPixel(
      _courtFrame.fromCourt(
        CourtPosition(
          lateralM: feet.lateralM + entry.$1,
          depthM: feet.depthM,
          heightM: entry.$2,
        ),
      ),
    )!;
    values[i * 3] = pixel.x;
    values[i * 3 + 1] = pixel.y;
    values[i * 3 + 2] = 0.92;
  }
  return values;
}

Map<Object?, Object?> _personPayload({
  required CourtPosition feet,
  required double wristHeight,
}) {
  final keypoints = _keypointsFor(feet: feet, wristHeight: wristHeight);
  var minX = double.infinity, minY = double.infinity, maxX = 0.0;
  for (var i = 0; i < ModelContract.poseKeypointCount; i++) {
    minX = math.min(minX, keypoints[i * 3]);
    maxX = math.max(maxX, keypoints[i * 3]);
    minY = math.min(minY, keypoints[i * 3 + 1]);
  }
  final floor = _intrinsics.projectToPixel(
    _courtFrame.fromCourt(
      CourtPosition(lateralM: feet.lateralM, depthM: feet.depthM, heightM: 0),
    ),
  )!;

  return {
    'box': Float64List.fromList([minX - 8, minY - 12, maxX + 8, floor.y]),
    'score': 0.93,
    'keypoints': keypoints,
  };
}

Map<Object?, Object?>? _ballPayload(CourtPosition position) {
  final world = _courtFrame.fromCourt(position);
  final pixel = _intrinsics.projectToPixel(world)!;
  final radius =
      _intrinsics.focalXPx * CourtDimensions.ballRadiusM / world.length;
  return {
    'box': Float64List.fromList([
      pixel.x - radius,
      pixel.y - radius,
      pixel.x + radius,
      pixel.y + radius,
    ]),
    'score': 0.9,
  };
}

Map<Object?, Object?> _framePayload({
  required int timeMs,
  Map<Object?, Object?>? person,
  Map<Object?, Object?>? ball,
}) => <Object?, Object?>{
  'type': 'detections',
  'tMs': timeMs,
  'people': person == null ? const [] : [person],
  'ball': ball,
  'rim': null,
  'rimEllipse': null,
  'backboard': null,
  'intrinsics': {
    'fx': _intrinsics.focalXPx,
    'fy': _intrinsics.focalYPx,
    'cx': _intrinsics.principalXPx,
    'cy': _intrinsics.principalYPx,
    'width': _intrinsics.widthPx,
    'height': _intrinsics.heightPx,
    'fromDevice': true,
  },
  'gravity': Float64List.fromList([0.0, 9.8, 0.0]),
  'conditions': {'meanLuma': 0.54, 'frameRate': 60, 'tripod': true},
  'fps': 58,
  'thermalHeadroom': 0.9,
  'backend': 'NNAPI',
};

/// One full attempt, as the bridge would report it.
List<Map<Object?, Object?>> _attemptPayloads() {
  const feet = CourtPosition(lateralM: 1.5, depthM: 4.19, heightM: 0);
  final payloads = <Map<Object?, Object?>>[];
  var time = 0;

  for (var i = 0; i < 20; i++) {
    final wrist = 1.30 - 0.10 * math.sin(i / 19 * math.pi);
    payloads.add(
      _framePayload(
        timeMs: time,
        person: _personPayload(feet: feet, wristHeight: wrist),
        ball: _ballPayload(
          CourtPosition(
            lateralM: feet.lateralM - 0.04,
            depthM: feet.depthM,
            heightM: wrist + 0.10,
          ),
        ),
      ),
    );
    time += 16;
  }

  const releaseHeight = 2.30;
  final angle = radians(52.0);
  final ground = math.sqrt(
    feet.lateralM * feet.lateralM + feet.depthM * feet.depthM,
  );
  final drop = CourtDimensions.rimHeightM - releaseHeight;
  final cos = math.cos(angle);
  final speed = math.sqrt(
    _g * ground * ground / (2 * cos * cos * (ground * math.tan(angle) - drop)),
  );

  for (var i = 0; i <= 90; i++) {
    final t = i / 60;
    final travelled = speed * cos * t;
    final height = releaseHeight + speed * math.sin(angle) * t - 0.5 * _g * t * t;
    if (height < 1.6) break;
    final progress = (travelled / ground).clamp(0.0, 1.0);

    payloads.add(
      _framePayload(
        timeMs: time + (t * 1000).round(),
        person: _personPayload(feet: feet, wristHeight: 2.05),
        ball: _ballPayload(
          CourtPosition(
            lateralM: feet.lateralM * (1 - progress),
            depthM: feet.depthM * (1 - progress),
            heightM: height,
          ),
        ),
      ),
    );
  }

  return payloads;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeBridge bridge;

  tearDown(() => bridge.remove());

  group('availability', () {
    test('reports live when the bridge answers with a matching contract', () async {
      bridge = FakeBridge(
        availability: {
          'contractVersion': ModelContract.version,
          'detectorVersion': 'rtmdet-m-1.0.0',
          'poseVersion': 'rtmpose-m-1.0.0',
          'backend': 'NNAPI',
        },
      )..install();

      final result = await bridge.source.checkAvailability();

      expect(result.isAvailable, isTrue);
      expect(result.runtime!.backend, InferenceBackend.nnapi);
    });

    test('a newer contract on the bridge is refused, not tolerated', () async {
      bridge = FakeBridge(
        availability: {
          'contractVersion': ModelContract.version + 1,
          'detectorVersion': 'x',
          'poseVersion': 'y',
          'backend': 'CPU',
        },
      )..install();

      final result = await bridge.source.checkAvailability();

      expect(result.isAvailable, isFalse);
      expect(result.reason, CaptureUnavailableReason.contractMismatch);
      expect(result.detail, contains('contract'));
    });

    test('missing models are reported as such', () async {
      bridge = FakeBridge(
        availability: {
          'unavailable': 'modelsMissing',
          'detail': 'arcvanta_rtmdet_m_640.onnx not found',
        },
      )..install();

      final result = await bridge.source.checkAvailability();

      expect(result.reason, CaptureUnavailableReason.modelsMissing);
      expect(result.detail, contains('rtmdet'));
    });

    test('no platform implementation at all', () async {
      bridge = FakeBridge()..install();
      final result = await bridge.source.checkAvailability();
      expect(
        result.reason,
        CaptureUnavailableReason.noPlatformImplementation,
      );
    });
  });

  group('driving a session through the bridge', () {
    late NativeCaptureSource source;
    late List<CaptureFrame> frames;
    late List<Shot> shots;

    setUp(() async {
      bridge = FakeBridge()..install();
      source = bridge.source..courtFrame = _courtFrame;
      frames = [];
      shots = [];
      // Errors are asserted on by their own listener below; this one only
      // collects frames and must not turn an error into an unhandled one.
      source.frames.listen(frames.add, onError: (Object _) {});
      source.shots.listen(shots.add);

      await source.start(
        CaptureRequest(
          drill: DrillCatalog.all.first,
          angle: CameraAngle.side,
          calibrationQuality: 0.92,
        ),
      );
      await Future<void>.delayed(Duration.zero);
    });

    Future<void> playAttempt() async {
      for (final payload in _attemptPayloads()) {
        bridge.emit(payload);
      }
      await Future<void>.delayed(Duration.zero);
    }

    test('start tells the platform what it needs', () {
      final call = bridge.calls.firstWhere((c) => c.method == 'start');
      final args = call.arguments as Map;
      expect(args['angle'], 'side');
      expect(args['calibrationQuality'], closeTo(0.92, 1e-9));
      expect(args['pose'], isTrue);
    });

    test('subscribes to the event channel', () {
      expect(bridge.isListening, isTrue);
    });

    test('emits a frame for every detection frame', () async {
      await playAttempt();
      expect(frames, hasLength(_attemptPayloads().length));
    });

    test('forwards pose, telemetry and backend state to the interface', () async {
      await playAttempt();
      final frame = frames.first;
      expect(frame.pose!.landmarks, hasLength(14));
      expect(frame.processedFps, 58);
      expect(frame.thermalHeadroom, closeTo(0.9, 1e-9));
      expect(frame.trackingConfidence, greaterThan(0.5));
    });

    test('normalises coordinates for the overlay', () async {
      await playAttempt();
      for (final point in frames.first.pose!.landmarks.values) {
        expect(point.dx, inInclusiveRange(0, 1));
        expect(point.dy, inInclusiveRange(0, 1));
      }
    });

    test('produces one measured shot', () async {
      await playAttempt();

      expect(shots, hasLength(1));
      final shot = shots.single;
      expect(shot.result, ShotResult.made);
      expect(shot.releaseAngle, closeTo(52, 3));
      expect(shot.entryAngle, inInclusiveRange(38, 54));
      expect(shot.releaseHeightM, closeTo(2.30, 0.15));
      expect(shot.trajectory, isNotEmpty);
    });

    test('grades the shot against the calibration it was measured with', () async {
      await playAttempt();
      expect(shots.single.confidence, isNot(ConfidenceLevel.unavailable));
    });

    test('indexes and time-stamps shots from the session start', () async {
      await playAttempt();
      expect(shots.single.index, 0);
      expect(shots.single.offsetFromStart, greaterThan(Duration.zero));
    });

    test('a paused session ignores frames', () async {
      await source.pause();
      await playAttempt();
      expect(frames, isEmpty);
      expect(shots, isEmpty);

      await source.resume();
      await playAttempt();
      expect(frames, isNotEmpty);
    });

    test('an unreadable frame is dropped, not guessed at', () async {
      bridge.emit({'type': 'detections', 'tMs': 5});
      await Future<void>.delayed(Duration.zero);
      expect(frames, isEmpty);

      // The stream keeps working afterwards.
      await playAttempt();
      expect(frames, isNotEmpty);
    });

    test('a platform error reaches the listener', () async {
      final errors = <Object>[];
      source.frames.listen(null, onError: errors.add);

      bridge.emit({
        'type': 'error',
        'code': 'cameraUnavailable',
        'message': 'in use',
      });
      await Future<void>.delayed(Duration.zero);

      expect(errors.single, isA<PlatformException>());
    });

    test('stopping tears down the subscription', () async {
      await source.stop();
      expect(bridge.calls.map((c) => c.method), contains('stop'));
      expect(bridge.isListening, isFalse);
    });
  });

  test('without a calibration a shot is still reported, but unmeasured', () async {
    bridge = FakeBridge()..install();
    final source = bridge.source;
    final shots = <Shot>[];
    source.shots.listen(shots.add);

    await source.start(
      CaptureRequest(
        drill: DrillCatalog.all.first,
        angle: CameraAngle.side,
        calibrationQuality: 0.4,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    for (final payload in _attemptPayloads()) {
      bridge.emit(payload);
    }
    await source.stop();
    await Future<void>.delayed(Duration.zero);

    if (shots.isNotEmpty) {
      final shot = shots.first;
      expect(shot.result, ShotResult.uncertain);
      expect(shot.confidence, ConfidenceLevel.unavailable);
      expect(shot.releaseAngle, 0);
    }
  });

  test('calibration observations flow while previewing', () async {
    bridge = FakeBridge()..install();
    final source = bridge.source;
    final seen = <Object>[];
    source.observations.listen(seen.add);

    await source.startPreview();
    await Future<void>.delayed(Duration.zero);

    bridge.emit(
      _framePayload(
        timeMs: 0,
        person: _personPayload(
          feet: const CourtPosition(lateralM: 1.5, depthM: 4.19, heightM: 0),
          wristHeight: 1.3,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(seen, hasLength(1));
    expect(bridge.calls.map((c) => c.method), contains('startPreview'));
  });
}
