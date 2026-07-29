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
      CREATE VIRTUAL TABLE IF NOT EXISTS routes_fts USING fts5(
        route_id UNINDEXED,
        bus_line,
        agency,
        line_name,
        qr_payment,
        content=routes,
        content_rowid=rowid
      )
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS routes_ai AFTER INSERT ON routes BEGIN
        INSERT INTO routes_fts(rowid, route_id, bus_line, agency, line_name, qr_payment)
        VALUES (new.rowid, new.route_id, new.bus_line, new.agency, new.line_name, new.qr_payment);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS routes_ad AFTER DELETE ON routes BEGIN
        INSERT INTO routes_fts(routes_fts, rowid, route_id, bus_line, agency, line_name, qr_payment)
        VALUES ('delete', old.rowid, old.route_id, old.bus_line, old.agency, old.line_name, old.qr_payment);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS routes_au AFTER UPDATE ON routes BEGIN
        INSERT INTO routes_fts(routes_fts, rowid, route_id, bus_line, agency, line_name, qr_payment)
        VALUES ('delete', old.rowid, old.route_id, old.bus_line, old.agency, old.line_name, old.qr_payment);
        INSERT INTO routes_fts(rowid, route_id, bus_line, agency, line_name, qr_payment)
        VALUES (new.rowid, new.route_id, new.bus_line, new.agency, new.line_name, new.qr_payment);
      END
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
      CREATE VIRTUAL TABLE IF NOT EXISTS bus_stops_fts USING fts5(
        stop_id UNINDEXED,
        group_id UNINDEXED,
        stop_name_en,
        stop_name_mm,
        road,
        township,
        content=bus_stops,
        content_rowid=rowid
      )
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS bus_stops_ai AFTER INSERT ON bus_stops BEGIN
        INSERT INTO bus_stops_fts(rowid, stop_id, group_id, stop_name_en, stop_name_mm, road, township)
        VALUES (new.rowid, new.stop_id, new.group_id, new.stop_name_en, new.stop_name_mm, new.road, new.township);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS bus_stops_ad AFTER DELETE ON bus_stops BEGIN
        INSERT INTO bus_stops_fts(bus_stops_fts, rowid, stop_id, group_id, stop_name_en, stop_name_mm, road, township)
        VALUES ('delete', old.rowid, old.stop_id, old.group_id, old.stop_name_en, old.stop_name_mm, old.road, old.township);
      END
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS bus_stops_au AFTER UPDATE ON bus_stops BEGIN
        INSERT INTO bus_stops_fts(bus_stops_fts, rowid, stop_id, group_id, stop_name_en, stop_name_mm, road, township)
        VALUES ('delete', old.rowid, old.stop_id, old.group_id, old.stop_name_en, old.stop_name_mm, old.road, old.township);
        INSERT INTO bus_stops_fts(rowid, stop_id, group_id, stop_name_en, stop_name_mm, road, township)
        VALUES (new.rowid, new.stop_id, new.group_id, new.stop_name_en, new.stop_name_mm, new.road, new.township);
      END
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
      // For each route we take only the SHORTEST forward span between the two
      // groups (MIN of end_order - start_order). YBS routes store the forward
      // + return legs under one route_id, so the same name appears at two very
      // different stop_orders; the shortest span is always the correct
      // (non-loop-around) segment. GROUP BY + MIN gives per-route ranking
      // without window functions, so it runs on old-device SQLite too.
      final rows = await db.rawQuery(
        '''
        SELECT r.route_id AS route_id,
               MIN(end_rs.stop_order - start_rs.stop_order) AS gap
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
        GROUP BY r.route_id
        ORDER BY gap ASC
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
        SELECT r.route_id AS route_id,
               MIN(end_rs.stop_order - start_rs.stop_order) AS gap
        FROM route_stops start_rs
        JOIN bus_stops start_stops ON start_rs.stop_id = start_stops.stop_id
        JOIN route_stops end_rs ON start_rs.route_id = end_rs.route_id
        JOIN bus_stops end_stops ON end_rs.stop_id = end_stops.stop_id
        JOIN routes r ON start_rs.route_id = r.route_id
        WHERE start_stops.stop_name_mm = ?
          AND end_stops.stop_name_mm = ?
          AND start_rs.stop_order < end_rs.stop_order
        GROUP BY r.route_id
        ORDER BY gap ASC
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

  /// Full-text search on stop names using FTS5.
  ///
  /// Returns matching stops ranked by FTS5 relevance (bm25).
  /// Supports both Burmese and English stop names.
  Future<List<Map<String, dynamic>>> searchStopsFTS({
    required String query,
    int limit = 20,
  }) async {
    final db = _db;
    if (db == null) return const [];
    try {
      final q = query.trim().replaceAll("'", "''");
      if (q.isEmpty) return const [];
      final rows = await db.rawQuery(
        '''
        SELECT b.stop_id, b.stop_name_mm, b.stop_name_en, b.road, b.township,
               b.latitude, b.longitude, b.group_id,
               bm25(bus_stops_fts, 10.0, 10.0, 1.0, 1.0) as score
        FROM bus_stops_fts
        JOIN bus_stops b ON bus_stops_fts.stop_id = b.stop_id
        WHERE bus_stops_fts MATCH ?
        ORDER BY score ASC
        LIMIT ?
        ''',
        ['$q*', limit],
      );
      return rows.map((r) => {
            'stop_id': r['stop_id'] as int,
            'stop_name_mm': r['stop_name_mm'] as String?,
            'stop_name_en': r['stop_name_en'] as String?,
            'road': r['road'] as String?,
            'township': r['township'] as String?,
            'latitude': r['latitude'] as double?,
            'longitude': r['longitude'] as double?,
            'group_id': r['group_id'] as int?,
            'score': (r['score'] as num?)?.toDouble() ?? 0.0,
          }).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Full-text search on route names using FTS5.
  Future<List<Map<String, dynamic>>> searchRoutesFTS({
    required String query,
    int limit = 20,
  }) async {
    final db = _db;
    if (db == null) return const [];
    try {
      final q = query.trim().replaceAll("'", "''");
      if (q.isEmpty) return const [];
      final rows = await db.rawQuery(
        '''
        SELECT r.route_id, r.bus_line, r.agency, r.line_name, r.qr_payment,
               bm25(routes_fts, 10.0, 10.0, 1.0, 1.0, 1.0) as score
        FROM routes_fts
        JOIN routes r ON routes_fts.route_id = r.route_id
        WHERE routes_fts MATCH ?
        ORDER BY score ASC
        LIMIT ?
        ''',
        ['$q*', limit],
      );
      return rows.map((r) => {
            'route_id': r['route_id'] as String,
            'bus_line': r['bus_line'] as String,
            'agency': r['agency'] as String?,
            'line_name': r['line_name'] as String?,
            'qr_payment': r['qr_payment'] as String?,
            'score': (r['score'] as num?)?.toDouble() ?? 0.0,
          }).toList();
    } catch (_) {
      return const [];
    }
  }
}
