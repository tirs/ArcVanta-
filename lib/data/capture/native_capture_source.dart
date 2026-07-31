import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../analysis/shot_assembler.dart';
import '../analysis/shot_tracker.dart';
import '../calibration/court_frame.dart';
import '../models/pose.dart';
import '../models/shot.dart';
import 'calibration_source.dart';
import 'capture_protocol.dart';
import 'capture_source.dart';
import 'model_contract.dart';

/// Why the native pipeline is not available.
enum CaptureUnavailableReason {
  /// Running somewhere without a bridge at all, such as a desktop test host.
  noPlatformImplementation,

  /// The bridge is there but the model files are not.
  modelsMissing,

  /// The bridge speaks a different contract version than this build.
  contractMismatch,

  cameraPermissionDenied,
  cameraUnavailable,
}

/// The outcome of asking for camera access.
enum CameraPermissionStatus {
  granted,

  /// Refused, but the system will show the prompt again.
  denied,

  /// Refused for good. Only a trip to the system settings changes this, so the
  /// interface has to offer that instead of asking a third time.
  permanentlyDenied,

  /// No bridge to ask, such as on a desktop test host.
  unsupported,
}

/// What the platform reported when asked whether it can run.
class CaptureAvailability {
  const CaptureAvailability.available(this.runtime)
    : reason = null,
      detail = null;

  const CaptureAvailability.unavailable(this.reason, {this.detail})
    : runtime = null;

  final ModelRuntimeInfo? runtime;
  final CaptureUnavailableReason? reason;
  final String? detail;

  bool get isAvailable => runtime != null;
}

/// The real pipeline: camera and on-device inference behind the native bridge.
///
/// The native side does the two things only it can: run the camera and push
/// frames through RTMDet and RTMPose on whichever accelerator the device has.
/// Everything else, including calibration, shot segmentation and every
/// measurement, happens here in Dart, so there is one implementation to get
/// right rather than one per platform, and it can be tested without a phone.
class NativeCaptureSource implements CaptureSource, CalibrationSource {
  NativeCaptureSource({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _methods = methodChannel ??
           const MethodChannel(CaptureProtocol.methodChannel),
       _events =
           eventChannel ?? const EventChannel(CaptureProtocol.eventChannel);

  final MethodChannel _methods;
  final EventChannel _events;

  final _frames = StreamController<CaptureFrame>.broadcast();
  final _shots = StreamController<Shot>.broadcast();
  final _observations = StreamController<CalibrationObservation>.broadcast();

  StreamSubscription<dynamic>? _events$;
  ShotTracker? _tracker;
  CaptureRequest? _request;
  CourtFrame? _courtFrame;
  ModelRuntimeInfo? _runtime;

  final ValueNotifier<int?> _previewTexture = ValueNotifier<int?>(null);

  int _shotIndex = 0;
  int? _sessionStartMs;
  bool _paused = false;

  @override
  Stream<CaptureFrame> get frames => _frames.stream;

  @override
  ValueListenable<int?> get previewTexture => _previewTexture;

  @override
  Stream<Shot> get shots => _shots.stream;

  @override
  Stream<CalibrationObservation> get observations => _observations.stream;

  /// What the bridge loaded, once it has answered. Stamped onto the session so
  /// a measurement can be traced back to the graphs that produced it.
  ModelRuntimeInfo? get runtime => _runtime;

  /// The scene the session is measured against. Set by the calibration screen
  /// before [start]; without it the pipeline still finds shots but reports
  /// them unmeasured.
  set courtFrame(CourtFrame? value) {
    _courtFrame = value;
    _tracker = ShotTracker(frame: value);
  }

  CourtFrame? get courtFrame => _courtFrame;

  /// Shows the system camera prompt.
  ///
  /// Separate from [checkAvailability] because asking is a user-visible event
  /// that has to happen at a moment the user expects it. Both platforms limit
  /// how often the dialog can appear, so it is triggered from the capture
  /// screens rather than at launch, where it would arrive with no context.
  Future<CameraPermissionStatus> requestCameraPermission() async {
    try {
      final response = await _methods.invokeMapMethod<Object?, Object?>(
        'requestCameraPermission',
      );
      return switch (response?['status']) {
        'granted' => CameraPermissionStatus.granted,
        'permanentlyDenied' => CameraPermissionStatus.permanentlyDenied,
        'denied' => CameraPermissionStatus.denied,
        _ => CameraPermissionStatus.unsupported,
      };
    } on MissingPluginException {
      return CameraPermissionStatus.unsupported;
    } on PlatformException {
      return CameraPermissionStatus.denied;
    }
  }

  /// Asks the platform whether it can run before anything commits to it.
  Future<CaptureAvailability> checkAvailability() async {
    try {
      final response = await _methods.invokeMapMethod<Object?, Object?>(
        'availability',
      );
      if (response == null) {
        return const CaptureAvailability.unavailable(
          CaptureUnavailableReason.noPlatformImplementation,
        );
      }

      final reason = response['unavailable'] as String?;
      if (reason != null) {
        return CaptureAvailability.unavailable(
          _reasonFromWire(reason),
          detail: response['detail'] as String?,
        );
      }

      final runtime = CaptureProtocol.decodeRuntimeInfo(response);
      if (!runtime.isCompatible) {
        return CaptureAvailability.unavailable(
          CaptureUnavailableReason.contractMismatch,
          detail:
              'bridge speaks contract ${runtime.contractVersion}, '
              'this build speaks ${ModelContract.version}',
        );
      }

      _runtime = runtime;
      return CaptureAvailability.available(runtime);
    } on MissingPluginException {
      return const CaptureAvailability.unavailable(
        CaptureUnavailableReason.noPlatformImplementation,
      );
    } on PlatformException catch (error) {
      return CaptureAvailability.unavailable(
        _reasonFromWire(error.code),
        detail: error.message,
      );
    }
  }

  @override
  Future<void> startPreview({bool tripod = true, bool frontCamera = false}) async {
    await _listen();
    _adoptTexture(
      await _methods.invokeMapMethod<Object?, Object?>('startPreview', {
        'tripod': tripod,
        'frontCamera': frontCamera,
      }),
    );
  }

  @override
  Future<void> stopPreview() async {
    await _methods.invokeMethod<void>('stopPreview');
    _previewTexture.value = null;
  }

  /// Picks up the texture the native side just bound the camera to.
  ///
  /// A start that reports no texture is not an error: the platform may have no
  /// preview to offer, and the session still measures. The preview widget
  /// handles the null by saying what it is showing instead.
  void _adoptTexture(Map<Object?, Object?>? response) {
    final id = response?['textureId'];
    _previewTexture.value = id is int ? id : null;
  }

  @override
  Future<void> start(CaptureRequest request) async {
    _request = request;
    _shotIndex = 0;
    _sessionStartMs = null;
    _paused = false;
    _tracker = ShotTracker(frame: _courtFrame);

    await _listen();
    _adoptTexture(await _methods.invokeMapMethod<Object?, Object?>('start', {
      'drillId': request.drill.id,
      'angle': request.angle.name,
      'calibrationQuality': request.calibrationQuality,
      'tripod': request.tripod,
      'highFrameRate': request.highFrameRate,
      'thermalGuard': request.thermalGuard,
      'frontCamera': request.frontCamera,
      'pose': true,
    }));
  }

  @override
  Future<void> pause() async {
    _paused = true;
    await _methods.invokeMethod<void>('pause');
  }

  @override
  Future<void> resume() async {
    _paused = false;
    await _methods.invokeMethod<void>('resume');
  }

  @override
  Future<void> stop() async {
    // A shot in flight when the athlete stops should still be reported rather
    // than vanishing.
    final pending = _tracker?.flush();
    if (pending != null) _emitShot(pending);

    await _methods.invokeMethod<void>('stop');
    _previewTexture.value = null;
    await _events$?.cancel();
    _events$ = null;
  }

  @override
  Future<void> dispose() async {
    await _events$?.cancel();
    _events$ = null;
    await _frames.close();
    await _shots.close();
    await _observations.close();
  }

  Future<void> _listen() async {
    if (_events$ != null) return;
    _events$ = _events.receiveBroadcastStream().listen(
      _onEvent,
      onError: _onError,
    );
  }

  void _onEvent(dynamic event) {
    if (event is! Map) return;
    final payload = event.cast<Object?, Object?>();

    if (payload['type'] == CaptureProtocol.eventError) {
      _onError(
        PlatformException(
          code: (payload['code'] as String?) ?? 'unknown',
          message: payload['message'] as String?,
        ),
      );
      return;
    }

    final DetectionFrame detections;
    try {
      detections = CaptureProtocol.decodeDetectionFrame(payload);
    } on CaptureProtocolException catch (error) {
      // A frame we cannot read is dropped rather than guessed at. Guessing
      // here would surface as a measurement in centimetres.
      debugPrint('Dropped a capture frame: ${error.message}');
      return;
    }

    _emitObservation(detections);
    if (_request == null || _paused) return;

    _sessionStartMs ??= detections.timestampMs;

    final tracked = _tracker?.accept(detections);
    _emitFrame(detections);
    if (tracked != null) _emitShot(tracked);
  }

  void _emitObservation(DetectionFrame detections) {
    if (_observations.isClosed || !_observations.hasListener) return;
    final parts = detections.calibrationParts;
    _observations.add(
      CalibrationObservation(
        intrinsics: parts.intrinsics,
        rim: parts.rim,
        backboard: parts.backboard,
        conditions: parts.conditions,
        gravity: parts.gravity,
      ),
    );
  }

  void _emitFrame(DetectionFrame detections) {
    if (_frames.isClosed) return;

    final person = detections.subject;
    final width = detections.intrinsics.widthPx;
    final height = detections.intrinsics.heightPx;

    _frames.add(
      CaptureFrame(
        phase: _tracker?.phase ?? ShotPhaseKind.idle,
        cycleProgress: 0,
        pose: person == null
            ? null
            : ShotTracker.poseFromDetection(person, width, height),
        ball: detections.ball == null
            ? null
            : Offset(
                detections.ball!.centre.x / width,
                detections.ball!.centre.y / height,
              ),
        rim: _normalisedRect(detections, detections.rim),
        backboard: _normalisedRect(detections, detections.backboard),
        trackingConfidence: person?.meanScore ?? 0,
        processedFps: detections.processedFps,
        thermalHeadroom: detections.thermalHeadroom,
      ),
    );
  }

  Rect? _normalisedRect(DetectionFrame detections, Detection? box) {
    if (box == null) return null;
    final width = detections.intrinsics.widthPx;
    final height = detections.intrinsics.heightPx;
    return Rect.fromLTRB(
      box.left / width,
      box.top / height,
      box.right / width,
      box.bottom / height,
    );
  }

  void _emitShot(TrackedShot tracked) {
    final request = _request;
    if (request == null || _shots.isClosed) return;

    _shots.add(
      ShotAssembler.assemble(
        tracked: tracked,
        index: _shotIndex++,
        offsetFromStart: Duration(
          milliseconds: tracked.releasedAtMs - (_sessionStartMs ?? 0),
        ),
        frame: _courtFrame,
        calibrationQuality: request.calibrationQuality,
        drill: request.drill,
      ),
    );
  }

  void _onError(Object error) {
    if (!_frames.isClosed) _frames.addError(error);
    if (!_observations.isClosed) _observations.addError(error);
  }

  static CaptureUnavailableReason _reasonFromWire(String code) =>
      switch (code) {
        'modelsMissing' => CaptureUnavailableReason.modelsMissing,
        'contractMismatch' => CaptureUnavailableReason.contractMismatch,
        'cameraPermissionDenied' =>
          CaptureUnavailableReason.cameraPermissionDenied,
        'cameraUnavailable' => CaptureUnavailableReason.cameraUnavailable,
        _ => CaptureUnavailableReason.noPlatformImplementation,
      };
}
