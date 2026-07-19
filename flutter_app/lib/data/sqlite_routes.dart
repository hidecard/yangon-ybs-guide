import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import '../models.dart' show BusRoute;

/// Mobile-only SQLite store for offline route search.
///
/// The app still ships the encrypted `routes.bin` bundle, but on first launch
/// we decode it once and materialize a real SQLite database (`routes.db`)
/// with the production schema below. All direct-route searches then run as
/// JOIN queries in SQL (matching the web's Turso schema), so direction and
/// same-named stops are resolved at the database layer — never by guessing.
///
/// `stop_groups` is the Parent key that disambiguates same-named stops across
/// townships (e.g. "တံတားဖြူ" in လသာ vs ကမာရွတ်): a route only matches when the
/// chosen *group* (name + township) appears before the destination group.
class SqliteRoutes {
  SqliteRoutes._();
  static final SqliteRoutes instance = SqliteRoutes._();

  static const _dbName = 'routes.db';
  static const _schemaVersion = 1;

  Database? _db;
  bool _building = false;

  /// Open (and lazily build) the database. [routes] is the decoded route set
  /// used to populate the tables the first time only.
  Future<Database> open(List<BusRoute> routes) async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    final path = p.join(dir, _dbName);

    _db = await openDatabase(
      path,
      version: _schemaVersion,
      onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async => await _createSchema(db),
      onUpgrade: (db, _, __) async => await _createSchema(db),
    );

    // Build only if empty (first launch / after a wipe).
    final count =
        Sqflite.firstIntValue(await _db!.rawQuery('SELECT COUNT(*) FROM routes'));
    if (count == 0) {
      await _populate(_db!, routes);
    }
    return _db!;
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS routes (
        route_id TEXT PRIMARY KEY,
        bus_line TEXT NOT NULL,
        agency TEXT,
        line_name TEXT,
        qr_payment TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stop_groups (
        group_id INTEGER PRIMARY KEY AUTOINCREMENT,
        group_name_mm TEXT NOT NULL,
        township TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bus_stops (
        stop_id INTEGER PRIMARY KEY AUTOINCREMENT,
        group_id INTEGER,
        stop_name_en TEXT,
        stop_name_mm TEXT,
        road TEXT NOT NULL DEFAULT '',
        township TEXT NOT NULL DEFAULT '',
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        FOREIGN KEY (group_id) REFERENCES stop_groups(group_id) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS route_stops (
        route_id TEXT,
        stop_id INTEGER,
        stop_order INTEGER NOT NULL,
        PRIMARY KEY (route_id, stop_id, stop_order),
        FOREIGN KEY (route_id) REFERENCES routes(route_id) ON DELETE CASCADE,
        FOREIGN KEY (stop_id) REFERENCES bus_stops(stop_id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_route_stops_search ON route_stops(stop_id, route_id, stop_order)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_bus_stops_coords ON bus_stops(latitude, longitude)');
  }

  Future<void> _populate(Database db, List<BusRoute> routes) async {
    if (_building) return;
    _building = true;
    try {
      await db.transaction((txn) async {
        // group key (name|township) -> group_id
        final groupIds = <String, int>{};
        // stop key (name|lat|lng) -> stop_id
        final stopIds = <String, int>{};

        int groupSeq = 1;
        int stopSeq = 1;

        for (final r in routes) {
          await txn.insert('routes', {
            'route_id': r.id,
            'bus_line': r.id,
            'agency': r.operator ?? '',
            'line_name': r.lineName ?? '',
            'qr_payment': r.qrPayment ?? '',
          }, conflictAlgorithm: ConflictAlgorithm.replace);

          for (int i = 0; i < r.stopsDetailed.length; i++) {
            final s = r.stopsDetailed[i];
            final township = s.townshipMm.isNotEmpty ? s.townshipMm : '';
            final gKey = '${s.nameMm}|$township';
            final gId = groupIds.putIfAbsent(gKey, () {
              txn.insert('stop_groups', {
                'group_id': groupSeq,
                'group_name_mm': s.nameMm,
                'township': township,
              });
              return groupSeq++;
            });

            final sKey = '${s.nameMm}|${s.lat}|${s.lng}';
            final sId = stopIds.putIfAbsent(sKey, () {
              txn.insert('bus_stops', {
                'stop_id': stopSeq,
                'group_id': gId,
                'stop_name_en': s.nameEn,
                'stop_name_mm': s.nameMm,
                'road': s.roadMm,
                'township': township,
                'latitude': s.lat,
                'longitude': s.lng,
              });
              return stopSeq++;
            });

            await txn.insert('route_stops', {
              'route_id': r.id,
              'stop_id': sId,
              'stop_order': i,
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      });
    } finally {
      _building = false;
    }
  }

  /// Returns route_ids whose forward leg passes through the [startName] group
  /// (in [startTownship]) before the [endName] group (in [endTownship]).
  ///
  /// Mirrors the Production Master SQL: a route matches only when the chosen
  /// stop GROUP (name + township) appears in the correct forward order, so a
  /// same-named stop in another township is never returned.
  Future<List<String>> directRouteIds({
    required String startName,
    required String startTownship,
    required String endName,
    required String endTownship,
  }) async {
    final db = _db;
    if (db == null) return const [];
    try {
      final rows = await db.rawQuery(
        '''
        SELECT DISTINCT r.route_id AS route_id
        FROM route_stops start_rs
        JOIN bus_stops start_stops ON start_rs.stop_id = start_stops.stop_id
        JOIN route_stops end_rs ON start_rs.route_id = end_rs.route_id
        JOIN bus_stops end_stops ON end_rs.stop_id = end_stops.stop_id
        JOIN routes r ON start_rs.route_id = r.route_id
        WHERE start_stops.stop_name_mm = ?
          AND start_stops.township = ?
          AND end_stops.stop_name_mm = ?
          AND end_stops.township = ?
          AND start_rs.stop_order < end_rs.stop_order
        ''',
        [startName, startTownship, endName, endTownship],
      );
      return rows
          .map((r) => (r['route_id'] as String?) ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Name-only directional lookup (no township disambiguation available).
  ///
  /// Used by entry points that only have the raw stop names typed by the user
  /// (Re-plan, Assistant). It matches EVERY township/platform variant of each
  /// name and relies solely on stop_order to enforce the forward direction, so
  /// a same-name / same-road opposite-platform stop is correctly handled: only
  /// the (start, end) pairing that actually runs forward on a line is returned.
  Future<List<String>> directRouteIdsByName({
    required String startName,
    required String endName,
  }) async {
    final db = _db;
    if (db == null) return const [];
    try {
      final rows = await db.rawQuery(
        '''
        SELECT DISTINCT r.route_id AS route_id
        FROM route_stops start_rs
        JOIN bus_stops start_stops ON start_rs.stop_id = start_stops.stop_id
        JOIN route_stops end_rs ON start_rs.route_id = end_rs.route_id
        JOIN bus_stops end_stops ON end_rs.stop_id = end_stops.stop_id
        JOIN routes r ON start_rs.route_id = r.route_id
        WHERE start_stops.stop_name_mm = ?
          AND end_stops.stop_name_mm = ?
          AND start_rs.stop_order < end_rs.stop_order
        ''',
        [startName, endName],
      );
      return rows
          .map((r) => (r['route_id'] as String?) ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
