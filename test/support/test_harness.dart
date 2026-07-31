import 'package:arcvanta/data/capture/model_contract.dart';
import 'package:arcvanta/data/capture/native_capture_source.dart';
import 'package:arcvanta/data/demo/demo_data.dart';
import 'package:arcvanta/data/store/repository.dart';
import 'package:arcvanta/state/capture_pipeline.dart';
import 'package:arcvanta/state/app_settings.dart';
import 'package:arcvanta/state/bootstrap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Boots the app's storage against a throwaway in-memory database.
///
/// Widget tests get the real repository rather than a fake so the same code
/// path the device uses is the one under test, including the SQL. Each call
/// opens a fresh database, so tests cannot leak state into each other.
abstract final class TestHarness {
  static void initialiseSqlite() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  /// States the pipeline answer up front.
  ///
  /// Left to itself the check goes out over a platform channel that never
  /// replies under the test binding, so anything waiting on it — the splash,
  /// for one — waits forever. Declaring it also lets a test choose which of
  /// the two presentations it is exercising.
  static Override pipeline({bool live = false}) =>
      pipelineStatusProvider.overrideWith(
        (ref) async => live
            ? const PipelineStatus(
                isLive: true,
                runtime: ModelRuntimeInfo(
                  contractVersion: ModelContract.version,
                  detectorVersion: 'test-det',
                  poseVersion: 'test-pose',
                  backend: InferenceBackend.cpu,
                ),
                fallbackReason: null,
                fallbackDetail: null,
              )
            : const PipelineStatus.simulated(
                reason: CaptureUnavailableReason.noPlatformImplementation,
              ),
      );

  /// Overrides for a device that has never been used.
  static Future<List<Override>> empty() async {
    final repository = await _open();
    return [
      repositoryProvider.overrideWithValue(repository),
      appSnapshotProvider.overrideWithValue(await AppSnapshot.load(repository)),
      pipeline(),
    ];
  }

  /// Overrides for a device with the sample season loaded.
  ///
  /// This is the state most screen tests want: it is the only way to render a
  /// populated history now that the app no longer starts with one.
  static Future<List<Override>> withDemoData() async {
    final repository = await _open();
    await repository.saveSessions(DemoData.sessions);
    await repository.saveProfile(DemoData.player);
    await repository.saveGoals(DemoData.goals);
    await repository.saveHighlights(DemoData.highlights);
    await repository.saveNotifications(DemoData.notifications);

    final snapshot = await AppSnapshot.load(repository);

    return [
      repositoryProvider.overrideWithValue(repository),
      pipeline(),
      appSnapshotProvider.overrideWithValue(
        AppSnapshot(
          sessions: await repository.loadSessions(includeDemo: true),
          profile: snapshot.profile,
          goals: snapshot.goals,
          highlights: snapshot.highlights,
          notifications: snapshot.notifications,
          customDrills: snapshot.customDrills,
          settings: const AppSettings(demoDataEnabled: true),
        ),
      ),
    ];
  }

  static int _sequence = 0;

  /// Opens a database no other test can see.
  ///
  /// sqflite shares one `:memory:` database between every open in a process
  /// until it is closed, so using the plain in-memory path let one test's
  /// sessions leak into the next — which quietly turned the "first run" cases
  /// into a second copy of the populated ones. A unique named memory database
  /// per call keeps them genuinely separate.
  static Future<ArcVantaRepository> _open() async {
    final repository = await ArcVantaRepository.open(
      path: 'file:arcvanta-test-${_sequence++}?mode=memory&cache=shared',
      factory: databaseFactoryFfi,
    );
    addTearDown(repository.close);
    return repository;
  }
}
