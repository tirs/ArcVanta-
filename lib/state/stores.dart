import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/drill.dart';
import '../data/models/profile.dart';
import '../data/models/program.dart';
import '../data/models/progress.dart';
import '../data/models/session.dart';
import '../data/models/shot.dart';
import '../data/models/subscription.dart';
import '../data/seed/drill_catalog.dart';
import '../data/seed/seed_data.dart';

/// Session history with the correction path required by the scope: a user can
/// reclassify a result without stopping their work, and the change is recorded
/// as a correction rather than silently overwriting the model output.
class SessionStore extends Notifier<List<TrainingSession>> {
  @override
  List<TrainingSession> build() => SeedData.sessions;

  TrainingSession byId(String id) =>
      state.firstWhere((s) => s.id == id, orElse: () => state.first);

  void correctShotResult({
    required String sessionId,
    required String shotId,
    required ShotResult result,
    ShotOutcomeDetail? detail,
  }) {
    state = [
      for (final session in state)
        if (session.id != sessionId)
          session
        else
          TrainingSession(
            id: session.id,
            drillId: session.drillId,
            drillName: session.drillName,
            startedAt: session.startedAt,
            duration: session.duration,
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
            calibration: session.calibration,
            cues: session.cues,
            modelVersion: session.modelVersion,
            deviceName: session.deviceName,
            processedOnDevice: session.processedOnDevice,
            assignmentId: session.assignmentId,
            coachComment: session.coachComment,
          ),
    ];
  }

  void addSession(TrainingSession session) => state = [session, ...state];

  void setCoachComment(String sessionId, String comment) {
    state = [
      for (final session in state)
        if (session.id != sessionId)
          session
        else
          TrainingSession(
            id: session.id,
            drillId: session.drillId,
            drillName: session.drillName,
            startedAt: session.startedAt,
            duration: session.duration,
            shots: session.shots,
            calibration: session.calibration,
            cues: session.cues,
            modelVersion: session.modelVersion,
            deviceName: session.deviceName,
            processedOnDevice: session.processedOnDevice,
            assignmentId: session.assignmentId,
            coachComment: comment,
          ),
    ];
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

class DrillStore extends Notifier<List<Drill>> {
  @override
  List<Drill> build() => DrillCatalog.all;

  void addCustom(Drill drill) => state = [drill, ...state];

  Drill byId(String id) =>
      state.firstWhere((d) => d.id == id, orElse: () => state.first);
}

final drillStoreProvider = NotifierProvider<DrillStore, List<Drill>>(
  DrillStore.new,
);

final drillByIdProvider = Provider.family<Drill, String>((ref, id) {
  final drills = ref.watch(drillStoreProvider);
  return drills.firstWhere((d) => d.id == id, orElse: () => drills.first);
});

class NotificationStore extends Notifier<List<AppNotification>> {
  @override
  List<AppNotification> build() => SeedData.notifications;

  int get unreadCount => state.where((n) => !n.read).length;

  void markRead(String id) {
    state = [
      for (final n in state)
        if (n.id != id)
          n
        else
          AppNotification(
            id: n.id,
            kind: n.kind,
            title: n.title,
            body: n.body,
            createdAt: n.createdAt,
            read: true,
            actionLabel: n.actionLabel,
            actionRoute: n.actionRoute,
          ),
    ];
  }

  void markAllRead() {
    state = [
      for (final n in state)
        AppNotification(
          id: n.id,
          kind: n.kind,
          title: n.title,
          body: n.body,
          createdAt: n.createdAt,
          read: true,
          actionLabel: n.actionLabel,
          actionRoute: n.actionRoute,
        ),
    ];
  }
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
  List<Goal> build() => SeedData.goals;

  void add(Goal goal) => state = [...state, goal];

  void remove(String id) =>
      state = state.where((g) => g.id != id).toList(growable: false);
}

final goalStoreProvider = NotifierProvider<GoalStore, List<Goal>>(
  GoalStore.new,
);

class AssignmentStore extends Notifier<List<Assignment>> {
  @override
  List<Assignment> build() => SeedData.assignments;

  void add(Assignment assignment) => state = [assignment, ...state];

  void setStatus(String id, AssignmentStatus status) {
    state = [
      for (final a in state)
        if (a.id != id)
          a
        else
          Assignment(
            id: a.id,
            drillId: a.drillId,
            drillName: a.drillName,
            athleteId: a.athleteId,
            athleteName: a.athleteName,
            assignedBy: a.assignedBy,
            dueAt: a.dueAt,
            status: status,
            targetMakes: a.targetMakes,
            completedMakes: a.completedMakes,
            note: a.note,
          ),
    ];
  }

  List<Assignment> forAthlete(String athleteId) =>
      state.where((a) => a.athleteId == athleteId).toList(growable: false);
}

final assignmentStoreProvider =
    NotifierProvider<AssignmentStore, List<Assignment>>(AssignmentStore.new);

class HighlightStore extends Notifier<List<Highlight>> {
  @override
  List<Highlight> build() => SeedData.highlights;

  void add(Highlight highlight) => state = [highlight, ...state];

  void remove(String id) =>
      state = state.where((h) => h.id != id).toList(growable: false);

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
            duration: h.duration,
            clipCount: h.clipCount,
            sessionId: h.sessionId,
            visibility: visibility,
            accent: h.accent,
            metricsBurnedIn: h.metricsBurnedIn,
          ),
    ];
  }
}

final highlightStoreProvider =
    NotifierProvider<HighlightStore, List<Highlight>>(HighlightStore.new);

final playerProfileProvider = Provider<PlayerProfile>((ref) => SeedData.player);

final rosterProvider = Provider<List<AthleteSummary>>((ref) => SeedData.roster);

final athleteByIdProvider = Provider.family<AthleteSummary, String>((ref, id) {
  final roster = ref.watch(rosterProvider);
  return roster.firstWhere((a) => a.id == id, orElse: () => roster.first);
});

final trainingPlanProvider = Provider<TrainingPlan>((ref) => SeedData.plan);

final progressProvider = Provider.family<List<ProgressPoint>, TrendRange>(
  (ref, range) => SeedData.progressFor(range),
);

final personalRecordsProvider = Provider<List<PersonalRecord>>(
  (ref) => SeedData.records,
);

final trendExplanationsProvider = Provider<List<TrendExplanation>>(
  (ref) => SeedData.explanations,
);

final planOptionsProvider = Provider<List<PlanOption>>((ref) => SeedData.plans);

final entitlementProvider = Provider<Entitlement>(
  (ref) => SeedData.entitlement,
);
