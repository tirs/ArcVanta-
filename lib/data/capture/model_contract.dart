import '../models/pose.dart';

/// The classes the detector is fine-tuned to find.
///
/// COCO has person and sports ball but neither a rim nor a backboard, and
/// those two are what the calibration stands on, so the detector is a
/// four-class fine-tune rather than a stock checkpoint.
enum DetectionClass {
  person(0, 'person'),
  ball(1, 'ball'),
  rim(2, 'rim'),
  backboard(3, 'backboard');

  const DetectionClass(this.id, this.wireName);

  final int id;
  final String wireName;

  static DetectionClass? fromId(int id) {
    for (final value in values) {
      if (value.id == id) return value;
    }
    return null;
  }
}

/// The Dart half of `vision/contract/model_contract.json`.
///
/// The JSON is the source of truth; this mirrors the parts the app has to
/// agree with the native bridge about. `tool/vision/verify_contract.py` checks
/// the exported graphs against the JSON, and
/// `test/capture/model_contract_test.dart` checks this against the JSON, so
/// the two cannot drift apart without something failing.
abstract final class ModelContract {
  static const int version = 1;

  static const String detectorFile = 'arcvanta_rtmdet_m_640.onnx';
  static const String poseFile = 'arcvanta_rtmpose_m_256x192.onnx';

  static const int detectorInputWidth = 640;
  static const int detectorInputHeight = 640;

  static const int poseInputWidth = 192;
  static const int poseInputHeight = 256;

  /// RTMPose predicts a one-dimensional distribution per axis at this
  /// multiple of the input resolution, so a peak index divides by it to land
  /// back in input pixels.
  static const double simccSplitRatio = 2.0;

  static const int poseKeypointCount = 17;

  /// COCO ordering, which is what RTMPose emits.
  static const List<String> cocoKeypoints = [
    'nose',
    'left_eye',
    'right_eye',
    'left_ear',
    'right_ear',
    'left_shoulder',
    'right_shoulder',
    'left_elbow',
    'right_elbow',
    'left_wrist',
    'right_wrist',
    'left_hip',
    'right_hip',
    'left_knee',
    'right_knee',
    'left_ankle',
    'right_ankle',
  ];

  /// Index into [cocoKeypoints] for each joint the product actually uses.
  /// [PoseJoint.neck] has no COCO equivalent and is the midpoint of the
  /// shoulders, so it is absent here and derived instead.
  static const Map<PoseJoint, int> cocoIndexForJoint = {
    PoseJoint.head: 0,
    PoseJoint.leftShoulder: 5,
    PoseJoint.rightShoulder: 6,
    PoseJoint.leftElbow: 7,
    PoseJoint.rightElbow: 8,
    PoseJoint.leftWrist: 9,
    PoseJoint.rightWrist: 10,
    PoseJoint.leftHip: 11,
    PoseJoint.rightHip: 12,
    PoseJoint.leftKnee: 13,
    PoseJoint.rightKnee: 14,
    PoseJoint.leftAnkle: 15,
    PoseJoint.rightAnkle: 16,
  };

  /// Joints built from other joints rather than predicted directly.
  static const Map<PoseJoint, (PoseJoint, PoseJoint)> derivedJoints = {
    PoseJoint.neck: (PoseJoint.leftShoulder, PoseJoint.rightShoulder),
  };
}

/// Which accelerator actually took the graph.
///
/// Both NNAPI and Core ML fall back per node without complaining, so the
/// bridge reports what it got rather than what it asked for. A run that landed
/// on the CPU is expected to hold a lower frame rate, not to produce different
/// numbers.
enum InferenceBackend {
  nnapi('NNAPI'),
  coreml('CoreML'),
  xnnpack('XNNPACK'),
  cpu('CPU'),
  unknown('unknown');

  const InferenceBackend(this.wireName);

  final String wireName;

  static InferenceBackend fromWire(String? value) {
    if (value == null) return InferenceBackend.unknown;
    for (final backend in values) {
      if (backend.wireName.toLowerCase() == value.toLowerCase()) return backend;
    }
    return InferenceBackend.unknown;
  }
}

/// What the native side reports about the models it loaded.
class ModelRuntimeInfo {
  const ModelRuntimeInfo({
    required this.contractVersion,
    required this.detectorVersion,
    required this.poseVersion,
    required this.backend,
  });

  final int contractVersion;
  final String detectorVersion;
  final String poseVersion;
  final InferenceBackend backend;

  /// The string stamped onto a finished session so a measurement can always be
  /// traced to the graphs that produced it.
  String get signature =>
      '$detectorVersion / $poseVersion / ${backend.wireName}';

  bool get isCompatible => contractVersion == ModelContract.version;
}
