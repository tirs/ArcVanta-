import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/drill.dart';
import '../data/models/profile.dart';
import '../data/models/program.dart';
import '../data/models/session.dart';
import '../data/store/repository.dart';
import '../data/store/settings_codec.dart';
import 'app_settings.dart';
import 'stores.dart';

/// Everything read from disk before the first frame.
///
/// Loading up front rather than per screen is a deliberate trade. It costs a
/// few milliseconds of startup and it means no screen in the app has to render
/// a spinner over its own history, and no store has to be an `AsyncValue`. The
/// data is small: a season of sessions is well under a megabyte.
class AppSnapshot {
  const AppSnapshot({
    required this.sessions,
    required this.profile,
    required this.goals,
    required this.highlights,
    required this.notifications,
    required this.customDrills,
    required this.settings,
  });

  /// The state a device that has never run the app is in.
  static const AppSnapshot empty = AppSnapshot(
    sessions: [],
    profile: null,
    goals: [],
    highlights: [],
    notifications: [],
    customDrills: [],
    settings: AppSettings(),
  );

  final List<TrainingSession> sessions;
  final PlayerProfile? profile;
  final List<Goal> goals;
  final List<Highlight> highlights;
  final List<AppNotification> notifications;
  final List<Drill> customDrills;
  final AppSettings settings;

  static Future<AppSnapshot> load(ArcVantaRepository repository) async {
    final settingsJson = await repository.readDocument(DocumentKey.settings);
    final settings = settingsJson == null
        ? const AppSettings()
        : SettingsCodec.fromJson(settingsJson);

    return AppSnapshot(
      sessions: await repository.loadSessions(
        includeDemo: settings.demoDataEnabled,
      ),
      profile: await repository.loadProfile(),
      goals: await repository.loadGoals(),
      highlights: await repository.loadHighlights(),
      notifications: await repository.loadNotifications(),
      customDrills: await repository.loadCustomDrills(),
      settings: settings,
    );
  }
}

/// The open database. Overridden at startup; reading it before then is a bug.
final repositoryProvider = Provider<ArcVantaRepository>((ref) {
  throw StateError(
    'repositoryProvider was read before the database was opened. '
    'Override it in the root ProviderScope.',
  );
});

/// What was on disk at launch. Stores seed themselves from this once.
final appSnapshotProvider = Provider<AppSnapshot>((ref) => AppSnapshot.empty);

/// How much room the app's data takes, measured rather than estimated.
///
/// Watching the session list makes this recompute after a session is recorded
/// or deleted, which is when the number would otherwise go stale.
final storageBytesProvider = FutureProvider<int>((ref) {
  ref.watch(sessionStoreProvider);
  return ref.watch(repositoryProvider).storageBytes();
});
