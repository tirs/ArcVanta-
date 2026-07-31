import 'dart:convert';
import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../models/drill.dart';
import '../models/profile.dart';
import '../models/program.dart';
import '../models/session.dart';
import '../models/shot.dart';
import 'codecs.dart';
import 'database.dart';

/// Keys for the small documents that are read and written whole.
abstract final class DocumentKey {
  static const String profile = 'profile';
  static const String goals = 'goals';
  static const String highlights = 'highlights';
  static const String notifications = 'notifications';
  static const String customDrills = 'custom_drills';
  static const String settings = 'settings';
  static const String onboarding = 'onboarding';
}

/// The app's only route to stored data.
///
/// Everything above this reads and writes domain objects; nothing above it
/// knows SQL exists. The split matters most for the demo data: `isDemo` is a
/// column here, so turning the demo off is one delete and cannot leave
/// fabricated shots mixed into a real history.
class ArcVantaRepository {
  ArcVantaRepository(this._db);

  final Database _db;

  static Future<ArcVantaRepository> open({
    String? path,
    DatabaseFactory? factory,
  }) async {
    return ArcVantaRepository(
      await ArcVantaDatabase.open(path: path, factory: factory),
    );
  }

  Future<void> close() => _db.close();

  /// Bytes this app's data actually occupies, read from the database file.
  ///
  /// Returns zero for the in-memory database used in tests, which has no file
  /// to measure.
  Future<int> storageBytes() async {
    final path = _db.path;
    if (!path.startsWith('/')) return 0;
    final file = File(path);
    if (!file.existsSync()) return 0;
    var total = await file.length();
    // SQLite keeps the write-ahead log and shared-memory file alongside the
    // database, and they count against the user's storage just the same.
    for (final suffix in const ['-wal', '-shm']) {
      final sidecar = File('$path$suffix');
      if (sidecar.existsSync()) total += await sidecar.length();
    }
    return total;
  }

  // --- Sessions -----------------------------------------------------------

  /// Loads full sessions, newest first.
  ///
  /// Shots come back in one query rather than one per session; a season of
  /// history would otherwise be hundreds of round trips on a cold start.
  Future<List<TrainingSession>> loadSessions({
    required bool includeDemo,
    int? limit,
  }) async {
    final sessionRows = await _db.query(
      ArcVantaDatabase.sessionsTable,
      where: includeDemo ? null : 'is_demo = 0',
      orderBy: 'started_at DESC',
      limit: limit,
    );
    if (sessionRows.isEmpty) return const [];

    final ids = [for (final row in sessionRows) row['id'] as String];
    final placeholders = List.filled(ids.length, '?').join(', ');
    final shotRows = await _db.query(
      ArcVantaDatabase.shotsTable,
      where: 'session_id IN ($placeholders)',
      whereArgs: ids,
      orderBy: 'idx ASC',
    );

    final shotsBySession = <String, List<Shot>>{};
    for (final row in shotRows) {
      (shotsBySession[row['session_id'] as String] ??= <Shot>[])
          .add(Codecs.shotFromRow(row));
    }

    return [
      for (final row in sessionRows)
        Codecs.sessionFromRow(row, shotsBySession[row['id']] ?? const []),
    ];
  }

  Future<void> saveSession(TrainingSession session) async {
    await _db.transaction((txn) async {
      await txn.insert(
        ArcVantaDatabase.sessionsTable,
        Codecs.sessionToRow(session),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      // Replacing the parent row does not cascade, because the row is
      // recreated rather than deleted. Clear the shots explicitly so a
      // re-saved session cannot keep orphans from its previous shape.
      await txn.delete(
        ArcVantaDatabase.shotsTable,
        where: 'session_id = ?',
        whereArgs: [session.id],
      );

      final batch = txn.batch();
      for (final shot in session.shots) {
        batch.insert(
          ArcVantaDatabase.shotsTable,
          Codecs.shotToRow(shot, session.id),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> deleteSession(String id) async {
    await _db.delete(
      ArcVantaDatabase.sessionsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteDemoSessions() async {
    await _db.delete(
      ArcVantaDatabase.sessionsTable,
      where: 'is_demo = 1',
    );
  }

  Future<bool> hasRealSessions() async {
    final rows = await _db.query(
      ArcVantaDatabase.sessionsTable,
      columns: ['id'],
      where: 'is_demo = 0',
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  // --- Documents ----------------------------------------------------------

  Future<Map<String, Object?>?> readDocument(String key) async {
    final rows = await _db.query(
      ArcVantaDatabase.documentsTable,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final decoded = jsonDecode(rows.first['value'] as String);
    return decoded is Map ? decoded.cast<String, Object?>() : null;
  }

  Future<List<Map<String, Object?>>> readCollection(String key) async {
    final document = await readDocument(key);
    if (document == null) return const [];
    return [
      for (final item in Codecs.jsonList(document['items']))
        if (item is Map) item.cast<String, Object?>(),
    ];
  }

  Future<void> writeDocument(String key, Map<String, Object?> value) async {
    await _db.insert(
      ArcVantaDatabase.documentsTable,
      {
        'key': key,
        'value': jsonEncode(value),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> writeCollection(
    String key,
    List<Map<String, Object?>> items,
  ) => writeDocument(key, {'items': items});

  Future<void> deleteDocument(String key) async {
    await _db.delete(
      ArcVantaDatabase.documentsTable,
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  // --- Typed document helpers --------------------------------------------

  Future<PlayerProfile?> loadProfile() async {
    final json = await readDocument(DocumentKey.profile);
    return json == null ? null : Codecs.profileFromJson(json);
  }

  Future<void> saveProfile(PlayerProfile profile) =>
      writeDocument(DocumentKey.profile, Codecs.profileToJson(profile));

  Future<List<Goal>> loadGoals() async => [
    for (final json in await readCollection(DocumentKey.goals))
      Codecs.goalFromJson(json),
  ];

  Future<void> saveGoals(List<Goal> goals) => writeCollection(
    DocumentKey.goals,
    [for (final goal in goals) Codecs.goalToJson(goal)],
  );

  Future<List<Highlight>> loadHighlights() async => [
    for (final json in await readCollection(DocumentKey.highlights))
      Codecs.highlightFromJson(json),
  ];

  Future<void> saveHighlights(List<Highlight> highlights) => writeCollection(
    DocumentKey.highlights,
    [for (final item in highlights) Codecs.highlightToJson(item)],
  );

  Future<List<AppNotification>> loadNotifications() async => [
    for (final json in await readCollection(DocumentKey.notifications))
      Codecs.notificationFromJson(json),
  ];

  Future<void> saveNotifications(List<AppNotification> items) =>
      writeCollection(DocumentKey.notifications, [
        for (final item in items) Codecs.notificationToJson(item),
      ]);

  Future<List<Drill>> loadCustomDrills() async => [
    for (final json in await readCollection(DocumentKey.customDrills))
      Codecs.drillFromJson(json),
  ];

  Future<void> saveCustomDrills(List<Drill> drills) => writeCollection(
    DocumentKey.customDrills,
    [for (final drill in drills) Codecs.drillToJson(drill)],
  );

  /// Writes many sessions in one transaction.
  ///
  /// Used when the sample history is switched on, which inserts a season's
  /// worth at once and should not be a few hundred separate commits.
  Future<void> saveSessions(List<TrainingSession> sessions) async {
    await _db.transaction((txn) async {
      final batch = txn.batch();
      for (final session in sessions) {
        batch.insert(
          ArcVantaDatabase.sessionsTable,
          Codecs.sessionToRow(session),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        for (final shot in session.shots) {
          batch.insert(
            ArcVantaDatabase.shotsTable,
            Codecs.shotToRow(shot, session.id),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
      await batch.commit(noResult: true);
    });
  }

  /// Removes every trace of the user's data.
  ///
  /// Backing the "delete everything" control in Settings, so it has to be
  /// exactly that and not a state reset that leaves rows behind.
  Future<void> deleteEverything() async {
    await _db.transaction((txn) async {
      await txn.delete(ArcVantaDatabase.shotsTable);
      await txn.delete(ArcVantaDatabase.sessionsTable);
      await txn.delete(ArcVantaDatabase.documentsTable);
    });
  }
}
