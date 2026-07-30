import 'package:flutter/material.dart';

import '../../core/theme/av_colors.dart';
import 'confidence.dart';
import 'shot.dart';

enum DrillCategory {
  fundamentals,
  accuracy,
  range,
  movement,
  pressure,
  conditioning;

  String get label => switch (this) {
    DrillCategory.fundamentals => 'Fundamentals',
    DrillCategory.accuracy => 'Accuracy',
    DrillCategory.range => 'Range',
    DrillCategory.movement => 'Movement',
    DrillCategory.pressure => 'Pressure',
    DrillCategory.conditioning => 'Conditioning',
  };

  Color get color => switch (this) {
    DrillCategory.fundamentals => AvColors.court,
    DrillCategory.accuracy => AvColors.made,
    DrillCategory.range => AvColors.insight,
    DrillCategory.movement => AvColors.flare,
    DrillCategory.pressure => AvColors.caution,
    DrillCategory.conditioning => AvColors.miss,
  };

  IconData get icon => switch (this) {
    DrillCategory.fundamentals => Icons.architecture_rounded,
    DrillCategory.accuracy => Icons.center_focus_strong_rounded,
    DrillCategory.range => Icons.open_in_full_rounded,
    DrillCategory.movement => Icons.directions_run_rounded,
    DrillCategory.pressure => Icons.bolt_rounded,
    DrillCategory.conditioning => Icons.favorite_rounded,
  };
}

enum DrillDifficulty {
  foundation,
  developing,
  advanced,
  elite;

  String get label => switch (this) {
    DrillDifficulty.foundation => 'Foundation',
    DrillDifficulty.developing => 'Developing',
    DrillDifficulty.advanced => 'Advanced',
    DrillDifficulty.elite => 'Elite',
  };

  int get level => index + 1;
}

class Drill {
  const Drill({
    required this.id,
    required this.name,
    required this.summary,
    required this.category,
    required this.difficulty,
    required this.zones,
    required this.targetMakes,
    required this.targetAttempts,
    required this.estimatedMinutes,
    required this.shotType,
    required this.coachingFocus,
    required this.recommendedAngle,
    required this.successThreshold,
    required this.audioPrompts,
    this.restSeconds = 0,
    this.timeLimitSeconds,
    this.movementPattern,
    this.isCustom = false,
    this.autoProgression = true,
  });

  final String id;
  final String name;
  final String summary;
  final DrillCategory category;
  final DrillDifficulty difficulty;
  final List<CourtZone> zones;
  final int targetMakes;
  final int targetAttempts;
  final int estimatedMinutes;
  final ShotType shotType;
  final String coachingFocus;
  final CameraAngle recommendedAngle;

  /// Percentage the athlete must reach for the drill to count as passed.
  final double successThreshold;
  final List<String> audioPrompts;
  final int restSeconds;
  final int? timeLimitSeconds;
  final String? movementPattern;
  final bool isCustom;
  final bool autoProgression;

  Drill copyWith({
    String? id,
    String? name,
    String? summary,
    DrillCategory? category,
    DrillDifficulty? difficulty,
    List<CourtZone>? zones,
    int? targetMakes,
    int? targetAttempts,
    int? estimatedMinutes,
    ShotType? shotType,
    String? coachingFocus,
    CameraAngle? recommendedAngle,
    double? successThreshold,
    List<String>? audioPrompts,
    int? restSeconds,
    int? timeLimitSeconds,
    String? movementPattern,
    bool? isCustom,
    bool? autoProgression,
  }) {
    return Drill(
      id: id ?? this.id,
      name: name ?? this.name,
      summary: summary ?? this.summary,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      zones: zones ?? this.zones,
      targetMakes: targetMakes ?? this.targetMakes,
      targetAttempts: targetAttempts ?? this.targetAttempts,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      shotType: shotType ?? this.shotType,
      coachingFocus: coachingFocus ?? this.coachingFocus,
      recommendedAngle: recommendedAngle ?? this.recommendedAngle,
      successThreshold: successThreshold ?? this.successThreshold,
      audioPrompts: audioPrompts ?? this.audioPrompts,
      restSeconds: restSeconds ?? this.restSeconds,
      timeLimitSeconds: timeLimitSeconds ?? this.timeLimitSeconds,
      movementPattern: movementPattern ?? this.movementPattern,
      isCustom: isCustom ?? this.isCustom,
      autoProgression: autoProgression ?? this.autoProgression,
    );
  }
}
