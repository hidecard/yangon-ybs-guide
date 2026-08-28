import 'package:flutter/material.dart';

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

String _str(dynamic value) => value?.toString() ?? '';

double? _double(dynamic value) => double.tryParse(_str(value));

class TrainRouteSchedule {
  final String slug;
  final String title;
  final String routeTypeTitle;
  final String type;
  final String way;
  final String direction;
  final String trainModel;
  final String time;

  const TrainRouteSchedule({
    required this.slug,
    required this.title,
    required this.routeTypeTitle,
    required this.type,
    required this.way,
    required this.direction,
    required this.trainModel,
    required this.time,
  });

  factory TrainRouteSchedule.fromJson(Map<String, dynamic> json) {
    return TrainRouteSchedule(
      slug: _str(json['slug']),
      title: _str(json['title']),
      routeTypeTitle: _str(json['route_type_title']),
      type: _str(_map(json['type'])['text']),
      way: _str(_map(json['way'])['text']),
      direction: _str(_map(json['direction'])['text']),
      trainModel: _str(_map(json['train_model'])['text']),
      time: _str(json['time']),
    );
  }
}

class TrainStationSchedule {
  final String slug;
  final String title;
  final String time;
  final double? latitude;
  final double? longitude;

  const TrainStationSchedule({
    required this.slug,
    required this.title,
    required this.time,
    this.latitude,
    this.longitude,
  });

  factory TrainStationSchedule.fromJson(Map<String, dynamic> json) {
    return TrainStationSchedule(
      slug: _str(json['slug']),
      title: _str(json['title']),
      time: _str(json['time']),
      latitude: _double(json['latitude']),
      longitude: _double(json['longitude']),
    );
  }
}

class TrainRoute {
  final String slug;
  final String title;
  final String routeTypeTitle;
  final String type;
  final String way;
  final String direction;
  final String trainModel;
  final String onlineTicketing;
  final String originStation;
  final String originTime;
  final String destinationStation;
  final String destinationTime;
  final String duration;
  final int totalStations;
  final String description;
  final String coverImage;
  final List<String> images;
  final List<TrainStationSchedule> stationSchedules;
  final String? youtubeUrl;
  final String typeColor;

  const TrainRoute({
    required this.slug,
    required this.title,
    required this.routeTypeTitle,
    required this.type,
    required this.way,
    required this.direction,
    required this.trainModel,
    required this.onlineTicketing,
    required this.originStation,
    required this.originTime,
    required this.destinationStation,
    required this.destinationTime,
    required this.duration,
    required this.totalStations,
    required this.description,
    required this.coverImage,
    required this.images,
    required this.stationSchedules,
    this.youtubeUrl,
    required this.typeColor,
  });

  Color get color {
    final value = int.tryParse(typeColor, radix: 16);
    return value == null ? const Color(0xFF0F766E) : Color(0xFF000000 | value);
  }

  factory TrainRoute.fromJson(Map<String, dynamic> json) {
    final type = _map(json['type']);
    final schedules = (json['station_schedules'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              TrainStationSchedule.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
    final rawImages = (json['images'] as List? ?? const [])
        .map(_str)
        .where((item) => item.isNotEmpty)
        .toList();
    final youtube = _map(json['youtube_video'])['url'];
    return TrainRoute(
      slug: _str(json['slug']),
      title: _str(json['title']),
      routeTypeTitle: _str(json['route_type_title']),
      type: _str(type['text']),
      way: _str(_map(json['way'])['text']),
      direction: _str(_map(json['direction'])['text']),
      trainModel: _str(_map(json['train_model'])['text']),
      onlineTicketing: _str(_map(json['online_ticketing_system'])['text']),
      originStation: _str(json['origin_station_title']),
      originTime: _str(json['origin_station_time']),
      destinationStation: _str(json['destination_station_title']),
      destinationTime: _str(json['destination_station_time']),
      duration: _str(json['traveling_minutes']),
      totalStations:
          int.tryParse(_str(json['total_stations'])) ?? schedules.length,
      description: _str(json['description']),
      coverImage: _str(json['cover_image']),
      images: rawImages,
      stationSchedules: schedules,
      youtubeUrl: youtube is String && youtube.isNotEmpty ? youtube : null,
      typeColor: _str(type['color']),
    );
  }
}

class TrainStation {
  final String slug;
  final String title;
  final String description;
  final double latitude;
  final double longitude;
  final String coverImage;
  final List<TrainRouteSchedule> upSchedules;
  final List<TrainRouteSchedule> downSchedules;
  final List<TrainRouteSchedule> clockwiseSchedules;
  final List<TrainRouteSchedule> anticlockwiseSchedules;
  final List<TrainRouteSchedule> upRouteSchedules;
  final List<TrainRouteSchedule> downRouteSchedules;
  final List<String> images;

  const TrainStation({
    required this.slug,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.coverImage,
    required this.upSchedules,
    required this.downSchedules,
    required this.clockwiseSchedules,
    required this.anticlockwiseSchedules,
    required this.upRouteSchedules,
    required this.downRouteSchedules,
    required this.images,
  });

  List<TrainRouteSchedule> get departures => [
    ...upRouteSchedules,
    ...downRouteSchedules,
    ...clockwiseSchedules,
    ...anticlockwiseSchedules,
  ];

  factory TrainStation.fromJson(Map<String, dynamic> json) {
    List<TrainRouteSchedule> routeSchedules(String key) {
      return (json[key] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                TrainRouteSchedule.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    }

    final rawImages = (json['images'] as List? ?? const [])
        .map(_str)
        .where((item) => item.isNotEmpty)
        .toList();
    return TrainStation(
      slug: _str(json['slug']),
      title: _str(json['title']),
      description: _str(json['description']),
      latitude: _double(json['latitude']) ?? 0,
      longitude: _double(json['longitude']) ?? 0,
      coverImage: _str(json['cover_image']),
      upSchedules: routeSchedules('up_route_schedules'),
      downSchedules: routeSchedules('down_route_schedules'),
      clockwiseSchedules: routeSchedules('clockwise_route_schedules'),
      anticlockwiseSchedules: routeSchedules('anticlockwise_route_schedules'),
      upRouteSchedules: routeSchedules('up_route_schedules'),
      downRouteSchedules: routeSchedules('down_route_schedules'),
      images: rawImages,
    );
  }
}
