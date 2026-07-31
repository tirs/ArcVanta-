import '../../core/utils/formatters.dart';
import '../analytics/session_analytics.dart';
import '../models/drill.dart';
import '../models/profile.dart';
import '../models/program.dart';
import '../models/session.dart';
import '../models/shot.dart';

/// Builds the week's training plan from what the athlete has actually shot.
///
/// The plan is a recommendation, and a recommendation with no evidence behind
/// it is just a guess dressed up as coaching. So [build] returns null until
/// there is enough history to justify one, and the plan screen asks the user to
/// record a session instead of showing them a schedule the app invented.
abstract final class PlanBuilder {
  /// Enough attempts that the weakest zone means something.
  static const int minimumAttempts = 30;

  static TrainingPlan? build({
    required List<TrainingSession> sessions,
    required List<Drill> drills,
    required PlayerProfile profile,
    required DateTime now,
  }) {
    final totals = SessionAnalytics.totals(sessions);
    if (totals.attempts < minimumAttempts) return null;

    final zones = SessionAnalytics.zoneBreakdown(sessions);
    final weakest = _weakestZone(zones);
    if (weakest == null) return null;

    final weekStart = _startOfWeek(now);
    final sessionsPerWeek = profile.weeklyAvailability.clamp(2, 6);

    final focusDrills = _drillsForZone(drills, weakest);
    final generalDrills = [
      for (final drill in drills)
        if (!drill.isCustom) drill,
    ];
    if (focusDrills.isEmpty && generalDrills.isEmpty) return null;

    final days = <PlanDay>[];
    // Spread the training days across the week rather than stacking them, so
    // the plan does not ask for four consecutive shooting sessions.
    final spacing = (7 / sessionsPerWeek).floor().clamp(1, 3);

    for (var i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      final isTrainingDay = i % spacing == 0 && days.where(_isWork).length < sessionsPerWeek;

      if (!isTrainingDay) {
        days.add(
          PlanDay(
            date: date,
            kind: PlanDayKind.rest,
            title: 'Rest',
            focus: 'Recovery',
            drillIds: const [],
            estimatedMinutes: 0,
            completed: _trainedOn(sessions, date),
          ),
        );
        continue;
      }

      final workIndex = days.where(_isWork).length;
      final pool = workIndex.isEven && focusDrills.isNotEmpty
          ? focusDrills
          : generalDrills;
      final drill = pool[workIndex % pool.length];

      days.add(
        PlanDay(
          date: date,
          kind: PlanDayKind.session,
          title: drill.name,
          focus: workIndex.isEven
              ? weakest.label
              : drill.coachingFocus,
          drillIds: [drill.id],
          estimatedMinutes: drill.estimatedMinutes,
          completed: _trainedOn(sessions, date),
        ),
      );
    }

    final record = zones[weakest]!;

    return TrainingPlan(
      id: 'plan-${weekStart.millisecondsSinceEpoch}',
      name: 'Week of ${_monthDay(weekStart)}',
      rationale:
          'Your weakest area over ${totals.attempts} recorded attempts is '
          '${weakest.label.toLowerCase()}, at '
          '${record.percentage.toStringAsFixed(0)} percent on '
          '${Fmt.count(record.attempts, 'shot')}. This week puts most of your '
          'volume there.',
      weekStart: weekStart,
      days: days,
      authoredBy: 'ArcVanta, from your sessions',
      targetMetric: '${weakest.label} accuracy',
      targetValue: (record.percentage + 5).clamp(0, 100),
      currentValue: record.percentage,
    );
  }

  static bool _isWork(PlanDay day) => day.kind != PlanDayKind.rest;

  /// The zone with the worst percentage among those with a usable sample.
  static CourtZone? _weakestZone(Map<CourtZone, ZoneRecord> zones) {
    CourtZone? worst;
    var worstPercentage = double.infinity;

    for (final entry in zones.entries) {
      // One airball from the corner is not a weakness.
      if (entry.value.attempts < 8) continue;
      if (entry.value.percentage < worstPercentage) {
        worstPercentage = entry.value.percentage;
        worst = entry.key;
      }
    }
    return worst;
  }

  static List<Drill> _drillsForZone(List<Drill> drills, CourtZone zone) => [
    for (final drill in drills)
      if (drill.zones.contains(zone)) drill,
  ];

  static bool _trainedOn(List<TrainingSession> sessions, DateTime date) {
    for (final session in sessions) {
      if (session.startedAt.year == date.year &&
          session.startedAt.month == date.month &&
          session.startedAt.day == date.day) {
        return true;
      }
    }
    return false;
  }

  static DateTime _startOfWeek(DateTime now) {
    final day = DateTime(now.year, now.month, now.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  static String _monthDay(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}
