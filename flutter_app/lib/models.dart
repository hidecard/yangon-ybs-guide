import 'package:flutter/material.dart';

class BusStop {
  final int id;
  final double lat;
  final double lng;
  final String nameEn;
  final String nameMm;
  final String roadEn;
  final String roadMm;
  final String townshipEn;
  final String townshipMm;

  const BusStop({
    required this.id,
    required this.lat,
    required this.lng,
    required this.nameEn,
    required this.nameMm,
    required this.roadEn,
    required this.roadMm,
    required this.townshipEn,
    required this.townshipMm,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'lat': lat,
        'lng': lng,
        'name_en': nameEn,
        'name_mm': nameMm,
        'road_en': roadEn,
        'road_mm': roadMm,
        'township_en': townshipEn,
        'township_mm': townshipMm,
      };

  factory BusStop.fromJson(Map<String, dynamic> j) => BusStop(
        id: (j['id'] as num).toInt(),
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        nameEn: j['name_en'] ?? '',
        nameMm: j['name_mm'] ?? '',
        roadEn: j['road_en'] ?? '',
        roadMm: j['road_mm'] ?? '',
        townshipEn: j['township_en'] ?? '',
        townshipMm: j['township_mm'] ?? '',
      );
}

/// Ordered stop on a specific route (with coordinates).
typedef BusStopDetailed = BusStop;

class BusRoute {
  final String id;
  final Color color;
  final String? operator;
  final String? lineName;
  final String? qrPayment;
  final List<String> stops; // name_mm list
  final List<BusStop> stopsDetailed;

  const BusRoute({
    required this.id,
    required this.color,
    this.operator,
    this.lineName,
    this.qrPayment,
    required this.stops,
    required this.stopsDetailed,
  });

  String get displayName => lineName ?? 'YBS $id';

  Map<String, dynamic> toJson() => {
        'id': id,
        'color': color.toARGB32(),
        'operator': operator,
        'line_name': lineName,
        'qr_payment': qrPayment,
        'stops': stops,
        'stops_detailed': stopsDetailed.map((s) => s.toJson()).toList(),
      };

  factory BusRoute.fromJson(Map<String, dynamic> j) => BusRoute(
        id: j['id'] as String,
        color: Color((j['color'] as num).toInt()),
        operator: j['operator'],
        lineName: j['line_name'],
        qrPayment: j['qr_payment'],
        stops: (j['stops'] as List).map((e) => e as String).toList(),
        stopsDetailed: (j['stops_detailed'] as List)
            .map((e) => BusStop.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// A single leg of a route plan.
class PathStep {
  final BusRoute route;
  final String fromStop;
  final String toStop;

  const PathStep({
    required this.route,
    required this.fromStop,
    required this.toStop,
  });

  Map<String, dynamic> toJson() => {
        'route': route.toJson(),
        'from_stop': fromStop,
        'to_stop': toStop,
      };

  factory PathStep.fromJson(Map<String, dynamic> j) => PathStep(
        route: BusRoute.fromJson(j['route'] as Map<String, dynamic>),
        fromStop: j['from_stop'] as String,
        toStop: j['to_stop'] as String,
      );
}

class SearchResult {
  final List<PathStep> steps;
  final int transferCount;
  final double totalDistance;

  const SearchResult({
    required this.steps,
    required this.transferCount,
    required this.totalDistance,
  });
}

class StopOption {
  final String raw;
  final String display;
  final int? id;

  const StopOption({required this.raw, required this.display, this.id});
}

class FavoriteTrip {
  final String id;
  final List<PathStep> steps;
  final int createdAt;

  const FavoriteTrip({
    required this.id,
    required this.steps,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'steps': steps.map((s) => s.toJson()).toList(),
        'created_at': createdAt,
      };

  factory FavoriteTrip.fromJson(Map<String, dynamic> j) => FavoriteTrip(
        id: j['id'] as String,
        steps: (j['steps'] as List)
            .map((e) => PathStep.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: (j['created_at'] as num).toInt(),
      );
}

class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final List<SearchResult>? results;

  const ChatMessage({required this.role, required this.content, this.results});
}

class LeaderboardEntry {
  final int rank;
  final String userName;
  final int points;

  const LeaderboardEntry({
    required this.rank,
    required this.userName,
    required this.points,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j) => LeaderboardEntry(
        rank: (j['rank'] as num).toInt(),
        userName: j['user_name']?.toString() ?? '',
        points: (j['points'] as num).toInt(),
      );
}

class LeaderboardResponse {
  final List<LeaderboardEntry> leaderboard;
  final LeaderboardEntry? myRank;

  const LeaderboardResponse({
    required this.leaderboard,
    this.myRank,
  });

  factory LeaderboardResponse.fromJson(Map<String, dynamic> j) =>
      LeaderboardResponse(
        leaderboard: (j['leaderboard'] as List?)
                ?.map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        myRank: j['my_rank'] != null
            ? LeaderboardEntry.fromJson(j['my_rank'] as Map<String, dynamic>)
            : null,
      );
}

class RewardItem {
  final int id;
  final String title;
  final String description;
  final int cost;
  final int stock;
  final String icon;
  final bool isActive;

  const RewardItem({
    required this.id,
    required this.title,
    required this.description,
    required this.cost,
    required this.stock,
    required this.icon,
    required this.isActive,
  });

  factory RewardItem.fromJson(Map<String, dynamic> j) => RewardItem(
        id: (j['id'] as num).toInt(),
        title: j['title']?.toString() ?? '',
        description: j['description']?.toString() ?? '',
        cost: (j['cost'] as num).toInt(),
        stock: (j['stock'] as num).toInt(),
        icon: j['icon']?.toString() ?? '🎁',
        isActive: j['isActive'] == true || j['is_active'] == 1 || j['is_active'] == true,
      );
}

class RedemptionResult {
  final bool ok;
  final int pointsSpent;
  final int newTotal;
  final String rewardTitle;

  const RedemptionResult({
    required this.ok,
    required this.pointsSpent,
    required this.newTotal,
    required this.rewardTitle,
  });

  factory RedemptionResult.fromJson(Map<String, dynamic> j) => RedemptionResult(
        ok: j['ok'] == true,
        pointsSpent: (j['points_spent'] as num?)?.toInt() ?? 0,
        newTotal: (j['new_total'] as num?)?.toInt() ?? 0,
        rewardTitle: j['reward_title']?.toString() ?? '',
      );
}
