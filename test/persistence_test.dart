import 'package:arcvanta/data/models/confidence.dart';
import 'package:arcvanta/data/models/profile.dart';
import 'package:arcvanta/data/models/program.dart';
import 'package:arcvanta/data/models/session.dart';
import 'package:arcvanta/data/models/shot.dart';
import 'package:arcvanta/data/store/repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Exercises the real SQL, not a stand-in.
///
/// The point of these tests is that a recorded session survives being written
/// to disk and read back by a process that did not create it, so an in-memory
/// fake would test nothing that matters.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late ArcVantaRepository repository;

  setUp(() async {
    repository = await ArcVantaRepository.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
  });

  tearDown(() => repository.close());

  Shot shot({
    required int index,
    ShotResult result = ShotResult.made,
    CourtZone zone = CourtZone.freeThrow,
  }) {
    return Shot(
      id: 'shot-$index',
      index: index,
      offsetFromStart: Duration(seconds: index * 12),
      result: result,
      outcomeDetail: ShotOutcomeDetail.swish,
      zone: zone,
      type: ShotType.freeThrow,
      confidence: ConfidenceLevel.high,
      releaseAngle: 52.4,
      entryAngle: 45.1,
      apexHeightM: 3.9,
      releaseHeightM: 2.3,
      ballSpeedMs: 7.1,
      flightTimeMs: 980,
      lateralDeviationCm: -2.5,
      depthCm: 4.0,
      elbowAngle: 88.0,
      kneeFlexion: 118.0,
      guideHandSeparationCm: 3.2,
      releaseTimeMs: 620,
      followThroughMs: 410,
      landingDriftCm: 5.5,
      balanceScore: 0.82,
      mechanicsScore: 0.79,
      trajectory: const [Offset(0.1, 0.9), Offset(0.5, 0.2), Offset(0.8, 0.4)],
      phases: const [
        ShotPhase(name: 'Dip', startMs: 0, durationMs: 180),
        ShotPhase(name: 'Rise', startMs: 180, durationMs: 260),
      ],
    );
  }

  TrainingSession session({
    required String id,
    required DateTime startedAt,
    List<Shot>? shots,
    bool isDemo = false,
    bool isSimulated = false,
  }) {
    return TrainingSession(
      id: id,
      drillId: 'free-throw-ladder',
      drillName: 'Free-throw ladder',
      startedAt: startedAt,
      duration: const Duration(minutes: 18),
      shots: shots ?? [shot(index: 0), shot(index: 1, result: ShotResult.missed)],
      calibration: const CalibrationRecord(
        angle: CameraAngle.side,
        qualityScore: 0.86,
        courtProfile: 'Home driveway',
        rimHeightM: 3.048,
        lightingScore: 0.8,
        stabilityScore: 0.9,
        framingScore: 0.84,
        frameRate: 60,
        notes: ['Tripod at 4.2 m'],
      ),
      cues: const [
        CoachingCue(
          id: 'cue-1',
          headline: 'Entry angle is flattening',
          detail: 'Nine of your last twelve came in under 42 degrees.',
          source: CueSource.measurement,
          priority: CuePriority.primary,
          confidence: ConfidenceLevel.high,
          evidence: ['entryAngle', 'releaseAngle'],
        ),
      ],
      modelVersion: 'rtmdet-m/rtmpose-m@1',
      deviceName: 'Pixel 8',
      processedOnDevice: true,
      isDemo: isDemo,
      isSimulated: isSimulated,
    );
  }

  test('a session survives a write and read with every field intact', () async {
    final original = session(id: 's1', startedAt: DateTime(2026, 3, 4, 17, 30));
    await repository.saveSession(original);

    final loaded = await repository.loadSessions(includeDemo: false);
    expect(loaded, hasLength(1));

    final restored = loaded.single;
    expect(restored.id, original.id);
    expect(restored.drillName, original.drillName);
    expect(restored.startedAt, original.startedAt);
    expect(restored.duration, original.duration);
    expect(restored.modelVersion, original.modelVersion);
    expect(restored.processedOnDevice, isTrue);

    expect(restored.calibration.angle, CameraAngle.side);
    expect(restored.calibration.qualityScore, closeTo(0.86, 1e-9));
    expect(restored.calibration.notes, ['Tripod at 4.2 m']);

    expect(restored.cues, hasLength(1));
    expect(restored.cues.single.headline, 'Entry angle is flattening');
    expect(restored.cues.single.evidence, ['entryAngle', 'releaseAngle']);

    expect(restored.shots, hasLength(2));
    final first = restored.shots.first;
    expect(first.result, ShotResult.made);
    expect(first.zone, CourtZone.freeThrow);
    expect(first.releaseAngle, closeTo(52.4, 1e-9));
    expect(first.trajectory, hasLength(3));
    expect(first.trajectory[1], const Offset(0.5, 0.2));
    expect(first.phases.map((p) => p.name), ['Dip', 'Rise']);
    expect(restored.shots[1].result, ShotResult.missed);
  });

  test('sessions come back newest first', () async {
    await repository.saveSession(
      session(id: 'older', startedAt: DateTime(2026, 1, 1)),
    );
    await repository.saveSession(
      session(id: 'newer', startedAt: DateTime(2026, 5, 1)),
    );

    final loaded = await repository.loadSessions(includeDemo: false);
    expect(loaded.map((s) => s.id), ['newer', 'older']);
  });

  test('demo sessions stay out of the real history', () async {
    await repository.saveSession(
      session(id: 'real', startedAt: DateTime(2026, 2, 2)),
    );
    await repository.saveSession(
      session(id: 'demo', startedAt: DateTime(2026, 3, 3), isDemo: true),
    );

    expect(
      (await repository.loadSessions(includeDemo: false)).map((s) => s.id),
      ['real'],
    );
    expect(
      (await repository.loadSessions(includeDemo: true)).map((s) => s.id),
      ['demo', 'real'],
    );
    expect(await repository.hasRealSessions(), isTrue);
  });

  test('a simulated session survives the round trip still flagged', () async {
    await repository.saveSession(
      session(id: 'sim', startedAt: DateTime(2026, 2, 2), isSimulated: true),
    );

    final loaded = (await repository.loadSessions(includeDemo: false)).single;
    expect(loaded.isSimulated, isTrue);
    expect(loaded.isDemo, isFalse);
    // Kept in history, because the athlete did run it, but never counted as
    // measurement.
    expect(loaded.isMeasured, isFalse);
  });

  test('turning the demo off removes only the demo rows', () async {
    await repository.saveSession(
      session(id: 'real', startedAt: DateTime(2026, 2, 2)),
    );
    await repository.saveSession(
      session(id: 'demo', startedAt: DateTime(2026, 3, 3), isDemo: true),
    );

    await repository.deleteDemoSessions();

    final loaded = await repository.loadSessions(includeDemo: true);
    expect(loaded.map((s) => s.id), ['real']);
  });

  test('re-saving a session does not leave its old shots behind', () async {
    await repository.saveSession(
      session(
        id: 's1',
        startedAt: DateTime(2026, 4, 4),
        shots: [shot(index: 0), shot(index: 1), shot(index: 2)],
      ),
    );
    await repository.saveSession(
      session(
        id: 's1',
        startedAt: DateTime(2026, 4, 4),
        shots: [shot(index: 0)],
      ),
    );

    final loaded = await repository.loadSessions(includeDemo: false);
    expect(loaded.single.shots, hasLength(1));
  });

  test('deleting a session takes its shots with it', () async {
    await repository.saveSession(
      session(id: 's1', startedAt: DateTime(2026, 4, 4)),
    );
    await repository.deleteSession('s1');

    expect(await repository.loadSessions(includeDemo: true), isEmpty);
    expect(await repository.hasRealSessions(), isFalse);
  });

  test('an empty database reports no history rather than failing', () async {
    expect(await repository.loadSessions(includeDemo: false), isEmpty);
    expect(await repository.hasRealSessions(), isFalse);
    expect(await repository.loadProfile(), isNull);
    expect(await repository.loadGoals(), isEmpty);
    expect(await repository.loadHighlights(), isEmpty);
  });

  test('the profile round-trips', () async {
    final profile = PlayerProfile(
      id: 'local',
      displayName: 'Tira',
      initials: 'T',
      ageBand: '23 to 29',
      heightCm: 188,
      wingspanCm: 193,
      dominantHand: DominantHand.left,
      position: PlayerPosition.pointGuard,
      skillLevel: SkillLevel.advanced,
      teamName: 'Saturday run',
      coachName: '',
      accentColor: const Color(0xFF2E6F5E),
      goals: const ['Raise entry angle', 'More corner threes'],
      weeklyAvailability: 4,
    );

    await repository.saveProfile(profile);
    final restored = await repository.loadProfile();

    expect(restored, isNotNull);
    expect(restored!.displayName, 'Tira');
    expect(restored.dominantHand, DominantHand.left);
    expect(restored.position, PlayerPosition.pointGuard);
    expect(restored.skillLevel, SkillLevel.advanced);
    expect(restored.heightCm, 188);
    expect(restored.accentColor.toARGB32(), 0xFF2E6F5E);
    expect(restored.goals, hasLength(2));
  });

  test('goals and highlights round-trip as collections', () async {
    await repository.saveGoals([
      Goal(
        id: 'g1',
        kind: GoalKind.percentage,
        title: 'Free throws above 80',
        detail: 'Across any session of twenty or more attempts.',
        current: 72,
        target: 80,
        unit: '%',
        dueAt: DateTime(2026, 9, 1),
        setBy: 'You',
      ),
    ]);
    await repository.saveHighlights([
      Highlight(
        id: 'h1',
        title: 'Seven straight',
        kind: HighlightKind.bestMakes,
        createdAt: DateTime(2026, 5, 5),
        shotCount: 7,
        sessionId: 's1',
        visibility: HighlightVisibility.privateOnly,
        accent: const Color(0xFFE8863E),
      ),
    ]);

    final goals = await repository.loadGoals();
    expect(goals.single.title, 'Free throws above 80');
    expect(goals.single.kind, GoalKind.percentage);
    expect(goals.single.dueAt, DateTime(2026, 9, 1));

    final highlights = await repository.loadHighlights();
    expect(highlights.single.kind, HighlightKind.bestMakes);
    expect(highlights.single.shotCount, 7);
  });

  test('an unknown enum name decodes to a fallback instead of throwing', () async {
    // Simulates a row written by a build that knew a variant this one does not.
    await repository.writeCollection('goals', [
      {
        'id': 'g1',
        'kind': 'somethingAddedLater',
        'title': 'Future goal',
        'detail': '',
        'current': 1.0,
        'target': 2.0,
        'unit': '%',
        'dueAt': DateTime(2026, 9, 1).millisecondsSinceEpoch,
        'setBy': 'You',
      },
    ]);

    final goals = await repository.loadGoals();
    expect(goals.single.kind, GoalKind.percentage);
    expect(goals.single.title, 'Future goal');
  });

  test('deleting everything leaves nothing', () async {
    await repository.saveSession(
      session(id: 's1', startedAt: DateTime(2026, 4, 4)),
    );
    await repository.saveGoals([
      Goal(
        id: 'g1',
        kind: GoalKind.volume,
        title: 'x',
        detail: '',
        current: 0,
        target: 1,
        unit: '',
        dueAt: DateTime(2026, 1, 1),
        setBy: 'You',
      ),
    ]);

    await repository.deleteEverything();

    expect(await repository.loadSessions(includeDemo: true), isEmpty);
    expect(await repository.loadGoals(), isEmpty);
  });
}
