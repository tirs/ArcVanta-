import 'package:flutter/material.dart';

import '../../core/theme/av_colors.dart';

enum AccountRole {
  player,
  guardian,
  trainer,
  coach,
  organizationAdmin;

  String get label => switch (this) {
    AccountRole.player => 'Player',
    AccountRole.guardian => 'Parent or guardian',
    AccountRole.trainer => 'Skills trainer',
    AccountRole.coach => 'Team coach',
    AccountRole.organizationAdmin => 'Academy or facility',
  };

  String get description => switch (this) {
    AccountRole.player => 'Track your own sessions, mechanics and progress.',
    AccountRole.guardian =>
      'Manage a minor account, approve access and review progress.',
    AccountRole.trainer =>
      'Work with multiple athletes, assign drills and review sessions.',
    AccountRole.coach =>
      'Build rosters, assign programs and follow team development.',
    AccountRole.organizationAdmin =>
      'Administer teams, coaches, branding and shared devices.',
  };

  IconData get icon => switch (this) {
    AccountRole.player => Icons.sports_basketball_rounded,
    AccountRole.guardian => Icons.family_restroom_rounded,
    AccountRole.trainer => Icons.fitness_center_rounded,
    AccountRole.coach => Icons.groups_rounded,
    AccountRole.organizationAdmin => Icons.apartment_rounded,
  };

  Color get color => switch (this) {
    AccountRole.player => AvColors.flare,
    AccountRole.guardian => AvColors.court,
    AccountRole.trainer => AvColors.insight,
    AccountRole.coach => AvColors.made,
    AccountRole.organizationAdmin => AvColors.caution,
  };

  /// Whether this role has a working workspace in this build.
  ///
  /// Everything past the player and guardian roles is a view onto other
  /// people's accounts, which needs a server. Offering them as equal choices
  /// and then landing the user on a wall of "not available" wastes their time,
  /// so the picker says so up front.
  bool get isAvailable =>
      this == AccountRole.player || this == AccountRole.guardian;
}

enum DominantHand {
  right,
  left;

  String get label => this == DominantHand.right ? 'Right' : 'Left';
}

enum PlayerPosition {
  pointGuard,
  shootingGuard,
  smallForward,
  powerForward,
  center;

  String get label => switch (this) {
    PlayerPosition.pointGuard => 'Point guard',
    PlayerPosition.shootingGuard => 'Shooting guard',
    PlayerPosition.smallForward => 'Small forward',
    PlayerPosition.powerForward => 'Power forward',
    PlayerPosition.center => 'Center',
  };

  String get abbreviation => switch (this) {
    PlayerPosition.pointGuard => 'PG',
    PlayerPosition.shootingGuard => 'SG',
    PlayerPosition.smallForward => 'SF',
    PlayerPosition.powerForward => 'PF',
    PlayerPosition.center => 'C',
  };
}

enum SkillLevel {
  beginner,
  intermediate,
  advanced,
  competitive;

  String get label => switch (this) {
    SkillLevel.beginner => 'Beginner',
    SkillLevel.intermediate => 'Intermediate',
    SkillLevel.advanced => 'Advanced',
    SkillLevel.competitive => 'Competitive',
  };
}

class PlayerProfile {
  const PlayerProfile({
    required this.id,
    required this.displayName,
    required this.initials,
    required this.ageBand,
    required this.heightCm,
    required this.wingspanCm,
    required this.dominantHand,
    required this.position,
    required this.skillLevel,
    required this.teamName,
    required this.coachName,
    required this.accentColor,
    required this.goals,
    required this.weeklyAvailability,
    this.isMinor = false,
    this.guardianName,
    this.guardianEmail,
  });

  final String id;
  final String displayName;
  final String initials;
  final String ageBand;
  final int heightCm;
  final int wingspanCm;
  final DominantHand dominantHand;
  final PlayerPosition position;
  final SkillLevel skillLevel;
  final String teamName;
  final String coachName;
  final Color accentColor;
  final List<String> goals;
  final int weeklyAvailability;
  final bool isMinor;
  final String? guardianName;

  /// Kept only so the record of who approved the account is complete. No mail
  /// is sent to it: there is no service in this build that could.
  final String? guardianEmail;

  /// Stands in for the moment between first launch and finishing setup.
  ///
  /// Every field is deliberately neutral. Nothing here should ever read as a
  /// measurement or an achievement, because it is not one.
  static const PlayerProfile placeholder = PlayerProfile(
    id: 'unset',
    displayName: 'Player',
    initials: 'P',
    ageBand: 'Not set',
    heightCm: 0,
    wingspanCm: 0,
    dominantHand: DominantHand.right,
    position: PlayerPosition.shootingGuard,
    skillLevel: SkillLevel.beginner,
    teamName: '',
    coachName: '',
    accentColor: AvColors.court,
    goals: [],
    weeklyAvailability: 0,
  );

  PlayerProfile copyWith({
    String? displayName,
    String? initials,
    String? ageBand,
    int? heightCm,
    int? wingspanCm,
    DominantHand? dominantHand,
    PlayerPosition? position,
    SkillLevel? skillLevel,
    String? teamName,
    String? coachName,
    Color? accentColor,
    List<String>? goals,
    int? weeklyAvailability,
    bool? isMinor,
    String? guardianName,
    String? guardianEmail,
  }) {
    return PlayerProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      initials: initials ?? this.initials,
      ageBand: ageBand ?? this.ageBand,
      heightCm: heightCm ?? this.heightCm,
      wingspanCm: wingspanCm ?? this.wingspanCm,
      dominantHand: dominantHand ?? this.dominantHand,
      position: position ?? this.position,
      skillLevel: skillLevel ?? this.skillLevel,
      teamName: teamName ?? this.teamName,
      coachName: coachName ?? this.coachName,
      accentColor: accentColor ?? this.accentColor,
      goals: goals ?? this.goals,
      weeklyAvailability: weeklyAvailability ?? this.weeklyAvailability,
      isMinor: isMinor ?? this.isMinor,
      guardianName: guardianName ?? this.guardianName,
      guardianEmail: guardianEmail ?? this.guardianEmail,
    );
  }

  /// Whether setup has produced a real profile rather than the placeholder.
  bool get isConfigured => id != placeholder.id;

  String get heightLabel {
    final totalInches = heightCm / 2.54;
    final feet = totalInches ~/ 12;
    final inches = (totalInches - feet * 12).round();
    return '$feet\u2032 $inches\u2033 \u00B7 $heightCm cm';
  }
}

/// A coach-managed athlete summary shown in the roster.
class AthleteSummary {
  const AthleteSummary({
    required this.id,
    required this.name,
    required this.initials,
    required this.ageBand,
    required this.position,
    required this.accentColor,
    required this.sessionsThisWeek,
    required this.percentage,
    required this.percentageDelta,
    required this.mechanicsScore,
    required this.pendingReviews,
    required this.lastSessionAt,
    required this.assignmentsComplete,
    required this.assignmentsTotal,
    required this.guardianApproved,
    required this.focusArea,
  });

  final String id;
  final String name;
  final String initials;
  final String ageBand;
  final PlayerPosition position;
  final Color accentColor;
  final int sessionsThisWeek;
  final double percentage;
  final double percentageDelta;
  final double mechanicsScore;
  final int pendingReviews;
  final DateTime lastSessionAt;
  final int assignmentsComplete;
  final int assignmentsTotal;
  final bool guardianApproved;
  final String focusArea;

  double get assignmentProgress =>
      assignmentsTotal == 0 ? 0 : assignmentsComplete / assignmentsTotal;
}
