import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/av_colors.dart';
import 'confidence.dart';
import 'shot.dart';

/// Origin of a coaching statement. Human and automated feedback are never
/// presented as the same thing.
enum CueSource {
  measurement,
  trend,
  humanCoach;

  String get label => switch (this) {
    CueSource.measurement => 'Measured this session',
    CueSource.trend => 'Trend across sessions',
    CueSource.humanCoach => 'From your coach',
  };

  IconData get icon => switch (this) {
    CueSource.measurement => Icons.straighten_rounded,
    CueSource.trend => Icons.timeline_rounded,
    CueSource.humanCoach => Icons.record_voice_over_rounded,
  };

  Color get color => switch (this) {
    CueSource.measurement => AvColors.court,
    CueSource.trend => AvColors.insight,
    CueSource.humanCoach => AvColors.flare,
  };
}

enum CuePriority { primary, supporting, reinforcement }

/// A single coaching statement, always tied to the measurements that produced
/// it so the interface can show its evidence.
class CoachingCue {
  const CoachingCue({
    required this.id,
    required this.headline,
    required this.detail,
    required this.source,
    required this.priority,
    required this.confidence,
    this.evidence = const [],
    this.suggestedDrillId,
    this.authorName,
  });

  final String id;
  final String headline;
  final String detail;
  final CueSource source;
  final CuePriority priority;
  final ConfidenceLevel confidence;
  final List<String> evidence;
  final String? suggestedDrillId;
  final String? authorName;
}

/// Camera and calibration state recorded with the session.
class CalibrationRecord {
  const CalibrationRecord({
    required this.angle,
    required this.qualityScore,
    required this.courtProfile,
    required this.rimHeightM,
    required this.lightingScore,
    required this.stabilityScore,
    required this.framingScore,
    required this.frameRate,
    required this.notes,
  });

  final CameraAngle angle;
  final double qualityScore;
  final String courtProfile;
  final double rimHeightM;
  final double lightingScore;
  final double stabilityScore;
  final double framingScore;
  final int frameRate;
  final List<String> notes;

  ConfidenceLevel get level => ConfidenceLevel.fromScore(qualityScore);
}

/// A completed training session.
class TrainingSession {
  const TrainingSession({
    required this.id,
    required this.drillId,
    required this.drillName,
    required this.startedAt,
    required this.duration,
    required this.shots,
    required this.calibration,
    required this.cues,
    required this.modelVersion,
    required this.deviceName,
    required this.processedOnDevice,
    this.assignmentId,
    this.coachComment,
  });

  final String id;
  final String drillId;
  final String drillName;
  final DateTime startedAt;
  final Duration duration;
  final List<Shot> shots;
  final CalibrationRecord calibration;
  final List<CoachingCue> cues;
  final String modelVersion;
  final String deviceName;
  final bool processedOnDevice;
  final String? assignmentId;
  final String? coachComment;

  List<Shot> get attempts =>
      shots.where((s) => s.result.countsAsAttempt).toList(growable: false);

  int get attemptCount => attempts.length;
  int get makeCount => shots.where((s) => s.isMake).length;
  int get missCount => shots.where((s) => s.result == ShotResult.missed).length;
  int get uncertainCount =>
      shots.where((s) => s.result == ShotResult.uncertain).length;
  int get swishCount => shots.where((s) => s.isSwish).length;

  double get percentage =>
      attemptCount == 0 ? 0 : makeCount / attemptCount * 100;

  double get swishRate => makeCount == 0 ? 0 : swishCount / makeCount * 100;

  int get bestStreak {
    var best = 0;
    var run = 0;
    for (final shot in attempts) {
      if (shot.isMake) {
        run++;
        if (run > best) best = run;
      } else {
        run = 0;
      }
    }
    return best;
  }

  Duration get averageInterval => attemptCount < 2
      ? Duration.zero
      : Duration(
          milliseconds:
              (attempts.last.offsetFromStart.inMilliseconds -
                  attempts.first.offsetFromStart.inMilliseconds) ~/
              (attemptCount - 1),
        );

  double get averageMechanics => attempts.isEmpty
      ? 0
      : attempts.map((s) => s.mechanicsScore).reduce((a, b) => a + b) /
            attempts.length;

  double get averageReleaseAngle => attempts.isEmpty
      ? 0
      : attempts.map((s) => s.releaseAngle).reduce((a, b) => a + b) /
            attempts.length;

  double get averageEntryAngle => attempts.isEmpty
      ? 0
      : attempts.map((s) => s.entryAngle).reduce((a, b) => a + b) /
            attempts.length;

  /// Shot-to-shot mechanical variance. Lower is more repeatable.
  double get consistencyScore {
    if (attempts.length < 2) return 0;
    final mean = averageMechanics;
    final variance =
        attempts
            .map((s) => (s.mechanicsScore - mean) * (s.mechanicsScore - mean))
            .reduce((a, b) => a + b) /
        attempts.length;
    final spread = math.sqrt(variance);
    return (100 - spread * 4.2).clamp(0, 100).toDouble();
  }

  Map<CourtZone, ZoneRecord> get zoneBreakdown {
    final map = <CourtZone, ZoneRecord>{};
    for (final shot in attempts) {
      final existing = map[shot.zone] ?? const ZoneRecord(0, 0);
      map[shot.zone] = ZoneRecord(
        existing.makes + (shot.isMake ? 1 : 0),
        existing.attempts + 1,
      );
    }
    return map;
  }

  Shot? get bestMechanicsShot {
    if (attempts.isEmpty) return null;
    return attempts.reduce(
      (a, b) => a.mechanicsScore >= b.mechanicsScore ? a : b,
    );
  }

  /// The miss that best represents the session's dominant error pattern.
  Shot? get representativeMiss {
    final misses = attempts
        .where((s) => s.result == ShotResult.missed)
        .toList();
    if (misses.isEmpty) return null;
    final meanDeviation =
        misses.map((s) => s.lateralDeviationCm).reduce((a, b) => a + b) /
        misses.length;
    misses.sort(
      (a, b) => (a.lateralDeviationCm - meanDeviation).abs().compareTo(
        (b.lateralDeviationCm - meanDeviation).abs(),
      ),
    );
    return misses.first;
  }

  CoachingCue? get primaryCue {
    for (final cue in cues) {
      if (cue.priority == CuePriority.primary) return cue;
    }
    return cues.isEmpty ? null : cues.first;
  }
}

class ZoneRecord {
  const ZoneRecord(this.makes, this.attempts);

  final int makes;
  final int attempts;

  double get percentage => attempts == 0 ? 0 : makes / attempts * 100;
}
