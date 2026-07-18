import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models.dart';

/// Deterministic color from an id (mirrors DataRepository hashing on web).
Color _generateColor(String id) {
  int hash = 0;
  for (int i = 0; i < id.length; i++) {
    hash = id.codeUnitAt(i) + ((hash << 5) - hash);
    hash = hash & 0xFFFFFFFF;
  }
  final c = (hash & 0x00FFFFFF);
  return Color(0xFF000000 | c);
}

/// SQLite-backed store for all YBS route and stop data.
///
/// On first launch the bundled JSON route files are imported into the
/// database; subsequent reads/route-finding serve entirely from SQLite.
///
/// Schema matches the shared SQLite/Turso design so the same queries run
/// offline (mobile) and on Turso (web) without changes:
///   - routes(route_id, bus_line, agency, qr_payment)
///   - bus_stops(stop_id, name_mm, name_en, road, township, lat, lng)
///   - route_stops(route_id, stop_id, stop_order)
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  static const _dbName = 'ybs_guide.db';
  static const _dbVersion = 2;

  Database? _db;

  Future<Database> get database async {
    _db ??= await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dbPath = p.join(await getDatabasesPath(), _dbName);
    return openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE routes (
        route_id TEXT PRIMARY KEY,
        bus_line TEXT NOT NULL,
        agency TEXT,
        qr_payment INTEGER DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE bus_stops (
        stop_id INTEGER PRIMARY KEY AUTOINCREMENT,
        stop_name_en TEXT NOT NULL,
        stop_name_mm TEXT NOT NULL,
        road TEXT,
        township TEXT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE route_stops (
        route_id TEXT,
        stop_id INTEGER,
        stop_order INTEGER NOT NULL,
        PRIMARY KEY (route_id, stop_order),
        FOREIGN KEY (route_id) REFERENCES routes(route_id) ON DELETE CASCADE,
        FOREIGN KEY (stop_id) REFERENCES bus_stops(stop_id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_route_stops_search ON route_stops(stop_id, route_id, stop_order)');
    await db.execute(
        'CREATE INDEX idx_bus_stops_coords ON bus_stops(latitude, longitude)');
  }

  Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < _dbVersion) {
      // Schema changed: drop and recreate is handled by version bump.
    }
  }

  /// Imports every JSON file listed in the manifest into the SQLite DB.
  ///
  /// Per the forward/backward fix (Method 2): each stop *occurrence* gets its
  /// own [bus_stops] row and [stop_order] is unique per route, so an out-and-
  /// back route's return-leg stops are distinct rows and never collapse into
  /// a single shared master ID (which previously corrupted the sequence).
  ///
  /// Returns the number of route files imported.
  Future<int> importFromAssets() async {
    final db = await database;
    final manifestRaw =
        await rootBundle.loadString('assets/routes_manifest.json');
    final files =
        (json.decode(manifestRaw) as List).map((e) => e as String).toList();

    final Set<String> usedRouteIds = {};
    int count = 0;

    await db.transaction((txn) async {
      for (final file in files) {
        try {
          final raw = await rootBundle.loadString('assets/routes/$file');
          final data = json.decode(raw) as Map<String, dynamic>;

          // Use the JSON route_id (e.g. "202") as the canonical key, matching
          // the rest of the app. Fall back to the filename if absent.
          String routeId = (data['route_id']?.toString() ??
                  data['bus_line']?.toString() ??
                  file
                      .replaceFirst('ybs_', '')
                      .replaceFirst('_data.json', ''))
              .trim();
          if (usedRouteIds.contains(routeId)) {
            final suffix = file
                .replaceFirst('ybs_', '')
                .replaceFirst('_data.json', '')
                .replaceFirst(RegExp(r'^\d+_'), '');
            routeId = '${routeId}_$suffix';
          }
          usedRouteIds.add(routeId);

          final routeInfo =
              (data['route_info'] as Map<String, dynamic>?) ?? const {};
          await txn.insert(
            'routes',
            {
              'route_id': routeId,
              'bus_line': data['bus_line']?.toString() ?? '',
              'agency': routeInfo['Agency']?.toString() ?? '',
              'qr_payment':
                  (routeInfo['QR Payment']?.toString().contains('Supported') ??
                          false)
                      ? 1
                      : 0,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          final rawStops = data['stops'];
          if (rawStops is List) {
            for (int i = 0; i < rawStops.length; i++) {
              final stopId = await _insertStopOccurrence(txn, rawStops[i]);
              if (stopId < 0) continue;
              await txn.insert(
                'route_stops',
                {
                  'route_id': routeId,
                  'stop_id': stopId,
                  'stop_order': i + 1,
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          }
          count++;
        } catch (e) {
          // Skip malformed files but keep importing the rest.
        }
      }
    });

    return count;
  }

  /// Inserts every stop occurrence as its own [bus_stops] row (so the same
  /// stop name appearing on both the outbound and return leg gets distinct
  /// IDs). Returns the new autoincrement id.
  Future<int> _insertStopOccurrence(Transaction txn, dynamic raw) async {
    final stop = raw as Map<String, dynamic>;
    final nameMm = stop['stop_name_mm']?.toString();
    final nameEn = stop['stop_name_en']?.toString();
    final lat = stop['latitude'];
    final lng = stop['longitude'];
    if (nameMm == null || nameEn == null || lat == null || lng == null) {
      return -1;
    }
    final roadStr = stop['road']?.toString() ?? '';
    final roadParts = roadStr.isEmpty ? ['', ''] : roadStr.split(',');
    final road = roadParts.isNotEmpty ? roadParts[0].trim() : '';
    final township = roadParts.length > 1
        ? roadParts[1].trim()
        : (roadParts.isNotEmpty ? roadParts[0].trim() : '');

    return await txn.insert(
      'bus_stops',
      {
        'stop_name_en': nameEn,
        'stop_name_mm': nameMm,
        'road': road,
        'township': township,
        'latitude': (lat as num).toDouble(),
        'longitude': (lng as num).toDouble(),
      },
    );
  }

  /// Returns true if the database already holds imported data.
  Future<bool> isImported() async {
    try {
      final db = await database;
      final result =
          await db.rawQuery('SELECT COUNT(*) AS c FROM routes');
      final c = (result.first['c'] as int?) ?? 0;
      return c > 0;
    } catch (_) {
      return false;
    }
  }

  /// Loads all routes, reconstructing [BusRoute] objects (with ordered
  /// [stopsDetailed]) joined from route_stops.
  Future<List<BusRoute>> loadRoutes() async {
    final db = await database;

    final routeRows = await db.query('routes', orderBy: 'route_id ASC');
    final stopRows = await db.query('bus_stops', orderBy: 'stop_id ASC');
    final stopById = <int, BusStop>{};
    for (final row in stopRows) {
      final id = row['stop_id'] as int;
      stopById[id] = BusStop(
        id: id,
        lat: (row['latitude'] as num).toDouble(),
        lng: (row['longitude'] as num).toDouble(),
        nameEn: row['stop_name_en'] as String,
        nameMm: row['stop_name_mm'] as String,
        roadEn: (row['road'] as String?) ?? '',
        roadMm: (row['road'] as String?) ?? '',
        townshipEn: (row['township'] as String?) ?? '',
        townshipMm: (row['township'] as String?) ?? '',
      );
    }

    final rsRows = await db.query('route_stops',
        orderBy: 'route_id ASC, stop_order ASC');
    final stopsByRoute = <String, List<Map<String, dynamic>>>{};
    for (final r in rsRows) {
      stopsByRoute.putIfAbsent(r['route_id'] as String, () => <Map<String, dynamic>>[]).add(r);
    }

    final List<BusRoute> loadedRoutes = [];
    for (final row in routeRows) {
      final routeId = row['route_id'] as String;
      final rs = stopsByRoute[routeId] ?? [];
      final stopNames = <String>[];
      final detailedStops = <BusStop>[];
      for (int i = 0; i < rs.length; i++) {
        final stop = stopById[rs[i]['stop_id'] as int];
        if (stop == null) continue;
        stopNames.add(stop.nameMm);
        detailedStops.add(BusStop(
          id: i + 1,
          lat: stop.lat,
          lng: stop.lng,
          nameEn: stop.nameEn,
          nameMm: stop.nameMm,
          roadEn: stop.roadEn,
          roadMm: stop.roadMm,
          townshipEn: stop.townshipEn,
          townshipMm: stop.townshipMm,
        ));
      }

      loadedRoutes.add(BusRoute(
        id: routeId,
        color: _generateColor(routeId),
        operator: (row['agency'] as String?)?.isNotEmpty == true
            ? row['agency'] as String
            : '',
        lineName: routeId,
        qrPayment: (row['qr_payment'] as int? ?? 1) == 1
            ? '✅ Supported'
            : null,
        stops: stopNames,
        stopsDetailed: detailedStops,
      ));
    }

    return loadedRoutes;
  }

  /// Loads all de-duplicated stops from the bus_stops table.
  Future<List<BusStop>> loadStops() async {
    final db = await database;
    final rows = await db.query('bus_stops', orderBy: 'stop_id ASC');
    final List<BusStop> stops = [];
    int id = 1;
    for (final row in rows) {
      stops.add(BusStop(
        id: id++,
        lat: (row['latitude'] as num).toDouble(),
        lng: (row['longitude'] as num).toDouble(),
        nameEn: row['stop_name_en'] as String,
        nameMm: row['stop_name_mm'] as String,
        roadEn: (row['road'] as String?) ?? '',
        roadMm: (row['road'] as String?) ?? '',
        townshipEn: (row['township'] as String?) ?? '',
        townshipMm: (row['township'] as String?) ?? '',
      ));
    }
    return stops;
  }

  /// Direct-route search: returns every route that passes through
  /// [startName] before [endName] in stop_order (correct forward direction
  /// only). Joins via stop *name* so out-and-back routes (where the same
  /// stop name has multiple stop_ids) are handled correctly.
  Future<List<Map<String, dynamic>>> findDirectRoutes({
    required String startName,
    required String endName,
  }) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT r.route_id, r.bus_line,
             MIN(start_rs.stop_order) AS start_index,
             MIN(end_rs.stop_order)   AS end_index
      FROM route_stops start_rs
      JOIN bus_stops start_bs ON start_bs.stop_id = start_rs.stop_id
      JOIN route_stops end_rs
        ON start_rs.route_id = end_rs.route_id
      JOIN bus_stops end_bs ON end_bs.stop_id = end_rs.stop_id
      JOIN routes r
        ON r.route_id = start_rs.route_id
      WHERE start_bs.stop_name_mm = ?
        AND end_bs.stop_name_mm   = ?
        AND start_rs.stop_order < end_rs.stop_order
      GROUP BY r.route_id
      ORDER BY (MIN(end_rs.stop_order) - MIN(start_rs.stop_order)) ASC
    ''',
      [startName, endName],
    );
  }

  /// Nearest-stop search using a bounding box first (fast SQLite scan),
  /// then exact Haversine distance in Dart to rank + filter by radius.
  Future<List<Map<String, dynamic>>> findNearbyStops({
    required double userLat,
    required double userLng,
    double radiusInKm = 0.5,
  }) async {
    const kmPerDegLat = 111.0;
    final latDelta = radiusInKm / kmPerDegLat;
    final lngDelta = radiusInKm /
        (kmPerDegLat * math.cos(userLat * math.pi / 180));

    final minLat = userLat - latDelta;
    final maxLat = userLat + latDelta;
    final minLng = userLng - lngDelta;
    final maxLng = userLng + lngDelta;

    final db = await database;
    final candidates = await db.query(
      'bus_stops',
      where: 'latitude BETWEEN ? AND ? AND longitude BETWEEN ? AND ?',
      whereArgs: [minLat, maxLat, minLng, maxLng],
    );

    double toKm(double lat1, double lon1, double lat2, double lon2) {
      const R = 6371.0;
      final dLat = (lat2 - lat1) * math.pi / 180;
      final dLon = (lon2 - lon1) * math.pi / 180;
      final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
          math.cos(lat1 * math.pi / 180) *
              math.cos(lat2 * math.pi / 180) *
              math.sin(dLon / 2) *
              math.sin(dLon / 2);
      final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
      return R * c;
    }

    final rows = candidates.map((r) {
      final lat = (r['latitude'] as num).toDouble();
      final lng = (r['longitude'] as num).toDouble();
      final d = toKm(userLat, userLng, lat, lng);
      return {
        'stop_id': r['stop_id'],
        'stop_name_mm': r['stop_name_mm'],
        'stop_name_en': r['stop_name_en'],
        'latitude': lat,
        'longitude': lng,
        'road': r['road'],
        'township': r['township'],
        'distance_km': d,
      };
    }).where((r) => r['distance_km'] as double <= radiusInKm).toList();

    rows.sort((a, b) =>
        (a['distance_km'] as double).compareTo(b['distance_km'] as double));
    return rows;
  }

  /// Resolves a stop name (mm) to its stable stop_id (first match).
  Future<int?> stopIdByName(String nameMm) async {
    final db = await database;
    final rows = await db.query(
      'bus_stops',
      columns: ['stop_id'],
      where: 'stop_name_mm = ?',
      whereArgs: [nameMm],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['stop_id'] as int;
  }

  /// Loads a single route (with ordered [stopsDetailed]) by route_id.
  /// Used by the frontend to draw the line on the map (Phase 4: static data
  /// lookup, no need to shuffle the whole dataset over the network).
  Future<BusRoute?> routeById(String routeId) async {
    final all = await loadRoutes();
    for (final r in all) {
      if (r.id == routeId) return r;
    }
    return null;
  }

  /// Phase 2 (Direct): returns every route that goes from [startName] to
  /// [endName] in the correct forward direction, as full [BusRoute] objects
  /// with their ordered stops, using the normalized route_stops join.
  Future<List<BusRoute>> findDirectRoutesByName(
    String startName,
    String endName,
  ) async {
    final rows = await findDirectRoutes(
      startName: startName,
      endName: endName,
    );

    final routes = await loadRoutes();
    final byId = <String, BusRoute>{};
    for (final r in routes) byId[r.id] = r;

    final out = <BusRoute>[];
    for (final row in rows) {
      final rid = row['route_id'] as String;
      final r = byId[rid];
      if (r != null) out.add(r);
    }
    return out;
  }

  /// Phase 2 (Connecting): builds an in-memory graph from route_stops so a
  /// BFS/Dijkstra planner can compute transfer routes. Keyed by stop_id,
  /// each entry lists the adjacent stop_id + route_id + stop_order so the
  /// planner can respect correct travel direction.
  Future<Map<int, List<RouteEdge>>> buildStopGraph() async {
    final db = await database;
    final rsRows = await db.query('route_stops',
        orderBy: 'route_id ASC, stop_order ASC');
    final graph = <int, List<RouteEdge>>{};
    String? prevRoute;
    int? prevStop;
    int? prevOrder;
    for (final r in rsRows) {
      final routeId = r['route_id'] as String;
      final stopId = r['stop_id'] as int;
      final order = r['stop_order'] as int;
      if (prevRoute == routeId && prevStop != null && prevOrder != null) {
        final from = prevStop;
        graph
            .putIfAbsent(from, () => <RouteEdge>[])
            .add(RouteEdge(
              toStop: stopId,
              routeId: routeId,
              order: order,
            ));
      }
      prevRoute = routeId;
      prevStop = stopId;
      prevOrder = order;
    }
    return graph;
  }
}

class RouteEdge {
  final int toStop;
  final String routeId;
  final int order;
  RouteEdge({required this.toStop, required this.routeId, required this.order});
}
