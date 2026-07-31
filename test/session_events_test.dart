import 'package:arcvanta/data/demo/demo_data.dart';
import 'package:arcvanta/data/models/program.dart';
import 'package:arcvanta/data/models/session.dart';
import 'package:arcvanta/data/store/repository.dart';
import 'package:arcvanta/state/bootstrap.dart';
import 'package:arcvanta/state/session_events.dart';
import 'package:arcvanta/state/stores.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The notification centre is only worth having if the app fills it from work
/// the athlete did. These tests hold it to that: nothing arrives unprompted,
/// and everything that arrives points at a real session.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late ArcVantaRepository repository;
  late ProviderContainer container;
  var sequence = 0;

  setUp(() async {
    repository = await ArcVantaRepository.open(
      path: 'file:events-${sequence++}?mode=memory&cache=shared',
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

  var day = 1;
  Future<TrainingSession> record(String id, {int shots = 0}) async {
    final session = _session(id, shotCount: shots, day: day++);
    await container.read(sessionStoreProvider.notifier).addSession(session);
    await container.read(sessionEventsProvider).recordCompleted(session);
    return session;
  }

  test('a fresh install has no notifications', () {
    expect(container.read(notificationStoreProvider), isEmpty);
  });

  test('recording a session posts one that opens its summary', () async {
    final session = await record('first');

    final posted = container.read(notificationStoreProvider);
    expect(posted, hasLength(1));
    expect(posted.single.kind, NotificationKind.analysis);
    expect(posted.single.title, contains(session.drillName));
    expect(posted.single.actionRoute, contains(session.id));
    expect(posted.single.read, isFalse);
  });

  test('the first session sets records without announcing them', () async {
    await record('first', shots: 40);

    // Every record is a first on session one. Calling each of them a new best
    // would bury the one notification that matters under a pile of noise.
    final kinds = [
      for (final n in container.read(notificationStoreProvider)) n.kind,
    ];
    expect(kinds, everyElement(NotificationKind.analysis));
  });

  test('beating a previous best announces it once', () async {
    // Both sessions clear the minimum attempt count, so the first sets the
    // records and the second has something to take off it.
    await record('weak', shots: 16);
    await record('strong', shots: 40);

    final records = [
      for (final n in container.read(notificationStoreProvider))
        if (n.kind == NotificationKind.progress) n,
    ];
    expect(records, isNotEmpty);
    expect(
      records.map((n) => n.id).toSet(),
      hasLength(records.length),
      reason: 'a record should not be posted twice',
    );
  });

  test('demo sessions post nothing', () async {
    final demo = DemoData.sessions.first;
    await container.read(sessionStoreProvider.notifier).addSession(demo);
    await container.read(sessionEventsProvider).recordCompleted(demo);

    expect(container.read(notificationStoreProvider), isEmpty);
  });

  test('a volume goal advances by the attempts actually taken', () async {
    container
        .read(goalStoreProvider.notifier)
        .add(
          Goal(
            id: 'volume',
            kind: GoalKind.volume,
            title: 'Weekly attempts',
            detail: '',
            current: 0,
            target: 1000,
            unit: '',
            dueAt: DateTime(2026, 12),
            setBy: 'You',
          ),
        );

    final session = await record('counted', shots: 20);

    final goal = container.read(goalStoreProvider).single;
    expect(goal.current, session.attemptCount.toDouble());
    expect(goal.achieved, isFalse);
  });

  test('reaching a goal announces it, and only the first time', () async {
    container
        .read(goalStoreProvider.notifier)
        .add(
          Goal(
            id: 'volume',
            kind: GoalKind.volume,
            title: 'Weekly attempts',
            detail: '',
            current: 0,
            target: 5,
            unit: '',
            dueAt: DateTime(2026, 12),
            setBy: 'You',
          ),
        );

    await record('one', shots: 10);
    await record('two', shots: 10);

    final reached = [
      for (final n in container.read(notificationStoreProvider))
        if (n.title.startsWith('Goal reached')) n,
    ];
    expect(reached, hasLength(1));
  });

  test('notifications survive a restart', () async {
    await record('kept');

    final restarted = ProviderContainer(
      overrides: [
        repositoryProvider.overrideWithValue(repository),
        appSnapshotProvider.overrideWithValue(
          await AppSnapshot.load(repository),
        ),
      ],
    );
    addTearDown(restarted.dispose);

    expect(restarted.read(notificationStoreProvider), hasLength(1));
  });
}

/// A recorded session built from the demo shot data, trimmed to [shotCount].
///
/// Using real shots keeps the analytics honest — percentages, streaks and
/// mechanics all come out of the same code path the app uses.
TrainingSession _session(
  String id, {
  required int shotCount,
  required int day,
}) {
  final source = DemoData.sessions.first;
  final shots = shotCount == 0
      ? source.shots
      : source.shots.take(shotCount).toList(growable: false);

  return TrainingSession(
    id: id,
    drillId: source.drillId,
    drillName: source.drillName,
    startedAt: DateTime(2026, 6, day, 17),
    duration: source.duration,
    shots: shots,
    calibration: source.calibration,
    cues: source.cues,
    modelVersion: source.modelVersion,
    deviceName: source.deviceName,
    processedOnDevice: true,
  );
}
