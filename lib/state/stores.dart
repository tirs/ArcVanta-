import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/analytics/session_analytics.dart';
import '../data/models/drill.dart';
import '../data/models/profile.dart';
import '../data/models/program.dart';
import '../data/models/progress.dart';
import '../data/models/session.dart';
import '../data/models/shot.dart';
import '../data/plan/plan_builder.dart';
import '../data/seed/drill_catalog.dart';
import '../data/store/repository.dart';
import 'bootstrap.dart';

/// Session history, loaded from disk at launch and written through on change.
///
/// Writes are fire-and-forget against the in-memory state deliberately: the
/// user should never wait on a disk flush to see a correction they just made,
/// and a failed write is recoverable on the next one. What is not acceptable
/// is losing a session, so [addSession] awaits its insert before the summary
/// screen can navigate away from it.
class SessionStore extends Notifier<List<TrainingSession>> {
  @override
  List<TrainingSession> build() => ref.watch(appSnapshotProvider).sessions;

  ArcVantaRepository get _repository => ref.read(repositoryProvider);

  TrainingSession? byId(String id) {
    for (final session in state) {
      if (session.id == id) return session;
    }
    return null;
  }

  Future<void> addSession(TrainingSession session) async {
    state = [session, ...state];
    await _repository.saveSession(session);
  }

  void correctShotResult({
    required String sessionId,
    required String shotId,
    required ShotResult result,
    ShotOutcomeDetail? detail,
  }) {
    _replace(sessionId, (session) {
      return session.copyWith(
        shots: [
          for (final shot in session.shots)
            if (shot.id != shotId)
              shot
            else
              shot.copyWith(
                result: result,
                outcomeDetail: detail ?? shot.outcomeDetail,
                correctedByUser: true,
              ),
        ],
      );
    });
  }

  void setCoachComment(String sessionId, String comment) {
    _replace(sessionId, (session) => session.copyWith(coachComment: comment));
  }

  Future<void> deleteSession(String id) async {
    state = [
      for (final session in state)
        if (session.id != id) session,
    ];
    await _repository.deleteSession(id);
  }

  /// Re-reads history from disk after something changed it out of band.
  Future<void> reload({required bool includeDemo}) async {
    state = await _repository.loadSessions(includeDemo: includeDemo);
  }

  void clear() => state = const [];

  void _replace(
    String id,
    TrainingSession Function(TrainingSession) transform,
  ) {
    final next = <TrainingSession>[];
    TrainingSession? updated;
    for (final session in state) {
      if (session.id != id) {
        next.add(session);
        continue;
      }
      updated = transform(session);
      next.add(updated);
    }
    state = next;
    if (updated != null) _repository.saveSession(updated);
  }
}

final sessionStoreProvider =
    NotifierProvider<SessionStore, List<TrainingSession>>(SessionStore.new);

final sessionByIdProvider = Provider.family<TrainingSession?, String>((
  ref,
  id,
) {
  final sessions = ref.watch(sessionStoreProvider);
  for (final session in sessions) {
    if (session.id == id) return session;
  }
  return null;
});

/// Whether the athlete has recorded anything of their own.
///
/// Distinct from `sessions.isNotEmpty` on purpose: with the demo switched on
/// the list is full of sessions nobody shot, and the app must not congratulate
/// the user on them or claim they have a history to compare against.
/// Whether the athlete has recorded anything of their own.
///
/// Statistics are computed over whatever is loaded, which includes the sample
/// history when the user has switched it on. This flag is what lets the app
/// say so: it drives the banner that marks the numbers as sample data, and it
/// is what the delete-my-data control checks before warning.
final hasRecordedHistoryProvider = Provider<bool>((ref) {
  return ref.watch(sessionStoreProvider).any((session) => session.isMeasured);
});

/// True when what is on screen is partly or wholly fabricated.
///
/// Sample sessions are counted here, not filtered out of the statistics: the
/// point of switching them on is to see a populated app, and the banner this
/// drives is what keeps that honest. Simulated sessions take the opposite
/// route — see [analysedSessionsProvider].
final showingSampleDataProvider = Provider<bool>((ref) {
  return ref.watch(sessionStoreProvider).any((session) => session.isDemo);
});

/// History with the simulated sessions taken out.
///
/// Every record, trend, total and plan reads from here rather than from the
/// raw store. A session run with no models is kept so the athlete can see
/// they ran it, but its invented numbers are not allowed to average with
/// anything or to stand as a personal best.
final analysedSessionsProvider = Provider<List<TrainingSession>>((ref) {
  final all = ref.watch(sessionStoreProvider);
  if (!all.any((session) => session.isSimulated)) return all;
  return [
    for (final session in all)
      if (!session.isSimulated) session,
  ];
});

/// The built-in drill library plus anything the user has built.
class DrillStore extends Notifier<List<Drill>> {
  @override
  List<Drill> build() {
    final custom = ref.watch(appSnapshotProvider).customDrills;
    return [...custom, ...DrillCatalog.all];
  }

  Future<void> addCustom(Drill drill) async {
    state = [drill, ...state];
    await _persistCustom();
  }

  Future<void> removeCustom(String id) async {
    state = [
      for (final drill in state)
        if (drill.id != id) drill,
    ];
    await _persistCustom();
  }

  Drill? byId(String id) {
    for (final drill in state) {
      if (drill.id == id) return drill;
    }
    return null;
  }

  Future<void> _persistCustom() {
    return ref.read(repositoryProvider).saveCustomDrills([
      for (final drill in state)
        if (drill.isCustom) drill,
    ]);
  }
}

final drillStoreProvider = NotifierProvider<DrillStore, List<Drill>>(
  DrillStore.new,
);

/// Falls back to the first catalogue drill so a stale route cannot crash the
/// app; the catalogue is compiled in and therefore never empty.
final drillByIdProvider = Provider.family<Drill, String>((ref, id) {
  final drills = ref.watch(drillStoreProvider);
  return drills.firstWhere((d) => d.id == id, orElse: () => drills.first);
});

class NotificationStore extends Notifier<List<AppNotification>> {
  @override
  List<AppNotification> build() => ref.watch(appSnapshotProvider).notifications;

  int get unreadCount => state.where((n) => !n.read).length;

  void markRead(String id) {
    state = [
      for (final n in state)
        if (n.id != id) n else _read(n),
    ];
    _persist();
  }

  void markAllRead() {
    state = [for (final n in state) _read(n)];
    _persist();
  }

  Future<void> add(AppNotification notification) {
    state = [notification, ...state];
    return _persist();
  }

  void clear() {
    state = const [];
    _persist();
  }

  static AppNotification _read(AppNotification n) => AppNotification(
    id: n.id,
    kind: n.kind,
    title: n.title,
    body: n.body,
    createdAt: n.createdAt,
    read: true,
    actionLabel: n.actionLabel,
    actionRoute: n.actionRoute,
  );

  Future<void> _persist() =>
      ref.read(repositoryProvider).saveNotifications(state);
}

final notificationStoreProvider =
    NotifierProvider<NotificationStore, List<AppNotification>>(
      NotificationStore.new,
    );

final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationStoreProvider).where((n) => !n.read).length;
});

class GoalStore extends Notifier<List<Goal>> {
  @override
  List<Goal> build() => ref.watch(appSnapshotProvider).goals;

  void add(Goal goal) {
    state = [...state, goal];
    _persist();
  }

  void remove(String id) {
    state = [
      for (final goal in state)
        if (goal.id != id) goal,
    ];
    _persist();
  }

  Future<void> update(Goal goal) {
    state = [
      for (final existing in state)
        if (existing.id == goal.id) goal else existing,
    ];
    return _persist();
  }

  void clear() {
    state = const [];
    _persist();
  }

  Future<void> _persist() => ref.read(repositoryProvider).saveGoals(state);
}

final goalStoreProvider = NotifierProvider<GoalStore, List<Goal>>(
  GoalStore.new,
);

class HighlightStore extends Notifier<List<Highlight>> {
  @override
  List<Highlight> build() => ref.watch(appSnapshotProvider).highlights;

  void add(Highlight highlight) {
    state = [highlight, ...state];
    _persist();
  }

  void remove(String id) {
    state = [
      for (final h in state)
        if (h.id != id) h,
    ];
    _persist();
  }

  void clear() {
    state = const [];
    _persist();
  }

  void setVisibility(String id, HighlightVisibility visibility) {
    state = [
      for (final h in state)
        if (h.id != id)
          h
        else
          Highlight(
            id: h.id,
            title: h.title,
            kind: h.kind,
            createdAt: h.createdAt,
            shotCount: h.shotCount,
            sessionId: h.sessionId,
            visibility: visibility,
            accent: h.accent,
          ),
    ];
    _persist();
  }

  void _persist() => ref.read(repositoryProvider).saveHighlights(state);
}

final highlightStoreProvider =
    NotifierProvider<HighlightStore, List<Highlight>>(HighlightStore.new);

/// The signed-in athlete, or null until profile setup finishes.
class ProfileStore extends Notifier<PlayerProfile?> {
  @override
  PlayerProfile? build() => ref.watch(appSnapshotProvider).profile;

  Future<void> save(PlayerProfile profile) async {
    state = profile;
    await ref.read(repositoryProvider).saveProfile(profile);
  }

  void clear() => state = null;
}

final profileStoreProvider =
    NotifierProvider<ProfileStore, PlayerProfile?>(ProfileStore.new);

/// The profile, or a neutral placeholder for the brief window before setup.
///
/// Screens that only need a name and an accent use this; anything that would
/// present placeholder values as the user's own data watches
/// [profileStoreProvider] and handles null.
final playerProfileProvider = Provider<PlayerProfile>((ref) {
  return ref.watch(profileStoreProvider) ?? PlayerProfile.placeholder;
});

// --- Derived analytics ----------------------------------------------------
//
// Everything below is computed from recorded sessions. None of it is stored,
// so it cannot drift out of step with the shots it describes.

final progressProvider = Provider.family<List<ProgressPoint>, TrendRange>((
  ref,
  range,
) {
  return SessionAnalytics.progressPoints(
    ref.watch(analysedSessionsProvider),
    range,
    now: DateTime.now(),
  );
});

final personalRecordsProvider = Provider<List<PersonalRecord>>((ref) {
  return SessionAnalytics.personalRecords(ref.watch(analysedSessionsProvider));
});

final trendExplanationsProvider = Provider<List<TrendExplanation>>((ref) {
  return SessionAnalytics.explainTrends(
    ref.watch(analysedSessionsProvider),
    now: DateTime.now(),
  );
});

final zoneBreakdownProvider = Provider<Map<CourtZone, ZoneRecord>>((ref) {
  return SessionAnalytics.zoneBreakdown(ref.watch(analysedSessionsProvider));
});

/// Totals for the rolling seven days, used by the home header.
final weeklyTotalsProvider = Provider<SessionTotals>((ref) {
  return SessionAnalytics.totals(
    ref.watch(analysedSessionsProvider),
    since: DateTime.now().subtract(const Duration(days: 7)),
  );
});

final lifetimeTotalsProvider = Provider<SessionTotals>((ref) {
  return SessionAnalytics.totals(ref.watch(analysedSessionsProvider));
});

/// This week's plan, or null when there is not enough history to build one.
final trainingPlanProvider = Provider<TrainingPlan?>((ref) {
  return PlanBuilder.build(
    sessions: ref.watch(analysedSessionsProvider),
    drills: ref.watch(drillStoreProvider),
    profile: ref.watch(playerProfileProvider),
    now: DateTime.now(),
  );
});
