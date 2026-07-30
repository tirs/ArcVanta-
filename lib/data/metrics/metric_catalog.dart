import '../models/confidence.dart';
import '../models/session.dart';
import '../models/shot.dart';

/// Grouping used to organise metrics in the interface.
enum MetricGroup {
  outcome,
  arc,
  accuracy,
  mechanics,
  timing;

  String get label => switch (this) {
    MetricGroup.outcome => 'Outcome',
    MetricGroup.arc => 'Arc and flight',
    MetricGroup.accuracy => 'Accuracy at the rim',
    MetricGroup.mechanics => 'Body mechanics',
    MetricGroup.timing => 'Timing and balance',
  };

  String get description => switch (this) {
    MetricGroup.outcome =>
      'What happened to the ball and how certain the system is about it.',
    MetricGroup.arc => 'The shape of the shot from release to the rim.',
    MetricGroup.accuracy =>
      'Where the ball arrived relative to the centre of the rim.',
    MetricGroup.mechanics =>
      'Joint angles measured through the shooting motion.',
    MetricGroup.timing =>
      'How long each part of the motion took and how you landed.',
  };
}

/// A measurement together with the group it belongs to.
class GroupedMetric {
  const GroupedMetric(this.group, this.metric);

  final MetricGroup group;
  final MetricValue metric;
}

/// The single definition of every measurement the product presents.
///
/// Targets come from the coaching model in the scope, eligibility is a property
/// of camera placement, and confidence is inherited from the shot record. Screens
/// read from here rather than formatting raw fields, which is what keeps the
/// same number from being shown three different ways.
abstract final class MetricCatalog {
  static const _sideish = {CameraAngle.side, CameraAngle.diagonal};
  static const _frontish = {CameraAngle.front, CameraAngle.diagonal};
  static const _depthish = {CameraAngle.side, CameraAngle.rear};
  static const _all = {
    CameraAngle.front,
    CameraAngle.side,
    CameraAngle.rear,
    CameraAngle.diagonal,
  };

  static List<GroupedMetric> forShot(
    Shot shot, {
    required CameraAngle angle,
    Map<String, double> baselines = const {},
  }) {
    ConfidenceLevel grade(Set<CameraAngle> eligible) => eligible.contains(angle)
        ? shot.confidence
        : ConfidenceLevel.unavailable;

    return [
      GroupedMetric(
        MetricGroup.arc,
        MetricValue(
          key: 'releaseAngle',
          label: 'Release angle',
          value: shot.releaseAngle,
          unit: '\u00B0',
          confidence: grade(_sideish),
          eligibleAngles: _sideish,
          targetLow: 48,
          targetHigh: 55,
          personalBaseline: baselines['releaseAngle'],
          description:
              'Angle of the ball leaving the hand, measured against '
              'the floor plane.',
        ),
      ),
      GroupedMetric(
        MetricGroup.arc,
        MetricValue(
          key: 'entryAngle',
          label: 'Entry angle',
          value: shot.entryAngle,
          unit: '\u00B0',
          confidence: grade({...(_depthish), CameraAngle.diagonal}),
          eligibleAngles: {..._depthish, CameraAngle.diagonal},
          targetLow: 43,
          targetHigh: 50,
          personalBaseline: baselines['entryAngle'],
          description:
              'Angle the ball makes with the rim plane on arrival. '
              'Forty-five degrees maximises the effective opening.',
        ),
      ),
      GroupedMetric(
        MetricGroup.arc,
        MetricValue(
          key: 'apexHeight',
          label: 'Apex height',
          value: shot.apexHeightM,
          unit: ' m',
          confidence: grade(_sideish),
          eligibleAngles: _sideish,
          targetLow: 3.4,
          targetHigh: 4.2,
          personalBaseline: baselines['apexHeight'],
          description: 'Highest point of the flight path above the floor.',
        ),
      ),
      GroupedMetric(
        MetricGroup.arc,
        MetricValue(
          key: 'releaseHeight',
          label: 'Release height',
          value: shot.releaseHeightM,
          unit: ' m',
          confidence: grade(_sideish),
          eligibleAngles: _sideish,
          personalBaseline: baselines['releaseHeight'],
          description: 'Height of the ball at the moment it leaves the hand.',
        ),
      ),
      GroupedMetric(
        MetricGroup.arc,
        MetricValue(
          key: 'ballSpeed',
          label: 'Ball speed',
          value: shot.ballSpeedMs,
          unit: ' m/s',
          confidence: grade(_sideish),
          eligibleAngles: _sideish,
          description:
              'Speed of the ball measured over the first metre of '
              'flight.',
        ),
      ),
      GroupedMetric(
        MetricGroup.accuracy,
        MetricValue(
          key: 'lateral',
          label: 'Left / right',
          value: shot.lateralDeviationCm,
          unit: ' cm',
          confidence: grade({CameraAngle.front, CameraAngle.rear}),
          eligibleAngles: const {CameraAngle.front, CameraAngle.rear},
          targetLow: -5,
          targetHigh: 5,
          personalBaseline: baselines['lateral'],
          description:
              'Horizontal distance from the centre of the rim. '
              'Negative values are left.',
        ),
      ),
      GroupedMetric(
        MetricGroup.accuracy,
        MetricValue(
          key: 'depth',
          label: 'Depth',
          value: shot.depthCm,
          unit: ' cm',
          confidence: grade(_depthish),
          eligibleAngles: _depthish,
          targetLow: 0,
          targetHigh: 11,
          personalBaseline: baselines['depth'],
          description:
              'Distance past the centre of the rim. A shade long is '
              'the most forgiving miss.',
        ),
      ),
      GroupedMetric(
        MetricGroup.mechanics,
        MetricValue(
          key: 'elbow',
          label: 'Elbow angle at set point',
          value: shot.elbowAngle,
          unit: '\u00B0',
          confidence: grade({CameraAngle.front, CameraAngle.side}),
          eligibleAngles: const {CameraAngle.front, CameraAngle.side},
          targetLow: 84,
          targetHigh: 96,
          personalBaseline: baselines['elbow'],
          description:
              'Angle between upper arm and forearm when the ball '
              'reaches the set point.',
        ),
      ),
      GroupedMetric(
        MetricGroup.mechanics,
        MetricValue(
          key: 'knee',
          label: 'Knee flexion',
          value: shot.kneeFlexion,
          unit: '\u00B0',
          confidence: grade(_sideish),
          eligibleAngles: _sideish,
          targetLow: 118,
          targetHigh: 138,
          personalBaseline: baselines['knee'],
          description:
              'Deepest knee angle in the load phase. Smaller numbers '
              'mean a deeper bend.',
        ),
      ),
      GroupedMetric(
        MetricGroup.mechanics,
        MetricValue(
          key: 'guideHand',
          label: 'Guide-hand separation',
          value: shot.guideHandSeparationCm,
          unit: ' cm',
          confidence: grade(_frontish),
          eligibleAngles: _frontish,
          targetLow: 0,
          targetHigh: 6,
          personalBaseline: baselines['guideHand'],
          description:
              'Distance the guide hand travels away from the ball at '
              'release. Late contact pushes the shot sideways.',
        ),
      ),
      GroupedMetric(
        MetricGroup.timing,
        MetricValue(
          key: 'releaseTime',
          label: 'Release time',
          value: shot.releaseTimeMs / 1000,
          unit: ' s',
          confidence: grade(_all),
          eligibleAngles: _all,
          targetLow: 0.42,
          targetHigh: 0.68,
          personalBaseline: baselines['releaseTime'],
          description:
              'Time from the start of the dip to the ball leaving '
              'the hand.',
        ),
      ),
      GroupedMetric(
        MetricGroup.timing,
        MetricValue(
          key: 'followThrough',
          label: 'Follow-through hold',
          value: shot.followThroughMs / 1000,
          unit: ' s',
          confidence: grade(_all),
          eligibleAngles: _all,
          targetLow: 0.6,
          targetHigh: 1.2,
          personalBaseline: baselines['followThrough'],
          description:
              'How long the shooting hand stays extended after '
              'release.',
        ),
      ),
      GroupedMetric(
        MetricGroup.timing,
        MetricValue(
          key: 'landingDrift',
          label: 'Landing drift',
          value: shot.landingDriftCm,
          unit: ' cm',
          confidence: grade(_all),
          eligibleAngles: _all,
          targetLow: -8,
          targetHigh: 8,
          personalBaseline: baselines['landingDrift'],
          description:
              'Distance between take-off and landing point. Drift '
              'costs repeatability more than it costs any single shot.',
        ),
      ),
      GroupedMetric(
        MetricGroup.timing,
        MetricValue(
          key: 'balance',
          label: 'Balance score',
          value: shot.balanceScore,
          unit: '',
          confidence: grade(_all),
          eligibleAngles: _all,
          targetLow: 82,
          targetHigh: 100,
          personalBaseline: baselines['balance'],
          description:
              'Composite of landing drift, trunk lean and shoulder '
              'level through the motion.',
        ),
      ),
    ];
  }

  /// Per-metric session averages, using only measurements the system is willing
  /// to stand behind.
  static Map<String, double> sessionBaselines(TrainingSession session) {
    final graded = session.attempts
        .where((s) => s.confidence.isAuthoritative)
        .toList(growable: false);
    if (graded.isEmpty) return const {};

    double mean(double Function(Shot) selector) =>
        graded.map(selector).reduce((a, b) => a + b) / graded.length;

    return {
      'releaseAngle': mean((s) => s.releaseAngle),
      'entryAngle': mean((s) => s.entryAngle),
      'apexHeight': mean((s) => s.apexHeightM),
      'releaseHeight': mean((s) => s.releaseHeightM),
      'lateral': mean((s) => s.lateralDeviationCm),
      'depth': mean((s) => s.depthCm),
      'elbow': mean((s) => s.elbowAngle),
      'knee': mean((s) => s.kneeFlexion),
      'guideHand': mean((s) => s.guideHandSeparationCm),
      'releaseTime': mean((s) => s.releaseTimeMs / 1000),
      'followThrough': mean((s) => s.followThroughMs / 1000),
      'landingDrift': mean((s) => s.landingDriftCm),
      'balance': mean((s) => s.balanceScore),
    };
  }

  /// Average of a session's metrics presented in the same shape as a shot, used
  /// by the session summary.
  static List<GroupedMetric> forSession(TrainingSession session) {
    final graded = session.attempts
        .where((s) => s.confidence.isAuthoritative)
        .toList(growable: false);
    if (graded.isEmpty) return const [];

    final representative = session.bestMechanicsShot ?? graded.first;
    final baselines = sessionBaselines(session);
    final averaged = MetricCatalog.forShot(
      representative,
      angle: session.calibration.angle,
    );

    return [
      for (final entry in averaged)
        GroupedMetric(
          entry.group,
          MetricValue(
            key: entry.metric.key,
            label: entry.metric.label,
            value: baselines[entry.metric.key] ?? entry.metric.value,
            unit: entry.metric.unit,
            confidence: entry.metric.confidence,
            eligibleAngles: entry.metric.eligibleAngles,
            targetLow: entry.metric.targetLow,
            targetHigh: entry.metric.targetHigh,
            personalBaseline: entry.metric.personalBaseline,
            description: entry.metric.description,
          ),
        ),
    ];
  }

  static List<GroupedMetric> inGroup(
    List<GroupedMetric> metrics,
    MetricGroup group,
  ) => metrics.where((m) => m.group == group).toList(growable: false);
}
