import 'dart:convert';

import '../models/profile.dart';
import '../models/program.dart';
import '../models/session.dart';
import '../models/shot.dart';
import 'codecs.dart';

/// Builds a portable copy of everything the app holds about one athlete.
///
/// The format is the same JSON the codecs write to storage, wrapped with a
/// version and a timestamp. That is deliberate: an export the app can read
/// back is worth more than a prettier one it cannot, and it means the file
/// stays truthful for free as the models change.
abstract final class DataExport {
  static const int formatVersion = 1;

  static String build({
    required List<TrainingSession> sessions,
    required PlayerProfile? profile,
    required List<Goal> goals,
    required List<Highlight> highlights,
    required DateTime exportedAt,
  }) {
    // Demo sessions are the app's, not the athlete's, and shipping them inside
    // a personal export would misrepresent what they have actually shot.
    final owned = [
      for (final session in sessions)
        if (!session.isDemo) session,
    ];

    return const JsonEncoder.withIndent('  ').convert({
      'format': 'arcvanta-export',
      'version': formatVersion,
      'exportedAt': exportedAt.toIso8601String(),
      'profile': profile == null ? null : Codecs.profileToJson(profile),
      'goals': [for (final goal in goals) Codecs.goalToJson(goal)],
      'highlights': [
        for (final highlight in highlights) Codecs.highlightToJson(highlight),
      ],
      'sessions': [
        for (final session in owned)
          {
            ...Codecs.sessionToRow(session),
            'shots': [
              for (final shot in session.shots)
                Codecs.shotToRow(shot, session.id),
            ],
          },
      ],
    });
  }

  static String fileName(DateTime exportedAt) {
    final stamp = exportedAt.toIso8601String().split('T').first;
    return 'arcvanta-export-$stamp.json';
  }

  /// One session as a file, for sending a single piece of work to someone.
  ///
  /// Sections are opt-in because the shot-by-shot mechanics are the most
  /// revealing thing the app holds, and a coach asking for a make percentage
  /// should not receive a joint-angle record of a fifteen-year-old by default.
  static String session(
    TrainingSession session, {
    required bool includeMechanics,
    required bool includeShotLocations,
    required DateTime exportedAt,
  }) {
    final row = Map<String, Object?>.from(Codecs.sessionToRow(session));

    return const JsonEncoder.withIndent('  ').convert({
      'format': 'arcvanta-session',
      'version': formatVersion,
      'exportedAt': exportedAt.toIso8601String(),
      'session': row,
      if (includeMechanics || includeShotLocations)
        'shots': [
          for (final shot in session.shots)
            _shotView(
              shot,
              session.id,
              includeMechanics: includeMechanics,
              includeShotLocations: includeShotLocations,
            ),
        ],
    });
  }

  static Map<String, Object?> _shotView(
    Shot shot,
    String sessionId, {
    required bool includeMechanics,
    required bool includeShotLocations,
  }) {
    final row = Map<String, Object?>.from(Codecs.shotToRow(shot, sessionId));
    if (!includeMechanics) {
      for (final key in _mechanicsKeys) {
        row.remove(key);
      }
    }
    if (!includeShotLocations) {
      for (final key in _locationKeys) {
        row.remove(key);
      }
    }
    return row;
  }

  static const _mechanicsKeys = [
    'release_angle',
    'release_height_m',
    'release_time_ms',
    'knee_flexion',
    'elbow_angle',
    'guide_hand_separation_cm',
    'follow_through_ms',
    'landing_drift_cm',
    'balance_score',
    'mechanics_score',
    'detail',
  ];

  static const _locationKeys = [
    'zone',
    'lateral_deviation_cm',
    'depth_cm',
  ];

  static String sessionFileName(TrainingSession session) {
    final stamp = session.startedAt.toIso8601String().split('T').first;
    final slug = session.drillName
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp('^-|-\$'), '');
    return 'arcvanta-$slug-$stamp.json';
  }
}
