import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/calibration/calibration_solver.dart';
import '../data/calibration/court_frame.dart';
import '../data/capture/calibration_source.dart';
import '../data/capture/capture_source.dart';
import '../data/capture/native_capture_source.dart';
import '../data/capture/simulated_capture_source.dart';
import '../data/capture/model_contract.dart';

/// Which pipeline is attached, and why.
class PipelineStatus {
  const PipelineStatus({
    required this.isLive,
    required this.runtime,
    required this.fallbackReason,
    required this.fallbackDetail,
  });

  const PipelineStatus.simulated({
    CaptureUnavailableReason? reason,
    String? detail,
  }) : isLive = false,
       runtime = null,
       fallbackReason = reason,
       fallbackDetail = detail;

  /// True when measurements come from the camera. False means the numbers on
  /// screen are generated, and the interface says so rather than letting a
  /// demo pass for a session.
  final bool isLive;

  final ModelRuntimeInfo? runtime;
  final CaptureUnavailableReason? fallbackReason;
  final String? fallbackDetail;

  /// What to tell the athlete when the camera pipeline is not running.
  String get explanation => switch (fallbackReason) {
    null => 'Measuring from the camera',
    CaptureUnavailableReason.noPlatformImplementation =>
      'This build has no camera pipeline, so sessions are simulated',
    CaptureUnavailableReason.modelsMissing =>
      'The analysis models are not installed, so sessions are simulated',
    CaptureUnavailableReason.contractMismatch =>
      'The installed models do not match this version of the app',
    CaptureUnavailableReason.cameraPermissionDenied =>
      'ArcVanta needs camera access to measure a session',
    CaptureUnavailableReason.cameraUnavailable =>
      'The camera is in use by another app',
  };

  /// The string stamped onto a finished session, so a stored measurement can
  /// always be traced to what produced it.
  String get signature => runtime?.signature ?? 'simulated';
}

/// The single native source, kept alive across the calibration screen and the
/// session so the camera is opened once.
final _nativeSourceProvider = Provider<NativeCaptureSource>((ref) {
  final source = NativeCaptureSource();
  ref.onDispose(source.dispose);
  return source;
});

final _simulatedSourceProvider = Provider<SimulatedCaptureSource>((ref) {
  final source = SimulatedCaptureSource();
  ref.onDispose(source.dispose);
  return source;
});

/// Asks the platform once whether it can run the real pipeline.
final pipelineStatusProvider = FutureProvider<PipelineStatus>((ref) async {
  final native = ref.watch(_nativeSourceProvider);
  final availability = await native.checkAvailability();

  if (!availability.isAvailable) {
    return PipelineStatus.simulated(
      reason: availability.reason,
      detail: availability.detail,
    );
  }

  return PipelineStatus(
    isLive: true,
    runtime: availability.runtime,
    fallbackReason: null,
    fallbackDetail: null,
  );
});

/// The pipeline the screens talk to.
///
/// Resolves to the native bridge where there is one and to the simulation
/// everywhere else, including tests and desktop. Screens never branch on
/// which: they read [pipelineStatusProvider] only to tell the athlete whether
/// the numbers are measured.
final captureSourceProvider = Provider<CaptureSource>((ref) {
  final status = ref.watch(pipelineStatusProvider).valueOrNull;
  return status != null && status.isLive
      ? ref.watch(_nativeSourceProvider)
      : ref.watch(_simulatedSourceProvider);
});

/// Asks for camera access, then re-checks whether the pipeline can run.
///
/// Kept here rather than on a screen because the answer invalidates
/// [pipelineStatusProvider]: a grant turns a simulated session into a measured
/// one, and nothing would notice unless the availability check runs again.
final cameraPermissionRequestProvider = Provider<Future<CameraPermissionStatus>
    Function()>((ref) {
  return () async {
    final status = await ref.read(_nativeSourceProvider)
        .requestCameraPermission();

    if (status == CameraPermissionStatus.granted) {
      ref.invalidate(pipelineStatusProvider);
    }
    return status;
  };
});

/// The camera texture currently open, or null when nothing is.
///
/// Exposed as a listenable rather than a value because the texture arrives
/// after the preview widget has already mounted: the camera is bound during
/// the first frames of the screen that shows it.
final previewTextureProvider = Provider<ValueListenable<int?>>(
  (ref) => ref.watch(captureSourceProvider).previewTexture,
);

/// Whether the athlete said the phone is mounted rather than held.
///
/// Declared on the placement step and read by both calibration and the
/// session, because the grade a handheld setup deserves is not the grade a
/// tripod deserves and the solver cannot always tell them apart from one run.
final tripodDeclaredProvider = NotifierProvider<TripodStore, bool>(
  TripodStore.new,
);

class TripodStore extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool value) => state = value;
}

/// Whether the athlete chose the front (selfie) camera so they can see the
/// tracking overlay while shooting. Declared on the placement step.
final frontCameraProvider = NotifierProvider<FrontCameraStore, bool>(
  FrontCameraStore.new,
);

class FrontCameraStore extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// The same object, seen through the calibration interface.
final calibrationSourceProvider = Provider<CalibrationSource>((ref) {
  final source = ref.watch(captureSourceProvider);
  return source as CalibrationSource;
});

/// The scene the session measures against, solved by the calibration screen.
///
/// Null until calibration succeeds. A session started without it still records
/// shots, but every metric that needs geometry is reported unavailable rather
/// than estimated.
final courtFrameProvider = NotifierProvider<CourtFrameStore, CourtFrame?>(
  CourtFrameStore.new,
);

class CourtFrameStore extends Notifier<CourtFrame?> {
  @override
  CourtFrame? build() => null;

  void set(CourtFrame? frame) {
    state = frame;
    final source = ref.read(captureSourceProvider);
    if (source is NativeCaptureSource) source.courtFrame = frame;
  }

  void clear() => set(null);
}

/// The solve the athlete accepted, kept so the finished session can record the
/// numbers the setup was actually graded on instead of restating a constant.
class CommittedCalibration {
  const CommittedCalibration({
    required this.solution,
    required this.conditions,
  });

  final CalibrationSolution solution;
  final CaptureConditions conditions;

  double _factor(String label) {
    for (final factor in solution.factors) {
      if (factor.label == label) return factor.score;
    }
    return 0;
  }

  double get lighting => _factor('Lighting');
  double get stability => _factor('Stability');
  double get framing => _factor('Framing');

  /// One line per graded factor, in the athlete's words rather than the
  /// solver's, so the session detail explains its own confidence.
  List<String> get notes => [
    for (final factor in solution.factors) '${factor.label}: ${factor.detail}',
  ];
}

final committedCalibrationProvider =
    NotifierProvider<CommittedCalibrationStore, CommittedCalibration?>(
      CommittedCalibrationStore.new,
    );

class CommittedCalibrationStore extends Notifier<CommittedCalibration?> {
  @override
  CommittedCalibration? build() => null;

  void set(CommittedCalibration? calibration) => state = calibration;

  void clear() => state = null;
}
