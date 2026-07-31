import 'package:sqflite/sqflite.dart';

/// Opens the on-device database and owns its schema.
///
/// Sessions are the only thing here that grows without bound — a season is
/// hundreds of sessions and tens of thousands of shots — so they get real
/// tables with real indexes. Everything else is a short list that is read
/// whole and written whole, and lives in [documentsTable] as JSON rather than
/// earning five more tables and five more migrations.
abstract final class ArcVantaDatabase {
  static const String fileName = 'arcvanta.db';

  static const String sessionsTable = 'sessions';
  static const String shotsTable = 'shots';
  static const String documentsTable = 'documents';

  /// Bump on any schema change and add the matching step to [_upgrade].
  ///
  /// A user's shot history is not regenerable. Dropping and recreating is
  /// never an acceptable migration here, whatever the convenience.
  static const int version = 2;

  static Future<Database> open({
    String? path,
    DatabaseFactory? factory,
  }) async {
    final resolved = factory ?? databaseFactory;
    final location = path ?? '${await resolved.getDatabasesPath()}/$fileName';

    return resolved.openDatabase(
      location,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) => _create(db),
        onUpgrade: (db, from, to) => _upgrade(db, from, to),
      ),
    );
  }

  static Future<void> _create(Database db) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE $sessionsTable (
        id TEXT PRIMARY KEY,
        drill_id TEXT NOT NULL,
        drill_name TEXT NOT NULL,
        started_at INTEGER NOT NULL,
        duration_ms INTEGER NOT NULL,
        model_version TEXT NOT NULL,
        device_name TEXT NOT NULL,
        processed_on_device INTEGER NOT NULL,
        assignment_id TEXT,
        coach_comment TEXT,
        calibration TEXT NOT NULL,
        cues TEXT NOT NULL,
        makes INTEGER NOT NULL,
        attempts INTEGER NOT NULL,
        is_demo INTEGER NOT NULL DEFAULT 0,
        is_simulated INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // History is always read newest first, and demo rows are always either
    // included or excluded wholesale, so both live in the same index.
    batch.execute(
      'CREATE INDEX sessions_recent ON $sessionsTable(is_demo, started_at DESC)',
    );

    batch.execute('''
      CREATE TABLE $shotsTable (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL
          REFERENCES $sessionsTable(id) ON DELETE CASCADE,
        idx INTEGER NOT NULL,
        offset_ms INTEGER NOT NULL,
        result TEXT NOT NULL,
        outcome_detail TEXT NOT NULL,
        zone TEXT NOT NULL,
        type TEXT NOT NULL,
        confidence TEXT NOT NULL,
        release_angle REAL NOT NULL,
        entry_angle REAL NOT NULL,
        apex_height_m REAL NOT NULL,
        release_height_m REAL NOT NULL,
        ball_speed_ms REAL NOT NULL,
        flight_time_ms INTEGER NOT NULL,
        lateral_deviation_cm REAL NOT NULL,
        depth_cm REAL NOT NULL,
        elbow_angle REAL NOT NULL,
        knee_flexion REAL NOT NULL,
        guide_hand_separation_cm REAL NOT NULL,
        release_time_ms INTEGER NOT NULL,
        follow_through_ms INTEGER NOT NULL,
        landing_drift_cm REAL NOT NULL,
        balance_score REAL NOT NULL,
        mechanics_score REAL NOT NULL,
        corrected_by_user INTEGER NOT NULL DEFAULT 0,
        note TEXT,
        detail TEXT NOT NULL
      )
    ''');

    batch.execute(
      'CREATE INDEX shots_by_session ON $shotsTable(session_id, idx)',
    );
    // The zone breakdown and the heatmap both group by zone across every
    // session, which is the one query that does not start from a session id.
    batch.execute('CREATE INDEX shots_by_zone ON $shotsTable(zone)');

    batch.execute('''
      CREATE TABLE $documentsTable (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await batch.commit(noResult: true);
  }

  static Future<void> _upgrade(Database db, int from, int to) async {
    // Each step is additive and runs in order, so a database at any earlier
    // version arrives at the current one by falling through all of them.
    if (from < 2) {
      // Sessions predating this column were all recorded before the app could
      // tell simulation from measurement. The default of 0 treats them as
      // measured, which is what the athlete was told at the time.
      await db.execute(
        'ALTER TABLE $sessionsTable '
        'ADD COLUMN is_simulated INTEGER NOT NULL DEFAULT 0',
      );
    }
  }
}
