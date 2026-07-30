import 'package:flutter/material.dart';

import '../../core/theme/av_colors.dart';
import 'confidence.dart';

enum ShotResult {
  made,
  missed,
  blocked,
  invalid,
  uncertain;

  String get label => switch (this) {
    ShotResult.made => 'Made',
    ShotResult.missed => 'Miss',
    ShotResult.blocked => 'Blocked',
    ShotResult.invalid => 'Invalid',
    ShotResult.uncertain => 'Uncertain',
  };

  Color get color => switch (this) {
    ShotResult.made => AvColors.made,
    ShotResult.missed => AvColors.miss,
    ShotResult.blocked => AvColors.insight,
    ShotResult.invalid => AvColors.unavailable,
    ShotResult.uncertain => AvColors.caution,
  };

  Color get softColor => switch (this) {
    ShotResult.made => AvColors.madeSoft,
    ShotResult.missed => AvColors.missSoft,
    ShotResult.blocked => AvColors.insightSoft,
    ShotResult.invalid => AvColors.unavailableSoft,
    ShotResult.uncertain => AvColors.cautionSoft,
  };

  IconData get icon => switch (this) {
    ShotResult.made => Icons.check_rounded,
    ShotResult.missed => Icons.close_rounded,
    ShotResult.blocked => Icons.block_rounded,
    ShotResult.invalid => Icons.remove_rounded,
    ShotResult.uncertain => Icons.question_mark_rounded,
  };

  bool get countsAsAttempt => this != ShotResult.invalid;
}

/// How the ball reached the result, when visual evidence supports it.
enum ShotOutcomeDetail {
  swish,
  rimMake,
  backboardMake,
  frontRim,
  backRim,
  leftRim,
  rightRim,
  short,
  long,
  airball,
  blocked,
  undetermined;

  String get label => switch (this) {
    ShotOutcomeDetail.swish => 'Swish',
    ShotOutcomeDetail.rimMake => 'Rim make',
    ShotOutcomeDetail.backboardMake => 'Backboard make',
    ShotOutcomeDetail.frontRim => 'Front rim',
    ShotOutcomeDetail.backRim => 'Back rim',
    ShotOutcomeDetail.leftRim => 'Left rim',
    ShotOutcomeDetail.rightRim => 'Right rim',
    ShotOutcomeDetail.short => 'Short',
    ShotOutcomeDetail.long => 'Long',
    ShotOutcomeDetail.airball => 'Airball',
    ShotOutcomeDetail.blocked => 'Blocked',
    ShotOutcomeDetail.undetermined => 'Not determined',
  };
}

enum ShotType {
  setShot,
  catchAndShoot,
  offDribble,
  pullUp,
  stepBack,
  movement,
  freeThrow,
  layup;

  String get label => switch (this) {
    ShotType.setShot => 'Set shot',
    ShotType.catchAndShoot => 'Catch and shoot',
    ShotType.offDribble => 'Off dribble',
    ShotType.pullUp => 'Pull-up',
    ShotType.stepBack => 'Step-back',
    ShotType.movement => 'Movement',
    ShotType.freeThrow => 'Free throw',
    ShotType.layup => 'Layup',
  };
}

/// Half-court zones used for location reporting.
enum CourtZone {
  leftCorner3,
  rightCorner3,
  leftWing3,
  rightWing3,
  topKey3,
  leftElbow,
  rightElbow,
  leftBaselineMid,
  rightBaselineMid,
  freeThrow,
  paint,
  restrictedArea;

  String get label => switch (this) {
    CourtZone.leftCorner3 => 'Left corner three',
    CourtZone.rightCorner3 => 'Right corner three',
    CourtZone.leftWing3 => 'Left wing three',
    CourtZone.rightWing3 => 'Right wing three',
    CourtZone.topKey3 => 'Top of the key three',
    CourtZone.leftElbow => 'Left elbow',
    CourtZone.rightElbow => 'Right elbow',
    CourtZone.leftBaselineMid => 'Left baseline midrange',
    CourtZone.rightBaselineMid => 'Right baseline midrange',
    CourtZone.freeThrow => 'Free-throw line',
    CourtZone.paint => 'Paint',
    CourtZone.restrictedArea => 'Restricted area',
  };

  String get shortLabel => switch (this) {
    CourtZone.leftCorner3 => 'L corner 3',
    CourtZone.rightCorner3 => 'R corner 3',
    CourtZone.leftWing3 => 'L wing 3',
    CourtZone.rightWing3 => 'R wing 3',
    CourtZone.topKey3 => 'Top key 3',
    CourtZone.leftElbow => 'L elbow',
    CourtZone.rightElbow => 'R elbow',
    CourtZone.leftBaselineMid => 'L baseline',
    CourtZone.rightBaselineMid => 'R baseline',
    CourtZone.freeThrow => 'Free throw',
    CourtZone.paint => 'Paint',
    CourtZone.restrictedArea => 'Restricted',
  };

  bool get isThree => switch (this) {
    CourtZone.leftCorner3 ||
    CourtZone.rightCorner3 ||
    CourtZone.leftWing3 ||
    CourtZone.rightWing3 ||
    CourtZone.topKey3 => true,
    _ => false,
  };

  /// Normalised half-court position. `dx` spans the 50-foot court width and
  /// `dy` spans the 35 feet of depth the shot chart renders, measured from the
  /// baseline.
  Offset get position => switch (this) {
    CourtZone.leftCorner3 => const Offset(0.06, 0.20),
    CourtZone.rightCorner3 => const Offset(0.94, 0.20),
    CourtZone.leftWing3 => const Offset(0.13, 0.69),
    CourtZone.rightWing3 => const Offset(0.87, 0.69),
    CourtZone.topKey3 => const Offset(0.50, 0.84),
    CourtZone.leftElbow => const Offset(0.34, 0.54),
    CourtZone.rightElbow => const Offset(0.66, 0.54),
    CourtZone.leftBaselineMid => const Offset(0.20, 0.23),
    CourtZone.rightBaselineMid => const Offset(0.80, 0.23),
    CourtZone.freeThrow => const Offset(0.50, 0.54),
    CourtZone.paint => const Offset(0.50, 0.33),
    CourtZone.restrictedArea => const Offset(0.50, 0.16),
  };
}

/// One phase of the shooting motion with its measured duration.
class ShotPhase {
  const ShotPhase({
    required this.name,
    required this.startMs,
    required this.durationMs,
  });

  final String name;
  final int startMs;
  final int durationMs;
}

/// A single measured value with the evidence needed to display it honestly.
class MetricValue {
  const MetricValue({
    required this.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.confidence,
    this.eligibleAngles = const {
      CameraAngle.front,
      CameraAngle.side,
      CameraAngle.rear,
      CameraAngle.diagonal,
    },
    this.targetLow,
    this.targetHigh,
    this.personalBaseline,
    this.uncertainty,
    this.description = '',
  });

  final String key;
  final String label;
  final double value;
  final String unit;
  final ConfidenceLevel confidence;
  final Set<CameraAngle> eligibleAngles;
  final double? targetLow;
  final double? targetHigh;
  final double? personalBaseline;

  /// Plus/minus band. Present whenever calibration cannot support a point
  /// estimate, so the interface never shows false precision.
  final double? uncertainty;
  final String description;

  bool eligibleFor(CameraAngle angle) => eligibleAngles.contains(angle);

  bool get inTarget {
    if (targetLow == null || targetHigh == null) return true;
    return value >= targetLow! && value <= targetHigh!;
  }

  double? get deltaFromBaseline =>
      personalBaseline == null ? null : value - personalBaseline!;

  String get formatted {
    if (confidence == ConfidenceLevel.unavailable) return 'Not available';
    final decimals = confidence.allowedDecimals;
    final text = value.toStringAsFixed(decimals);
    if (uncertainty != null && uncertainty! > 0) {
      return '$text \u00B1${uncertainty!.toStringAsFixed(decimals)}$unit';
    }
    return '$text$unit';
  }
}

/// A detected shot attempt and everything measured about it.
class Shot {
  const Shot({
    required this.id,
    required this.index,
    required this.offsetFromStart,
    required this.result,
    required this.outcomeDetail,
    required this.zone,
    required this.type,
    required this.confidence,
    required this.releaseAngle,
    required this.entryAngle,
    required this.apexHeightM,
    required this.releaseHeightM,
    required this.ballSpeedMs,
    required this.flightTimeMs,
    required this.lateralDeviationCm,
    required this.depthCm,
    required this.elbowAngle,
    required this.kneeFlexion,
    required this.guideHandSeparationCm,
    required this.releaseTimeMs,
    required this.followThroughMs,
    required this.landingDriftCm,
    required this.balanceScore,
    required this.mechanicsScore,
    required this.trajectory,
    required this.phases,
    this.correctedByUser = false,
    this.note,
  });

  final String id;
  final int index;
  final Duration offsetFromStart;
  final ShotResult result;
  final ShotOutcomeDetail outcomeDetail;
  final CourtZone zone;
  final ShotType type;
  final ConfidenceLevel confidence;

  final double releaseAngle;
  final double entryAngle;
  final double apexHeightM;
  final double releaseHeightM;
  final double ballSpeedMs;
  final int flightTimeMs;
  final double lateralDeviationCm;
  final double depthCm;

  final double elbowAngle;
  final double kneeFlexion;
  final double guideHandSeparationCm;
  final int releaseTimeMs;
  final int followThroughMs;
  final double landingDriftCm;
  final double balanceScore;
  final double mechanicsScore;

  /// Normalised ball path in view space, ordered from release to rim.
  final List<Offset> trajectory;
  final List<ShotPhase> phases;

  final bool correctedByUser;
  final String? note;

  bool get isMake => result == ShotResult.made;
  bool get isSwish => outcomeDetail == ShotOutcomeDetail.swish;

  Shot copyWith({
    String? id,
    int? index,
    Duration? offsetFromStart,
    ShotResult? result,
    ShotOutcomeDetail? outcomeDetail,
    ConfidenceLevel? confidence,
    bool? correctedByUser,
    String? note,
  }) {
    return Shot(
      id: id ?? this.id,
      index: index ?? this.index,
      offsetFromStart: offsetFromStart ?? this.offsetFromStart,
      result: result ?? this.result,
      outcomeDetail: outcomeDetail ?? this.outcomeDetail,
      zone: zone,
      type: type,
      confidence: confidence ?? this.confidence,
      releaseAngle: releaseAngle,
      entryAngle: entryAngle,
      apexHeightM: apexHeightM,
      releaseHeightM: releaseHeightM,
      ballSpeedMs: ballSpeedMs,
      flightTimeMs: flightTimeMs,
      lateralDeviationCm: lateralDeviationCm,
      depthCm: depthCm,
      elbowAngle: elbowAngle,
      kneeFlexion: kneeFlexion,
      guideHandSeparationCm: guideHandSeparationCm,
      releaseTimeMs: releaseTimeMs,
      followThroughMs: followThroughMs,
      landingDriftCm: landingDriftCm,
      balanceScore: balanceScore,
      mechanicsScore: mechanicsScore,
      trajectory: trajectory,
      phases: phases,
      correctedByUser: correctedByUser ?? this.correctedByUser,
      note: note ?? this.note,
    );
  }
}
