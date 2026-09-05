import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/route_models.dart';

class RouteRepository {
  Future<List<BusRoute>> loadRoutes() async {
    final manifest = jsonDecode(
      await rootBundle.loadString('assets/routes/manifest.json'),
    ) as List<dynamic>;
    final routes = <BusRoute>[];
    for (final item in manifest) {
      final assetName = item.toString();
      if (assetName == 'manifest.json') continue;
      try {
        final raw = jsonDecode(
          await rootBundle.loadString('assets/routes/$assetName'),
        ) as Map<String, dynamic>;
        final rawStops = (raw['stops'] as List<dynamic>? ?? const []);
        final stops = <BusStop>[];
        for (var index = 0; index < rawStops.length; index++) {
          final stop = rawStops[index] as Map<String, dynamic>;
          final lat = _toDouble(stop['latitude']);
          final lng = _toDouble(stop['longitude']);
          if (lat == null || lng == null) continue;
          stops.add(BusStop(
            id: '${assetName}_$index',
            nameMm: '${stop['stop_name_mm'] ?? ''}',
            nameEn: '${stop['stop_name_en'] ?? ''}',
            latitude: lat,
            longitude: lng,
            sequence: index,
            road: '${stop['road'] ?? ''}',
          ));
        }
        if (stops.isEmpty) continue;
        final info = raw['route_info'] as Map<String, dynamic>? ?? const {};
        routes.add(BusRoute(
          id: '${raw['route_id'] ?? _routeId(assetName)}',
          name: '${info['Line Name'] ?? _routeId(assetName)}',
          operatorName: '${info['Agency'] ?? ''}',
          stops: stops,
          assetName: assetName,
        ));
      } catch (_) {
        // Ignore a malformed route and keep the rest of the V3 dataset usable.
      }
    }
    routes.sort((a, b) => _naturalCompare(a.id, b.id));
    return routes;
  }

  String _routeId(String assetName) => assetName
      .replaceFirst('ybs_', '')
      .replaceFirst(RegExp(r'_.*'), '')
      .replaceFirst('_data.json', '');

  double? _toDouble(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value');

  int _naturalCompare(String a, String b) {
    final an = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), '')) ?? 9999;
    final bn = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), '')) ?? 9999;
    return an != bn ? an.compareTo(bn) : a.compareTo(b);
  }
}
