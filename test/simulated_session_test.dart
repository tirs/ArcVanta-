import 'package:arcvanta/data/models/confidence.dart';
import 'package:arcvanta/data/models/session.dart';
import 'package:arcvanta/data/models/shot.dart';
import 'package:arcvanta/data/store/repository.dart';
import 'package:arcvanta/state/bootstrap.dart';
import 'package:arcvanta/state/stores.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_harness.dart';

/// A session run with no models loaded is still the athlete's session — they
/// pressed start, so it belongs in their history. What it must never do is
/// contribute a number, because every number in it came from an animation.
/// These tests pin both halves of that.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestHarness.initialiseSqlite();

  var sequence = 0;

  Shot shot({
    required String session,
    required int index,
    required ShotResult result,
  }) {
    return Shot(
      // Scoped to the session: shot ids are the primary key in storage, so
      // two sessions sharing them would silently merge.
      id: '$session-shot-$index',
      index: index,
      offsetFromStart: Duration(seconds: index * 10),
      result: result,
      outcomeDetail: ShotOutcomeDetail.undetermined,
      zone: CourtZone.freeThrow,
      type: ShotType.setShot,
      confidence: ConfidenceLevel.high,
      releaseAngle: 52,
      entryAngle: 45,
      apexHeightM: 3.8,
      releaseHeightM: 2.2,
      ballSpeedMs: 7,
      flightTimeMs: 900,
      lateralDeviationCm: 0,
      depthCm: 0,
      elbowAngle: 88,
      kneeFlexion: 120,
      guideHandSeparationCm: 3,
      releaseTimeMs: 600,
      followThroughMs: 400,
      landingDriftCm: 2,
      balanceScore: 0.8,
      mechanicsScore: 0.8,
      trajectory: const [],
      phases: const [],
    );
  }

  TrainingSession session({
    required String id,
    required DateTime startedAt,
    required int makes,
    bool isSimulated = false,
  }) {
    return TrainingSession(
      id: id,
      drillId: 'free-throw-ladder',
      drillName: 'Free-throw ladder',
      startedAt: startedAt,
      duration: const Duration(minutes: 10),
      shots: [
        for (var i = 0; i < makes; i++)
          shot(session: id, index: i, result: ShotResult.made),
        shot(session: id, index: makes, result: ShotResult.missed),
      ],
      calibration: const CalibrationRecord(
        angle: CameraAngle.side,
        qualityScore: 0.9,
        courtProfile: 'Gym',
        rimHeightM: 3.048,
        lightingScore: 0.9,
        stabilityScore: 0.9,
        framingScore: 0.9,
        frameRate: 60,
        notes: [],
      ),
      cues: const [],
      modelVersion: isSimulated ? 'simulated' : 'rtmdet-m/rtmpose-m@1',
      deviceName: 'Test',
      processedOnDevice: true,
      isSimulated: isSimulated,
    );
  }

  Future<ProviderContainer> boot(List<TrainingSession> sessions) async {
    final repository = await ArcVantaRepository.open(
      path: 'file:arcvanta-sim-${sequence++}?mode=memory&cache=shared',
      factory: databaseFactoryFfi,
    );
    addTearDown(repository.close);

    for (final session in sessions) {
      await repository.saveSession(session);
    }

    final container = ProviderContainer(
      overrides: [
        repositoryProvider.overrideWithValue(repository),
        appSnapshotProvider.overrideWithValue(
          await AppSnapshot.load(repository),
        ),
        TestHarness.pipeline(),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  TrainingSession rehearsal(DateTime at, int makes) =>
      session(id: 'sim', startedAt: at, makes: makes, isSimulated: true);

  test('a simulated session appears in history', () async {
    final container = await boot([rehearsal(DateTime(2026, 4, 1), 9)]);

    expect(container.read(sessionStoreProvider).map((s) => s.id), ['sim']);
  });

  test('a simulated session is not counted as recorded history', () async {
    final container = await boot([rehearsal(DateTime(2026, 4, 1), 9)]);

    expect(container.read(hasRecordedHistoryProvider), isFalse);
  });

  test('simulated shots are left out of lifetime totals', () async {
    final container = await boot([
      session(id: 'real', startedAt: DateTime(2026, 4, 1), makes: 1),
      rehearsal(DateTime(2026, 4, 2), 40),
    ]);

    final totals = container.read(lifetimeTotalsProvider);
    // One make and one miss from the real session. The forty-one attempts
    // from the rehearsal must not be in here.
    expect(totals.attempts, 2);
    expect(totals.makes, 1);
  });

  test('a simulated session cannot set a personal best', () async {
    final container = await boot([
      session(id: 'real', startedAt: DateTime(2026, 4, 1), makes: 1),
      rehearsal(DateTime(2026, 4, 2), 40),
    ]);

    // The rehearsal has a forty-shot streak against the real session's one,
    // so it would win every streak and volume record if it were eligible.
    for (final record in container.read(personalRecordsProvider)) {
      expect(
        record.achievedAt,
        isNot(DateTime(2026, 4, 2)),
        reason: '${record.label} was taken from a rehearsal',
      );
    }
  });

  test('a simulated session does not raise the sample data banner', () async {
    final container = await boot([rehearsal(DateTime(2026, 4, 1), 9)]);

    // It carries its own, differently worded warning on the session itself,
    // and it contributes nothing to the screens the banner sits on.
    expect(container.read(showingSampleDataProvider), isFalse);
  });
}
