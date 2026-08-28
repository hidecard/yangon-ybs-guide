import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../train_models.dart';

class TrainDataRepository {
  TrainDataRepository._();
  static final instance = TrainDataRepository._();

  List<TrainRoute> routes = const [];
  List<TrainStation> stations = const [];
  bool loaded = false;

  Future<void> load() async {
    if (loaded) return;
    final routeRaw = json.decode(
      await rootBundle.loadString('assets/train/route_details.json'),
    );
    final stationRaw = json.decode(
      await rootBundle.loadString('assets/train/station_details.json'),
    );
    if (routeRaw is! List || stationRaw is! List) {
      throw const FormatException('Train data must be JSON arrays');
    }
    routes = routeRaw
        .whereType<Map>()
        .map((item) => TrainRoute.fromJson(Map<String, dynamic>.from(item)))
        .where(
          (route) => route.slug.isNotEmpty && route.stationSchedules.isNotEmpty,
        )
        .toList(growable: false);
    stations = stationRaw
        .whereType<Map>()
        .map((item) => TrainStation.fromJson(Map<String, dynamic>.from(item)))
        .where((station) => station.slug.isNotEmpty)
        .toList(growable: false);
    loaded = routes.isNotEmpty && stations.isNotEmpty;
    if (!loaded) throw const FormatException('Train data is empty');
  }

  TrainRoute? routeBySlug(String slug) {
    for (final route in routes) {
      if (route.slug == slug) return route;
    }
    return null;
  }

  TrainStation? stationBySlug(String slug) {
    for (final station in stations) {
      if (station.slug == slug) return station;
    }
    return null;
  }

  List<TrainRoute> searchRoutes(String query, {String? type}) {
    final term = query.trim().toLowerCase();
    return routes
        .where((route) {
          final matchesType =
              type == null || type.isEmpty || route.type == type;
          if (!matchesType) return false;
          if (term.isEmpty) return true;
          return [
            route.title,
            route.routeTypeTitle,
            route.originStation,
            route.destinationStation,
            route.trainModel,
            route.type,
            route.direction,
          ].join(' ').toLowerCase().contains(term);
        })
        .toList(growable: false);
  }

  List<TrainStation> searchStations(String query) {
    final term = query.trim().toLowerCase();
    if (term.isEmpty) return stations;
    return stations
        .where((station) {
          return [
            station.title,
            station.description,
          ].join(' ').toLowerCase().contains(term);
        })
        .toList(growable: false);
  }

  List<TrainRouteSchedule> departuresFor(TrainStation station) {
    final all = station.departures;
    final seen = <String>{};
    return all
        .where(
          (item) => seen.add('${item.slug}|${item.time}|${item.direction}'),
        )
        .toList();
  }
}
