import 'dart:ui' show Offset;

/// Landmarks the overlay renders. This is the compact subset the native
/// inference layer forwards to the product layer; full-resolution frames never
/// cross the boundary.
enum PoseJoint {
  head,
  neck,
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
}

/// Bones drawn between landmarks, in render order.
const List<(PoseJoint, PoseJoint)> poseSkeleton = [
  (PoseJoint.head, PoseJoint.neck),
  (PoseJoint.neck, PoseJoint.leftShoulder),
  (PoseJoint.neck, PoseJoint.rightShoulder),
  (PoseJoint.leftShoulder, PoseJoint.leftElbow),
  (PoseJoint.leftElbow, PoseJoint.leftWrist),
  (PoseJoint.rightShoulder, PoseJoint.rightElbow),
  (PoseJoint.rightElbow, PoseJoint.rightWrist),
  (PoseJoint.leftShoulder, PoseJoint.leftHip),
  (PoseJoint.rightShoulder, PoseJoint.rightHip),
  (PoseJoint.leftHip, PoseJoint.rightHip),
  (PoseJoint.leftHip, PoseJoint.leftKnee),
  (PoseJoint.leftKnee, PoseJoint.leftAnkle),
  (PoseJoint.rightHip, PoseJoint.rightKnee),
  (PoseJoint.rightKnee, PoseJoint.rightAnkle),
];

/// Landmark set for one processed frame, in normalised preview coordinates.
class PoseFrame {
  const PoseFrame({required this.landmarks, required this.confidence});

  final Map<PoseJoint, Offset> landmarks;
  final double confidence;

  Offset operator [](PoseJoint joint) =>
      landmarks[joint] ?? const Offset(0.5, 0.5);

  static PoseFrame lerp(PoseFrame a, PoseFrame b, double t) {
    final result = <PoseJoint, Offset>{};
    for (final joint in PoseJoint.values) {
      result[joint] = Offset.lerp(a[joint], b[joint], t)!;
    }
    return PoseFrame(
      landmarks: result,
      confidence: a.confidence + (b.confidence - a.confidence) * t,
    );
  }
}

/// Phases of the shooting motion, in the order the state machine traverses.
enum ShotPhaseKind {
  idle,
  possession,
  ready,
  dip,
  load,
  upward,
  setPoint,
  release,
  flight,
  rimInteraction,
  followThrough,
  landing,
  recovery;

  String get label => switch (this) {
    ShotPhaseKind.idle => 'Idle',
    ShotPhaseKind.possession => 'Possession',
    ShotPhaseKind.ready => 'Ready',
    ShotPhaseKind.dip => 'Dip',
    ShotPhaseKind.load => 'Load',
    ShotPhaseKind.upward => 'Upward motion',
    ShotPhaseKind.setPoint => 'Set point',
    ShotPhaseKind.release => 'Release',
    ShotPhaseKind.flight => 'Ball flight',
    ShotPhaseKind.rimInteraction => 'Rim interaction',
    ShotPhaseKind.followThrough => 'Follow-through',
    ShotPhaseKind.landing => 'Landing',
    ShotPhaseKind.recovery => 'Recovery',
  };

  bool get ballInHand => switch (this) {
    ShotPhaseKind.flight ||
    ShotPhaseKind.rimInteraction ||
    ShotPhaseKind.followThrough ||
    ShotPhaseKind.landing ||
    ShotPhaseKind.recovery => false,
    _ => true,
  };
}
