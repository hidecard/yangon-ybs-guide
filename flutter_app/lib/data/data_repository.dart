import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart' show BusRoute, BusStop;
import 'route_finder.dart' show resolveStopByName;
import 'routes_crypto.dart' show xorBytes;
import 'sqlite_routes.dart' show SqliteRoutes;

/// Loads and caches all YBS route/stop data.
///
/// The route data is bundled as an encrypted binary blob (`assets/routes.bin`,
/// gzip + XOR) so the plain JSON is not readable by simply unzipping the APK.
/// On first launch the blob is decoded, parsed and cached in SharedPreferences
/// so the app works fully offline afterwards.
class DataRepository {
  DataRepository._();
  static final DataRepository instance = DataRepository._();

  static const _cacheKey = 'ybs-local-cache-v1';

  List<BusRoute> routes = [];
  List<BusStop> stops = [];
  bool loaded = false;

  /// Deterministic color from an id (same algorithm as web generateColor).
  static Color _generateColor(String id) {
    int hash = 0;
    for (int i = 0; i < id.length; i++) {
      hash = id.codeUnitAt(i) + ((hash << 5) - hash);
      hash = hash & 0xFFFFFFFF; // keep 32-bit like JS bitwise
    }
    final c = (hash & 0x00FFFFFF);
    return Color(0xFF000000 | c);
  }

  Future<void> load({bool forceReload = false}) async {
    if (loaded && !forceReload) return;

    // 1) Previously cached data (works offline, no re-decrypt).
    if (!forceReload) {
      final ok = await _loadCache();
      if (ok) {
        loaded = true;
        return;
      }
    }

    // 2) Decode the encrypted bundled blob.
    try {
      await _loadFromBundle();
      if (routes.isNotEmpty) {
        await _saveCache();
        // Materialize the local SQLite database (first launch only) so
        // direct-route searches run as real JOIN queries offline.
        try {
          await SqliteRoutes.instance.open(routes);
        } catch (e) {
          debugPrint('SQLite build skipped: $e');
        }
        loaded = true;
        return;
      }
    } catch (e) {
      debugPrint('Bundle load failed: $e');
    }

    // 3) Last resort: reuse a previously saved cache even if stale.
    loaded = await _loadCache();
  }

  /// Reads [assets/routes.bin], base64-decodes, XOR-decrypts, gunzips and
  /// parses the packed route JSON files.
  Future<void> _loadFromBundle() async {
    final b64 = await rootBundle.loadString('assets/routes.bin');
    final encrypted = base64.decode(b64);
    final gzipped = xorBytes(Uint8List.fromList(encrypted));
    final packed = gzip.decode(gzipped) as Uint8List;
    final entries = (json.decode(utf8.decode(packed)) as List)
        .cast<Map<String, dynamic>>();

    final Set<String> usedIds = {};
    final List<BusRoute> loadedRoutes = [];
    final Map<String, BusStop> stopsMap = {};
    int stopIdCounter = 1;

    for (final entry in entries) {
      final name = entry['name'] as String? ?? '';
      final data = json.decode(entry['json'] as String) as Map<String, dynamic>;

      final routeIdRaw = data['bus_line']?.toString() ??
          name.replaceFirst('ybs_', '').replaceFirst('_data.json', '');
      String routeId = routeIdRaw.trim();
      if (usedIds.contains(routeId)) {
        final suffix = name
            .replaceFirst('ybs_', '')
            .replaceFirst('_data.json', '')
            .replaceFirst(RegExp(r'^\d+_'), '');
        routeId = '${routeId}_$suffix';
      }
      usedIds.add(routeId);

      final List<String> stopNames = [];
      final List<BusStop> detailedStops = [];

      final rawStops = data['stops'];
      if (rawStops is List) {
        for (int idx = 0; idx < rawStops.length; idx++) {
          final stop = rawStops[idx] as Map<String, dynamic>;
          final nameMm = stop['stop_name_mm']?.toString();
          final nameEn = stop['stop_name_en']?.toString();
          final lat = stop['latitude'];
          final lng = stop['longitude'];

          if (nameMm != null && nameMm.isNotEmpty) {
            stopNames.add(nameMm);
          }

          if (nameMm != null &&
              nameEn != null &&
              lat != null &&
              lng != null) {
            final roadStr = stop['road']?.toString() ?? '';
            final roadParts =
                roadStr.isEmpty ? ['', ''] : roadStr.split(',');
            final road = roadParts.isNotEmpty ? roadParts[0].trim() : '';
            final township = roadParts.length > 1
                ? roadParts[1].trim()
                : (roadParts.isNotEmpty ? roadParts[0].trim() : '');

            final ds = BusStop(
              id: idx + 1,
              lat: (lat as num).toDouble(),
              lng: (lng as num).toDouble(),
              nameEn: nameEn,
              nameMm: nameMm,
              roadEn: road,
              roadMm: road,
              townshipEn: township,
              townshipMm: township,
            );
            detailedStops.add(ds);

            final key = '${nameMm}_${ds.lat}_${ds.lng}';
            if (!stopsMap.containsKey(key)) {
              stopsMap[key] = BusStop(
                id: stopIdCounter++,
                lat: ds.lat,
                lng: ds.lng,
                nameEn: nameEn,
                nameMm: nameMm,
                roadEn: road,
                roadMm: road,
                townshipEn: township,
                townshipMm: township,
              );
            }
          }
        }
      }

      final routeInfo =
          (data['route_info'] as Map<String, dynamic>?) ?? const {};

      loadedRoutes.add(BusRoute(
        id: routeId,
        color: _generateColor(routeId),
        operator: (routeInfo['Agency']?.toString().isNotEmpty ?? false)
            ? routeInfo['Agency'].toString()
            : '',
        lineName: routeInfo['Line Name']?.toString(),
        qrPayment: routeInfo['QR Payment']?.toString(),
        stops: stopNames,
        stopsDetailed: detailedStops,
      ));
    }

    routes = loadedRoutes;
    stops = stopsMap.values.toList();
  }

  Future<bool> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return false;
      final cache = json.decode(raw) as Map<String, dynamic>;
      routes = (cache['routes'] as List)
          .map((e) => BusRoute.fromJson(e as Map<String, dynamic>))
          .toList();
      stops = (cache['stops'] as List)
          .map((e) => BusStop.fromJson(e as Map<String, dynamic>))
          .toList();
      return routes.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = json.encode({
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'routes': routes.map((r) => r.toJson()).toList(),
        'stops': stops.map((s) => s.toJson()).toList(),
      });
      await prefs.setString(_cacheKey, data);
    } catch (_) {}
  }

  Future<String?> cacheInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return null;
    final bytes = utf8.encode(raw).length;
    final size = bytes > 1024 * 1024
        ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '${(bytes / 1024).toStringAsFixed(0)} KB';
    return size;
  }

  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    loaded = false;
    routes = [];
    stops = [];
  }

  BusRoute? routeById(String id) {
    for (final r in routes) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Direct-route search: returns every loaded route that passes through
  /// [startName] before [endName] in stop order (correct forward direction
  /// only). Matching is by Burmese stop name, with an English fallback.
  ///
  /// [startStop]/[endStop] are optional precise stops (with coordinates). When
  /// supplied they disambiguate same-named stops — the route is only a match
  /// if it physically contains the chosen stop on the forward (start → end)
  /// leg, so the backward/different-area duplicate of a name is never returned.
  ///
  /// When the local SQLite database is available the search runs as a JOIN
  /// query keyed by stop group (name + township), matching the production
  /// schema. Falls back to the in-memory scan if SQLite is unavailable.
  Future<List<BusRoute>> findDirectRoutes(
    String startName,
    String endName, {
    BusStop? startStop,
    BusStop? endStop,
  }) async {
    final start = startName.trim();
    final end = endName.trim();
    if (start.isEmpty || end.isEmpty) return const [];

    // Prefer the SQLite JOIN query (keyed by stop group = name + township).
    // The directional query resolves same-name / same-road opposite-platform
    // stops purely by stop_order, so we never need a locked stop_id.
    final byId = {for (final r in routes) r.id: r};

    if (startStop != null && endStop != null) {
      // Precise path: the exact chosen stops disambiguate by township.
      final ids = await SqliteRoutes.instance.directRouteIds(
        startName: startStop.nameMm,
        startTownship: startStop.townshipMm,
        endName: endStop.nameMm,
        endTownship: endStop.townshipMm,
      );
      final found =
          ids.where(byId.containsKey).map((id) => byId[id]!).toList();
      if (found.isNotEmpty) return found;
    } else {
      // Name-only path (Re-plan / Assistant): run the directional query by
      // name across every township variant of each name. stop_order still
      // guarantees the correct forward direction, so opposite-platform
      // duplicates on the same road are handled at the DB layer.
      final ids = await SqliteRoutes.instance.directRouteIdsByName(
        startName: start,
        endName: end,
      );
      final found =
          ids.where(byId.containsKey).map((id) => byId[id]!).toList();
      if (found.isNotEmpty) return found;
    }

    // In-memory fallback (also handles the SQLite-unavailable case).
    return _findDirectRoutesInMemory(start, end, startStop, endStop);
  }

  List<BusRoute> _findDirectRoutesInMemory(
    String start,
    String end,
    BusStop? startStop,
    BusStop? endStop,
  ) {
    final effectiveStart = startStop ?? resolveStopByName(start, stops, hint: endStop == null ? null : (lat: endStop.lat, lng: endStop.lng));
    final effectiveEnd = endStop ?? resolveStopByName(end, stops, hint: startStop == null ? null : (lat: startStop.lat, lng: startStop.lng));
    // Collect matches with their shortest forward span so out-and-back (loop)
    // routes resolve to the correct segment and we can rank shortest-first,
    // mirroring the SQLite MIN(gap) query and the detail page's _findLeg.
    final scored = <({BusRoute route, int gap})>[];
    for (final r in routes) {
      final startIdxs = <int>[];
      final endIdxs = <int>[];
      for (int i = 0; i < r.stopsDetailed.length; i++) {
        final s = r.stopsDetailed[i];
        if (_stopMatches(s, start, effectiveStart)) startIdxs.add(i);
        if (_stopMatches(s, end, effectiveEnd)) endIdxs.add(i);
      }
      if (startIdxs.isEmpty || endIdxs.isEmpty) continue;
      int bestGap = 1 << 30;
      for (final f in startIdxs) {
        for (final t in endIdxs) {
          if (t > f && (t - f) < bestGap) bestGap = t - f;
        }
      }
      if (bestGap != 1 << 30) scored.add((route: r, gap: bestGap));
    }
    scored.sort((a, b) => a.gap.compareTo(b.gap));
    return scored.map((e) => e.route).toList();
  }

  /// Match a detailed stop against [name], preferring the [hint] stop's exact
  /// coordinates when several detailed stops share [name].
  bool _stopMatches(BusStop s, String name, BusStop? hint) {
    if (s.nameMm != name && s.nameEn != name) return false;
    if (hint == null) return true;
    // Require the coordinate to match the chosen physical stop so that a
    // duplicate name on the reverse leg / in another area is not matched.
    return (s.lat - hint.lat).abs() < 1e-6 &&
        (s.lng - hint.lng).abs() < 1e-6;
  }
}
