import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart' show BusRoute, BusStop;
import 'database_service.dart';

/// Loads and caches all YBS route/stop data from bundled JSON assets.
///
/// Mirrors the web app's data_constants.ts (color hashing, road parsing,
/// stop de-duplication and the local cache mechanism).
class DataRepository {
  DataRepository._();
  static final DataRepository instance = DataRepository._();

  static const _cacheKey = 'ybs-local-cache-v1';

  List<BusRoute> routes = [];
  List<BusStop> stops = [];
  bool loaded = false;

  Future<List<String>> _manifest() async {
    final raw = await rootBundle.loadString('assets/routes_manifest.json');
    final list = json.decode(raw) as List;
    return list.map((e) => e as String).toList();
  }

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

  Future<void> _parseFiles() async {
    final files = await _manifest();
    final Set<String> usedIds = {};
    final List<BusRoute> loadedRoutes = [];
    final Map<String, BusStop> stopsMap = {};
    int stopIdCounter = 1;

    for (final file in files) {
      try {
        final raw = await rootBundle.loadString('assets/routes/$file');
        final data = json.decode(raw) as Map<String, dynamic>;

        // Route id
        final routeIdRaw = data['bus_line']?.toString() ??
            file.replaceFirst('ybs_', '').replaceFirst('_data.json', '');
        String routeId = routeIdRaw.trim();
        if (usedIds.contains(routeId)) {
          final suffix = file
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
              final roadParts = roadStr.isEmpty ? ['', ''] : roadStr.split(',');
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

              // Global de-duplicated stops (matches loadStopsFromRouteFiles)
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
      } catch (e) {
        debugPrint('Error loading $file: $e');
      }
    }

    routes = loadedRoutes;
    stops = stopsMap.values.toList();
  }

  Future<void> load({bool forceReload = false}) async {
    if (loaded && !forceReload) return;

    // First launch: import all JSON assets into the SQLite DB, then read from it.
    if (!await DatabaseService.instance.isImported() || forceReload) {
      await DatabaseService.instance.importFromAssets();
    }

    try {
      final dbRoutes = await DatabaseService.instance.loadRoutes();
      final dbStops = await DatabaseService.instance.loadStops();
      if (dbRoutes.isNotEmpty) {
        routes = dbRoutes;
        stops = dbStops;
        loaded = true;
        return;
      }
    } catch (e) {
      debugPrint('DB load failed, falling back to assets: $e');
    }

    // Fallback: parse assets directly (also keeps old cache as a last resort).
    final cached = await _loadCache();
    if (cached && !forceReload) {
      loaded = true;
      _parseFiles().then((_) => _saveCache());
      return;
    }

    await _parseFiles();
    await _saveCache();
    loaded = true;
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
  }

  BusRoute? routeById(String id) {
    for (final r in routes) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Phase 2 (Direct): fast SQL-path lookup for routes that go from
  /// [startName] to [endName] in the correct forward direction. Returns full
  /// [BusRoute] objects read from the SQLite route_stops join.
  Future<List<BusRoute>> findDirectRoutes(String startName, String endName) =>
      DatabaseService.instance.findDirectRoutesByName(startName, endName);
}
