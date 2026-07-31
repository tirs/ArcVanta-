import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/router/app_router.dart';
import '../core/utils/formatters.dart';
import '../data/analytics/session_analytics.dart';
import '../data/models/program.dart';
import '../data/models/progress.dart';
import '../data/models/session.dart';
import 'stores.dart';

/// Turns a finished session into the notifications and goal movement it earned.
///
/// The notification centre used to be a display case for messages nobody sent.
/// Everything here is derived from a session the athlete actually recorded:
/// a record only appears if the new session beat the previous best, and a goal
/// only advances by what was measured.
class SessionEvents {
  const SessionEvents(this._ref);

  final Ref _ref;

  /// Call once, after [SessionStore.addSession] has committed the session.
  ///
  /// Reads history *including* the new session, which is why it runs after the
  /// insert rather than alongside it. Awaits its own writes so a notification
  /// about a session cannot outlive the session it describes.
  Future<void> recordCompleted(TrainingSession session) async {
    if (!session.isMeasured) return;

    final history = _ref.read(sessionStoreProvider);
    final earlier = [
      for (final other in history)
        if (other.id != session.id && other.isMeasured) other,
    ];

    final notifications = _ref.read(notificationStoreProvider.notifier);

    await notifications.add(
      AppNotification(
        id: 'session-${session.id}',
        kind: NotificationKind.analysis,
        title: '${session.drillName} measured',
        body:
            '${session.makeCount} of ${session.attemptCount} on '
            '${Fmt.date(session.startedAt)}. '
            '${Fmt.percent(session.percentage, decimals: 0)} from the floor.',
        createdAt: session.endedAt,
        read: false,
        actionLabel: 'Open summary',
        actionRoute: AppRoute.session(session.id),
      ),
    );

    for (final record in _recordsBrokenBy(session, earlier)) {
      await notifications.add(
        AppNotification(
          id: 'record-${session.id}-${record.label}',
          kind: NotificationKind.progress,
          title: 'New best: ${record.label.toLowerCase()}',
          body: '${record.value}${record.unit} \u2014 ${record.context}',
          createdAt: session.endedAt,
          read: false,
          actionLabel: 'See progress',
          actionRoute: AppRoute.progress,
        ),
      );
    }

    await _advanceGoals(session, notifications);
  }

  /// Records this session took off a previous holder.
  ///
  /// A category with no prior value is a first, not a personal best, and is
  /// deliberately silent — otherwise session one arrives with a stack of
  /// congratulations for beating nobody. Comparing whole record sets keeps the
  /// rule in one place: whatever [SessionAnalytics] counts as a record is what
  /// gets celebrated.
  List<PersonalRecord> _recordsBrokenBy(
    TrainingSession session,
    List<TrainingSession> earlier,
  ) {
    final before = {
      for (final record in SessionAnalytics.personalRecords(earlier))
        record.label: record.value,
    };

    return [
      for (final record in SessionAnalytics.personalRecords([
        session,
        ...earlier,
      ]))
        if (record.achievedAt == session.startedAt &&
            before[record.label] != null &&
            before[record.label] != record.value)
          record,
    ];
  }

  Future<void> _advanceGoals(
    TrainingSession session,
    NotificationStore notifications,
  ) async {
    final goals = _ref.read(goalStoreProvider);
    if (goals.isEmpty) return;

    final store = _ref.read(goalStoreProvider.notifier);
    for (final goal in goals) {
      final contribution = _contribution(goal, session);
      if (contribution == 0) continue;

      final wasAchieved = goal.achieved;
      final updated = Goal(
        id: goal.id,
        kind: goal.kind,
        title: goal.title,
        detail: goal.detail,
        current: goal.kind == GoalKind.volume
            ? goal.current + contribution
            : contribution,
        target: goal.target,
        unit: goal.unit,
        dueAt: goal.dueAt,
        setBy: goal.setBy,
      );
      await store.update(updated);

      if (!wasAchieved && updated.achieved) {
        await notifications.add(
          AppNotification(
            id: 'goal-${goal.id}-${session.id}',
            kind: NotificationKind.progress,
            title: 'Goal reached: ${goal.title}',
            body:
                '${updated.current.toStringAsFixed(0)}${goal.unit} against a '
                'target of ${goal.target.toStringAsFixed(0)}${goal.unit}.',
            createdAt: session.endedAt,
            read: false,
            actionLabel: 'See goals',
            actionRoute: AppRoute.goals,
          ),
        );
      }
    }
  }

  /// What this session contributes to a goal.
  ///
  /// Volume goals accumulate; the rest are a current reading rather than a
  /// running total, so they take the session's own value.
  double _contribution(Goal goal, TrainingSession session) =>
      switch (goal.kind) {
        GoalKind.volume => session.attemptCount.toDouble(),
        GoalKind.percentage => session.percentage,
        GoalKind.mechanics => session.averageMechanics,
        GoalKind.consistency => session.consistencyScore,
        GoalKind.streak => session.bestStreak.toDouble(),
      };
}

final sessionEventsProvider = Provider<SessionEvents>(SessionEvents.new);
