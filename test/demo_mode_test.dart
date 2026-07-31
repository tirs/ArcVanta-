import 'package:arcvanta/data/demo/demo_data.dart';
import 'package:arcvanta/data/models/session.dart';
import 'package:arcvanta/data/store/repository.dart';
import 'package:arcvanta/state/app_settings.dart';
import 'package:arcvanta/state/bootstrap.dart';
import 'package:arcvanta/state/demo_mode.dart';
import 'package:arcvanta/state/stores.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The sample data is only defensible if it can never be mistaken for the
/// user's own. These tests pin that boundary down.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late ArcVantaRepository repository;
  late ProviderContainer container;

  setUp(() async {
    repository = await ArcVantaRepository.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    container = ProviderContainer(
      overrides: [
        repositoryProvider.overrideWithValue(repository),
        appSnapshotProvider.overrideWithValue(
          await AppSnapshot.load(repository),
        ),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    return repository.close();
  });

  test('the app starts with no sessions at all', () {
    expect(container.read(sessionStoreProvider), isEmpty);
    expect(container.read(hasRecordedHistoryProvider), isFalse);
    expect(container.read(showingSampleDataProvider), isFalse);
    expect(container.read(appSettingsProvider).demoDataEnabled, isFalse);
  });

  test('every statistic on a fresh install is empty, not a placeholder', () {
    expect(container.read(lifetimeTotalsProvider).attempts, 0);
    expect(container.read(personalRecordsProvider), isEmpty);
    expect(container.read(trendExplanationsProvider), isEmpty);
    expect(container.read(zoneBreakdownProvider), isEmpty);
    expect(container.read(trainingPlanProvider), isNull);
  });

  test('turning the demo on loads it and marks it as sample data', () async {
    await container.read(demoModeProvider).setEnabled(true);

    expect(container.read(sessionStoreProvider), isNotEmpty);
    expect(container.read(showingSampleDataProvider), isTrue);
    expect(container.read(appSettingsProvider).demoDataEnabled, isTrue);
  });

  test('demo sessions never count as the athlete having a history', () async {
    await container.read(demoModeProvider).setEnabled(true);

    expect(container.read(sessionStoreProvider), isNotEmpty);
    expect(container.read(hasRecordedHistoryProvider), isFalse);
  });

  test('every loaded demo session is flagged in storage', () async {
    await container.read(demoModeProvider).setEnabled(true);

    final stored = await repository.loadSessions(includeDemo: true);
    expect(stored, isNotEmpty);
    expect(stored.every((session) => session.isDemo), isTrue);
    expect(await repository.hasRealSessions(), isFalse);
  });

  test('turning the demo off removes all of it', () async {
    await container.read(demoModeProvider).setEnabled(true);
    expect(container.read(sessionStoreProvider), isNotEmpty);

    await container.read(demoModeProvider).setEnabled(false);

    expect(container.read(sessionStoreProvider), isEmpty);
    expect(container.read(showingSampleDataProvider), isFalse);
    expect(await repository.loadSessions(includeDemo: true), isEmpty);
  });

  test('turning the demo off leaves a real session untouched', () async {
    await repository.saveSession(_recordedSession('my-session'));
    await container
        .read(sessionStoreProvider.notifier)
        .reload(includeDemo: false);

    await container.read(demoModeProvider).setEnabled(true);
    expect(container.read(hasRecordedHistoryProvider), isTrue);

    await container.read(demoModeProvider).setEnabled(false);

    final remaining = container.read(sessionStoreProvider);
    expect(remaining, hasLength(1));
    expect(remaining.single.id, 'my-session');
    expect(remaining.single.isDemo, isFalse);
  });

  test('the demo preference survives a restart', () async {
    await container.read(demoModeProvider).setEnabled(true);

    // A second container over the same database stands in for a relaunch.
    final restarted = ProviderContainer(
      overrides: [
        repositoryProvider.overrideWithValue(repository),
        appSnapshotProvider.overrideWithValue(
          await AppSnapshot.load(repository),
        ),
      ],
    );
    addTearDown(restarted.dispose);

    expect(restarted.read(appSettingsProvider).demoDataEnabled, isTrue);
    expect(restarted.read(sessionStoreProvider), isNotEmpty);
  });

  test('a recorded session survives a restart', () async {
    await container
        .read(sessionStoreProvider.notifier)
        .addSession(_recordedSession('recorded'));

    final restarted = ProviderContainer(
      overrides: [
        repositoryProvider.overrideWithValue(repository),
        appSnapshotProvider.overrideWithValue(
          await AppSnapshot.load(repository),
        ),
      ],
    );
    addTearDown(restarted.dispose);

    final sessions = restarted.read(sessionStoreProvider);
    expect(sessions, hasLength(1));
    expect(sessions.single.id, 'recorded');
    expect(sessions.single.shots, isNotEmpty);
    expect(restarted.read(hasRecordedHistoryProvider), isTrue);
  });
}

/// A session shaped like one the camera produced.
///
/// Borrows a demo session's shots so the row has realistic content, but is
/// built as the athlete's own: a different id and `isDemo` left false.
TrainingSession _recordedSession(String id) {
  final source = DemoData.sessions.first;

  return TrainingSession(
    id: id,
    drillId: source.drillId,
    drillName: source.drillName,
    startedAt: DateTime(2026, 6, 1, 17),
    duration: source.duration,
    shots: source.shots,
    calibration: source.calibration,
    cues: source.cues,
    modelVersion: source.modelVersion,
    deviceName: source.deviceName,
    processedOnDevice: true,
  );
}
