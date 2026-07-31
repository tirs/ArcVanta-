import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/profile.dart';
import '../data/models/program.dart';

/// Coach, roster and assignment state.
///
/// Every one of these features is inherently multi-user: a roster is other
/// people's accounts, an assignment is a message from one device to another,
/// and a review queue is work handed between two humans. None of that can
/// exist without a server, and this build does not have one.
///
/// Rather than populate the screens with invented athletes — which is what
/// they used to do — the providers return nothing and
/// [TeamFeatures.isAvailable] is false. The screens read that flag and explain
/// the situation instead of pretending.
abstract final class TeamFeatures {
  static const bool isAvailable = false;

  static const String unavailableHeadline = 'Team features need an account';

  static const String unavailableBody =
      'Rosters, assignments and session review move data between a coach and '
      'their athletes, which needs a server this build does not include. '
      'Everything that measures your own shooting works fully offline.';
}

/// The coach's athletes. Empty until there is a backend to hold them.
final rosterProvider = Provider<List<AthleteSummary>>((ref) => const []);

final athleteByIdProvider = Provider.family<AthleteSummary?, String>((ref, id) {
  for (final athlete in ref.watch(rosterProvider)) {
    if (athlete.id == id) return athlete;
  }
  return null;
});

/// Drill assignments. Local-only assignment would be a note to yourself, so
/// this stays empty rather than half-implemented.
class AssignmentStore extends Notifier<List<Assignment>> {
  @override
  List<Assignment> build() => const [];

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

  List<Assignment> forAthlete(String athleteId) => [
    for (final a in state)
      if (a.athleteId == athleteId) a,
  ];
}

final assignmentStoreProvider =
    NotifierProvider<AssignmentStore, List<Assignment>>(AssignmentStore.new);
