import 'dart:math' as math;

class BusStop {
  const BusStop({
    required this.id,
    required this.nameMm,
    required this.nameEn,
    required this.latitude,
    required this.longitude,
    required this.sequence,
    this.road = '',
  });

  final String id;
  final String nameMm;
  final String nameEn;
  final double latitude;
  final double longitude;
  final int sequence;
  final String road;

  double distanceTo(double lat, double lng) {
    const earthRadius = 6371000.0;
    final dLat = _radians(latitude - lat);
    final dLng = _radians(longitude - lng);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(lat)) *
            math.cos(_radians(latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _radians(double value) => value * math.pi / 180;
}

class BusRoute {
  const BusRoute({
    required this.id,
    required this.name,
    required this.stops,
    required this.assetName,
    this.operatorName = '',
  });

  final String id;
  final String name;
  final List<BusStop> stops;
  final String assetName;
  final String operatorName;
}

class TripState {
  const TripState({
    required this.route,
    required this.boardingStop,
    required this.destinationStop,
    this.latitude,
    this.longitude,
    this.currentIndex = 0,
    this.distanceToNextStop = 0,
  });

  final BusRoute route;
  final BusStop boardingStop;
  final BusStop destinationStop;
  final double? latitude;
  final double? longitude;
  final int currentIndex;
  final double distanceToNextStop;

  BusStop? get nextStop {
    final index = currentIndex + 1;
    return index < route.stops.length ? route.stops[index] : null;
  }

  int get remainingStops => math.max(0, destinationStop.sequence - currentIndex);

  TripState copyWith({
    double? latitude,
    double? longitude,
    int? currentIndex,
    double? distanceToNextStop,
  }) => TripState(
        route: route,
        boardingStop: boardingStop,
        destinationStop: destinationStop,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        currentIndex: currentIndex ?? this.currentIndex,
        distanceToNextStop: distanceToNextStop ?? this.distanceToNextStop,
      );
}
