import 'package:flutter/material.dart';

import '../../core/theme/av_colors.dart';

enum AssignmentStatus {
  assigned,
  inProgress,
  submitted,
  reviewed,
  overdue;

  String get label => switch (this) {
    AssignmentStatus.assigned => 'Assigned',
    AssignmentStatus.inProgress => 'In progress',
    AssignmentStatus.submitted => 'Awaiting review',
    AssignmentStatus.reviewed => 'Reviewed',
    AssignmentStatus.overdue => 'Overdue',
  };

  Color get color => switch (this) {
    AssignmentStatus.assigned => AvColors.court,
    AssignmentStatus.inProgress => AvColors.insight,
    AssignmentStatus.submitted => AvColors.caution,
    AssignmentStatus.reviewed => AvColors.made,
    AssignmentStatus.overdue => AvColors.miss,
  };
}

class Assignment {
  const Assignment({
    required this.id,
    required this.drillId,
    required this.drillName,
    required this.athleteId,
    required this.athleteName,
    required this.assignedBy,
    required this.dueAt,
    required this.status,
    required this.targetMakes,
    required this.completedMakes,
    required this.note,
  });

  final String id;
  final String drillId;
  final String drillName;
  final String athleteId;
  final String athleteName;
  final String assignedBy;
  final DateTime dueAt;
  final AssignmentStatus status;
  final int targetMakes;
  final int completedMakes;
  final String note;

  double get progress =>
      targetMakes == 0 ? 0 : (completedMakes / targetMakes).clamp(0, 1);
}

enum PlanDayKind {
  session,
  recovery,
  rest;

  String get label => switch (this) {
    PlanDayKind.session => 'Training',
    PlanDayKind.recovery => 'Light recovery',
    PlanDayKind.rest => 'Rest',
  };
}

class PlanDay {
  const PlanDay({
    required this.date,
    required this.kind,
    required this.title,
    required this.focus,
    required this.drillIds,
    required this.estimatedMinutes,
    required this.completed,
  });

  final DateTime date;
  final PlanDayKind kind;
  final String title;
  final String focus;
  final List<String> drillIds;
  final int estimatedMinutes;
  final bool completed;
}

class TrainingPlan {
  const TrainingPlan({
    required this.id,
    required this.name,
    required this.rationale,
    required this.weekStart,
    required this.days,
    required this.authoredBy,
    required this.targetMetric,
    required this.targetValue,
    required this.currentValue,
  });

  final String id;
  final String name;
  final String rationale;
  final DateTime weekStart;
  final List<PlanDay> days;
  final String authoredBy;
  final String targetMetric;
  final double targetValue;
  final double currentValue;

  int get completedDays => days.where((d) => d.completed).length;
  int get sessionDays =>
      days.where((d) => d.kind == PlanDayKind.session).length;
  double get progress =>
      sessionDays == 0 ? 0 : completedDays / sessionDays.toDouble();
}

enum GoalKind {
  percentage,
  volume,
  mechanics,
  consistency,
  streak;

  String get label => switch (this) {
    GoalKind.percentage => 'Accuracy',
    GoalKind.volume => 'Volume',
    GoalKind.mechanics => 'Mechanics',
    GoalKind.consistency => 'Consistency',
    GoalKind.streak => 'Streak',
  };

  IconData get icon => switch (this) {
    GoalKind.percentage => Icons.percent_rounded,
    GoalKind.volume => Icons.equalizer_rounded,
    GoalKind.mechanics => Icons.accessibility_new_rounded,
    GoalKind.consistency => Icons.show_chart_rounded,
    GoalKind.streak => Icons.local_fire_department_rounded,
  };

  Color get color => switch (this) {
    GoalKind.percentage => AvColors.made,
    GoalKind.volume => AvColors.court,
    GoalKind.mechanics => AvColors.insight,
    GoalKind.consistency => AvColors.flare,
    GoalKind.streak => AvColors.caution,
  };
}

class Goal {
  const Goal({
    required this.id,
    required this.kind,
    required this.title,
    required this.detail,
    required this.current,
    required this.target,
    required this.unit,
    required this.dueAt,
    required this.setBy,
  });

  final String id;
  final GoalKind kind;
  final String title;
  final String detail;
  final double current;
  final double target;
  final String unit;
  final DateTime dueAt;
  final String setBy;

  double get progress => target == 0 ? 0 : (current / target).clamp(0, 1);
  bool get achieved => current >= target;
}

enum HighlightKind {
  bestMakes,
  progressComparison,
  coachReview,
  sessionRecap;

  String get label => switch (this) {
    HighlightKind.bestMakes => 'Best makes',
    HighlightKind.progressComparison => 'Progress comparison',
    HighlightKind.coachReview => 'Coach review reel',
    HighlightKind.sessionRecap => 'Session recap',
  };

  IconData get icon => switch (this) {
    HighlightKind.bestMakes => Icons.auto_awesome_motion_rounded,
    HighlightKind.progressComparison => Icons.compare_arrows_rounded,
    HighlightKind.coachReview => Icons.rate_review_rounded,
    HighlightKind.sessionRecap => Icons.movie_creation_rounded,
  };
}

enum HighlightVisibility {
  privateOnly,
  coachAndGuardian,
  team;

  String get label => switch (this) {
    HighlightVisibility.privateOnly => 'Private',
    HighlightVisibility.coachAndGuardian => 'Coach and guardian',
    HighlightVisibility.team => 'Team',
  };

  IconData get icon => switch (this) {
    HighlightVisibility.privateOnly => Icons.lock_rounded,
    HighlightVisibility.coachAndGuardian => Icons.shield_rounded,
    HighlightVisibility.team => Icons.groups_2_rounded,
  };
}

/// A moment worth coming back to.
///
/// A bookmark into a stored session, not a video. No frames are written to
/// disk anywhere in this build, so a highlight is the shots it points at and
/// the measurements already held against them.
class Highlight {
  const Highlight({
    required this.id,
    required this.title,
    required this.kind,
    required this.createdAt,
    required this.shotCount,
    required this.sessionId,
    required this.visibility,
    required this.accent,
  });

  final String id;
  final String title;
  final HighlightKind kind;
  final DateTime createdAt;

  /// How many shots the moment covers.
  final int shotCount;

  final String sessionId;
  final HighlightVisibility visibility;
  final Color accent;
}

enum NotificationKind {
  training,
  assignment,
  progress,
  analysis,
  account,
  safety;

  String get label => switch (this) {
    NotificationKind.training => 'Training reminder',
    NotificationKind.assignment => 'Coach assignment',
    NotificationKind.progress => 'Goal and streak',
    NotificationKind.analysis => 'Session measured',
    NotificationKind.account => 'Account and billing',
    NotificationKind.safety => 'Guardian and safety',
  };

  IconData get icon => switch (this) {
    NotificationKind.training => Icons.alarm_rounded,
    NotificationKind.assignment => Icons.assignment_rounded,
    NotificationKind.progress => Icons.trending_up_rounded,
    NotificationKind.analysis => Icons.insights_rounded,
    NotificationKind.account => Icons.credit_card_rounded,
    NotificationKind.safety => Icons.shield_moon_rounded,
  };

  Color get color => switch (this) {
    NotificationKind.training => AvColors.flare,
    NotificationKind.assignment => AvColors.insight,
    NotificationKind.progress => AvColors.made,
    NotificationKind.analysis => AvColors.court,
    NotificationKind.account => AvColors.caution,
    NotificationKind.safety => AvColors.miss,
  };
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.read,
    this.actionLabel,
    this.actionRoute,
  });

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;
  final String? actionLabel;
  final String? actionRoute;
}
