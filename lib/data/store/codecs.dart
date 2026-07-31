import 'dart:convert';

import 'package:flutter/painting.dart' show Color, Offset;

import '../models/confidence.dart';
import '../models/drill.dart';
import '../models/profile.dart';
import '../models/program.dart';
import '../models/session.dart';
import '../models/shot.dart';

/// Turns the domain models into rows and back.
///
/// Written by hand rather than generated. There are two reasons and they both
/// come down to the same thing: a stored session is a record of a measurement
/// that happened, and it has to survive the code that wrote it. Hand-written
/// decoders can accept a row missing a field added last release; generated ones
/// tend to throw. And enums are stored by name, never by index, so reordering
/// `ShotResult` cannot silently turn every recorded make into a miss.
abstract final class Codecs {
  /// Reads an enum by name, falling back rather than throwing.
  ///
  /// A row written by a newer build may name a variant this one has never
  /// heard of. Losing one field of one shot is recoverable; failing to open the
  /// history is not.
  static T enumByName<T extends Enum>(
    List<T> values,
    Object? raw,
    T fallback,
  ) {
    if (raw is! String) return fallback;
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return fallback;
  }

  static double number(Object? raw, [double fallback = 0]) =>
      raw is num ? raw.toDouble() : fallback;

  static int integer(Object? raw, [int fallback = 0]) =>
      raw is num ? raw.toInt() : fallback;

  static bool boolean(Object? raw, [bool fallback = false]) {
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    return fallback;
  }

  static String text(Object? raw, [String fallback = '']) =>
      raw is String ? raw : fallback;

  static List<Object?> jsonList(Object? raw) {
    if (raw is List) return raw;
    if (raw is String && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded;
    }
    return const [];
  }

  static Map<String, Object?> jsonMap(Object? raw) {
    if (raw is Map) return raw.cast<String, Object?>();
    if (raw is String && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return decoded.cast<String, Object?>();
    }
    return const {};
  }

  // --- Shot ---------------------------------------------------------------

  /// The parts of a shot no query ever filters on, kept as one JSON blob.
  ///
  /// A trajectory is a hundred points and a phase list is five records. Giving
  /// them columns would mean two more tables and a join on every read, to
  /// support sorting nobody does.
  static String encodeShotDetail(Shot shot) => jsonEncode({
    'trajectory': [
      for (final point in shot.trajectory) [point.dx, point.dy],
    ],
    'phases': [
      for (final phase in shot.phases)
        {
          'name': phase.name,
          'startMs': phase.startMs,
          'durationMs': phase.durationMs,
        },
    ],
  });

  static Map<String, Object?> shotToRow(Shot shot, String sessionId) => {
    'id': shot.id,
    'session_id': sessionId,
    'idx': shot.index,
    'offset_ms': shot.offsetFromStart.inMilliseconds,
    'result': shot.result.name,
    'outcome_detail': shot.outcomeDetail.name,
    'zone': shot.zone.name,
    'type': shot.type.name,
    'confidence': shot.confidence.name,
    'release_angle': shot.releaseAngle,
    'entry_angle': shot.entryAngle,
    'apex_height_m': shot.apexHeightM,
    'release_height_m': shot.releaseHeightM,
    'ball_speed_ms': shot.ballSpeedMs,
    'flight_time_ms': shot.flightTimeMs,
    'lateral_deviation_cm': shot.lateralDeviationCm,
    'depth_cm': shot.depthCm,
    'elbow_angle': shot.elbowAngle,
    'knee_flexion': shot.kneeFlexion,
    'guide_hand_separation_cm': shot.guideHandSeparationCm,
    'release_time_ms': shot.releaseTimeMs,
    'follow_through_ms': shot.followThroughMs,
    'landing_drift_cm': shot.landingDriftCm,
    'balance_score': shot.balanceScore,
    'mechanics_score': shot.mechanicsScore,
    'corrected_by_user': shot.correctedByUser ? 1 : 0,
    'note': shot.note,
    'detail': encodeShotDetail(shot),
  };

  static Shot shotFromRow(Map<String, Object?> row) {
    final detail = jsonMap(row['detail']);

    return Shot(
      id: text(row['id']),
      index: integer(row['idx']),
      offsetFromStart: Duration(milliseconds: integer(row['offset_ms'])),
      result: enumByName(ShotResult.values, row['result'], ShotResult.uncertain),
      outcomeDetail: enumByName(
        ShotOutcomeDetail.values,
        row['outcome_detail'],
        ShotOutcomeDetail.undetermined,
      ),
      zone: enumByName(CourtZone.values, row['zone'], CourtZone.freeThrow),
      type: enumByName(ShotType.values, row['type'], ShotType.setShot),
      confidence: enumByName(
        ConfidenceLevel.values,
        row['confidence'],
        ConfidenceLevel.unavailable,
      ),
      releaseAngle: number(row['release_angle']),
      entryAngle: number(row['entry_angle']),
      apexHeightM: number(row['apex_height_m']),
      releaseHeightM: number(row['release_height_m']),
      ballSpeedMs: number(row['ball_speed_ms']),
      flightTimeMs: integer(row['flight_time_ms']),
      lateralDeviationCm: number(row['lateral_deviation_cm']),
      depthCm: number(row['depth_cm']),
      elbowAngle: number(row['elbow_angle']),
      kneeFlexion: number(row['knee_flexion']),
      guideHandSeparationCm: number(row['guide_hand_separation_cm']),
      releaseTimeMs: integer(row['release_time_ms']),
      followThroughMs: integer(row['follow_through_ms']),
      landingDriftCm: number(row['landing_drift_cm']),
      balanceScore: number(row['balance_score']),
      mechanicsScore: number(row['mechanics_score']),
      trajectory: [
        for (final point in jsonList(detail['trajectory']))
          if (point is List && point.length == 2)
            Offset(number(point[0]), number(point[1])),
      ],
      phases: [
        for (final phase in jsonList(detail['phases']))
          if (phase is Map)
            ShotPhase(
              name: text(phase['name']),
              startMs: integer(phase['startMs']),
              durationMs: integer(phase['durationMs']),
            ),
      ],
      correctedByUser: boolean(row['corrected_by_user']),
      note: row['note'] as String?,
    );
  }

  // --- Session ------------------------------------------------------------

  static Map<String, Object?> calibrationToJson(CalibrationRecord record) => {
    'angle': record.angle.name,
    'qualityScore': record.qualityScore,
    'courtProfile': record.courtProfile,
    'rimHeightM': record.rimHeightM,
    'lightingScore': record.lightingScore,
    'stabilityScore': record.stabilityScore,
    'framingScore': record.framingScore,
    'frameRate': record.frameRate,
    'notes': record.notes,
  };

  static CalibrationRecord calibrationFromJson(Map<String, Object?> json) {
    return CalibrationRecord(
      angle: enumByName(CameraAngle.values, json['angle'], CameraAngle.side),
      qualityScore: number(json['qualityScore']),
      courtProfile: text(json['courtProfile'], 'Unnamed court'),
      rimHeightM: number(json['rimHeightM'], 3.048),
      lightingScore: number(json['lightingScore']),
      stabilityScore: number(json['stabilityScore']),
      framingScore: number(json['framingScore']),
      frameRate: integer(json['frameRate'], 30),
      notes: [for (final note in jsonList(json['notes'])) text(note)],
    );
  }

  static Map<String, Object?> cueToJson(CoachingCue cue) => {
    'id': cue.id,
    'headline': cue.headline,
    'detail': cue.detail,
    'source': cue.source.name,
    'priority': cue.priority.name,
    'confidence': cue.confidence.name,
    'evidence': cue.evidence,
    'suggestedDrillId': cue.suggestedDrillId,
    'authorName': cue.authorName,
  };

  static CoachingCue cueFromJson(Map<String, Object?> json) {
    return CoachingCue(
      id: text(json['id']),
      headline: text(json['headline']),
      detail: text(json['detail']),
      source: enumByName(CueSource.values, json['source'], CueSource.measurement),
      priority: enumByName(
        CuePriority.values,
        json['priority'],
        CuePriority.supporting,
      ),
      confidence: enumByName(
        ConfidenceLevel.values,
        json['confidence'],
        ConfidenceLevel.medium,
      ),
      evidence: [for (final item in jsonList(json['evidence'])) text(item)],
      suggestedDrillId: json['suggestedDrillId'] as String?,
      authorName: json['authorName'] as String?,
    );
  }

  static Map<String, Object?> sessionToRow(TrainingSession session) {
    var makes = 0;
    var attempts = 0;
    for (final shot in session.shots) {
      if (!shot.result.countsAsAttempt) continue;
      attempts++;
      if (shot.isMake) makes++;
    }

    return {
      'id': session.id,
      'drill_id': session.drillId,
      'drill_name': session.drillName,
      'started_at': session.startedAt.millisecondsSinceEpoch,
      'duration_ms': session.duration.inMilliseconds,
      'model_version': session.modelVersion,
      'device_name': session.deviceName,
      'processed_on_device': session.processedOnDevice ? 1 : 0,
      'assignment_id': session.assignmentId,
      'coach_comment': session.coachComment,
      'calibration': jsonEncode(calibrationToJson(session.calibration)),
      'cues': jsonEncode([for (final cue in session.cues) cueToJson(cue)]),
      // Denormalised so the history list and the weekly totals do not have to
      // read every shot of every session to draw one number.
      'makes': makes,
      'attempts': attempts,
      'is_demo': session.isDemo ? 1 : 0,
      'is_simulated': session.isSimulated ? 1 : 0,
    };
  }

  static TrainingSession sessionFromRow(
    Map<String, Object?> row,
    List<Shot> shots,
  ) {
    return TrainingSession(
      id: text(row['id']),
      drillId: text(row['drill_id']),
      drillName: text(row['drill_name']),
      startedAt: DateTime.fromMillisecondsSinceEpoch(
        integer(row['started_at']),
      ),
      duration: Duration(milliseconds: integer(row['duration_ms'])),
      shots: shots,
      calibration: calibrationFromJson(jsonMap(row['calibration'])),
      cues: [
        for (final cue in jsonList(row['cues']))
          if (cue is Map) cueFromJson(cue.cast<String, Object?>()),
      ],
      modelVersion: text(row['model_version'], 'unknown'),
      deviceName: text(row['device_name'], 'This device'),
      processedOnDevice: boolean(row['processed_on_device'], true),
      assignmentId: row['assignment_id'] as String?,
      coachComment: row['coach_comment'] as String?,
      isDemo: boolean(row['is_demo']),
      isSimulated: boolean(row['is_simulated']),
    );
  }

  // --- Profile ------------------------------------------------------------

  static Map<String, Object?> profileToJson(PlayerProfile profile) => {
    'id': profile.id,
    'displayName': profile.displayName,
    'initials': profile.initials,
    'ageBand': profile.ageBand,
    'heightCm': profile.heightCm,
    'wingspanCm': profile.wingspanCm,
    'dominantHand': profile.dominantHand.name,
    'position': profile.position.name,
    'skillLevel': profile.skillLevel.name,
    'teamName': profile.teamName,
    'coachName': profile.coachName,
    'accentColor': profile.accentColor.toARGB32(),
    'goals': profile.goals,
    'weeklyAvailability': profile.weeklyAvailability,
    'isMinor': profile.isMinor,
    'guardianName': profile.guardianName,
    'guardianEmail': profile.guardianEmail,
  };

  static PlayerProfile profileFromJson(Map<String, Object?> json) {
    return PlayerProfile(
      id: text(json['id'], 'local-player'),
      displayName: text(json['displayName'], 'Player'),
      initials: text(json['initials'], 'P'),
      ageBand: text(json['ageBand'], '18 to 22'),
      heightCm: integer(json['heightCm'], 180),
      wingspanCm: integer(json['wingspanCm'], 180),
      dominantHand: enumByName(
        DominantHand.values,
        json['dominantHand'],
        DominantHand.right,
      ),
      position: enumByName(
        PlayerPosition.values,
        json['position'],
        PlayerPosition.shootingGuard,
      ),
      skillLevel: enumByName(
        SkillLevel.values,
        json['skillLevel'],
        SkillLevel.intermediate,
      ),
      teamName: text(json['teamName']),
      coachName: text(json['coachName']),
      accentColor: Color(integer(json['accentColor'], 0xFFE8863E)),
      goals: [for (final goal in jsonList(json['goals'])) text(goal)],
      weeklyAvailability: integer(json['weeklyAvailability'], 3),
      isMinor: boolean(json['isMinor']),
      guardianName: json['guardianName'] as String?,
      guardianEmail: json['guardianEmail'] as String?,
    );
  }

  // --- Goals --------------------------------------------------------------

  static Map<String, Object?> goalToJson(Goal goal) => {
    'id': goal.id,
    'kind': goal.kind.name,
    'title': goal.title,
    'detail': goal.detail,
    'current': goal.current,
    'target': goal.target,
    'unit': goal.unit,
    'dueAt': goal.dueAt.millisecondsSinceEpoch,
    'setBy': goal.setBy,
  };

  static Goal goalFromJson(Map<String, Object?> json) {
    return Goal(
      id: text(json['id']),
      kind: enumByName(GoalKind.values, json['kind'], GoalKind.percentage),
      title: text(json['title']),
      detail: text(json['detail']),
      current: number(json['current']),
      target: number(json['target']),
      unit: text(json['unit']),
      dueAt: DateTime.fromMillisecondsSinceEpoch(integer(json['dueAt'])),
      setBy: text(json['setBy'], 'You'),
    );
  }

  // --- Highlights ---------------------------------------------------------

  static Map<String, Object?> highlightToJson(Highlight highlight) => {
    'id': highlight.id,
    'title': highlight.title,
    'kind': highlight.kind.name,
    'createdAt': highlight.createdAt.millisecondsSinceEpoch,
    'shotCount': highlight.shotCount,
    'sessionId': highlight.sessionId,
    'visibility': highlight.visibility.name,
    'accent': highlight.accent.toARGB32(),
  };

  static Highlight highlightFromJson(Map<String, Object?> json) {
    return Highlight(
      id: text(json['id']),
      title: text(json['title']),
      kind: enumByName(
        HighlightKind.values,
        json['kind'],
        HighlightKind.sessionRecap,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        integer(json['createdAt']),
      ),
      // Rows written before highlights stopped pretending to be video still
      // carry clipCount, and it meant the same thing: how many shots.
      shotCount: integer(json['shotCount'] ?? json['clipCount']),
      sessionId: text(json['sessionId']),
      visibility: enumByName(
        HighlightVisibility.values,
        json['visibility'],
        HighlightVisibility.privateOnly,
      ),
      accent: Color(integer(json['accent'], 0xFFE8863E)),
    );
  }

  // --- Drills -------------------------------------------------------------

  static Map<String, Object?> drillToJson(Drill drill) => {
    'id': drill.id,
    'name': drill.name,
    'summary': drill.summary,
    'category': drill.category.name,
    'difficulty': drill.difficulty.name,
    'zones': [for (final zone in drill.zones) zone.name],
    'targetMakes': drill.targetMakes,
    'targetAttempts': drill.targetAttempts,
    'estimatedMinutes': drill.estimatedMinutes,
    'shotType': drill.shotType.name,
    'coachingFocus': drill.coachingFocus,
    'recommendedAngle': drill.recommendedAngle.name,
    'successThreshold': drill.successThreshold,
    'audioPrompts': drill.audioPrompts,
    'restSeconds': drill.restSeconds,
    'timeLimitSeconds': drill.timeLimitSeconds,
    'movementPattern': drill.movementPattern,
    'isCustom': drill.isCustom,
    'autoProgression': drill.autoProgression,
  };

  static Drill drillFromJson(Map<String, Object?> json) {
    return Drill(
      id: text(json['id']),
      name: text(json['name'], 'Untitled drill'),
      summary: text(json['summary']),
      category: enumByName(
        DrillCategory.values,
        json['category'],
        DrillCategory.fundamentals,
      ),
      difficulty: enumByName(
        DrillDifficulty.values,
        json['difficulty'],
        DrillDifficulty.developing,
      ),
      zones: [
        for (final zone in jsonList(json['zones']))
          enumByName(CourtZone.values, zone, CourtZone.freeThrow),
      ],
      targetMakes: integer(json['targetMakes'], 10),
      targetAttempts: integer(json['targetAttempts'], 10),
      estimatedMinutes: integer(json['estimatedMinutes'], 10),
      shotType: enumByName(ShotType.values, json['shotType'], ShotType.setShot),
      coachingFocus: text(json['coachingFocus']),
      recommendedAngle: enumByName(
        CameraAngle.values,
        json['recommendedAngle'],
        CameraAngle.side,
      ),
      successThreshold: number(json['successThreshold'], 0.7),
      audioPrompts: [
        for (final prompt in jsonList(json['audioPrompts'])) text(prompt),
      ],
      restSeconds: integer(json['restSeconds']),
      timeLimitSeconds: json['timeLimitSeconds'] is num
          ? integer(json['timeLimitSeconds'])
          : null,
      movementPattern: json['movementPattern'] as String?,
      isCustom: boolean(json['isCustom'], true),
      autoProgression: boolean(json['autoProgression'], true),
    );
  }

  // --- Notifications ------------------------------------------------------

  static Map<String, Object?> notificationToJson(AppNotification value) => {
    'id': value.id,
    'kind': value.kind.name,
    'title': value.title,
    'body': value.body,
    'createdAt': value.createdAt.millisecondsSinceEpoch,
    'read': value.read,
    'actionLabel': value.actionLabel,
    'actionRoute': value.actionRoute,
  };

  static AppNotification notificationFromJson(Map<String, Object?> json) {
    return AppNotification(
      id: text(json['id']),
      kind: enumByName(
        NotificationKind.values,
        json['kind'],
        NotificationKind.training,
      ),
      title: text(json['title']),
      body: text(json['body']),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        integer(json['createdAt']),
      ),
      read: boolean(json['read']),
      actionLabel: json['actionLabel'] as String?,
      actionRoute: json['actionRoute'] as String?,
    );
  }
}
