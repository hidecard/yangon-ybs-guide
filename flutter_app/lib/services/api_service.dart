import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models.dart';

// ----- Bus updates -----
enum BusUpdateType { started, reached, roadClosed, notRunning, other }

BusUpdateType busUpdateTypeFrom(String s) {
  switch (s) {
    case 'started':
      return BusUpdateType.started;
    case 'reached':
      return BusUpdateType.reached;
    case 'road_closed':
      return BusUpdateType.roadClosed;
    case 'not_running':
      return BusUpdateType.notRunning;
    default:
      return BusUpdateType.other;
  }
}

String busUpdateTypeKey(BusUpdateType t) {
  switch (t) {
    case BusUpdateType.started:
      return 'started';
    case BusUpdateType.reached:
      return 'reached';
    case BusUpdateType.roadClosed:
      return 'road_closed';
    case BusUpdateType.notRunning:
      return 'not_running';
    case BusUpdateType.other:
      return 'other';
  }
}

class UpdateMeta {
  final String label;
  final Color color;
  final Color bg;
  final Color dot;
  const UpdateMeta(this.label, this.color, this.bg, this.dot);
}

const updateTypeMeta = <BusUpdateType, UpdateMeta>{
  BusUpdateType.started: UpdateMeta(
      'စထွက်ပါပြီ', Color(0xFF047857), Color(0xFFECFDF5), Color(0xFF10B981)),
  BusUpdateType.reached: UpdateMeta(
      'ဘယ်နား ရောက်ပါပြီ', Color(0xFF1D4ED8), Color(0xFFEFF6FF), Color(0xFF3B82F6)),
  BusUpdateType.roadClosed: UpdateMeta(
      'ကားလမ်းပိတ်နေ', Color(0xFFBE123C), Color(0xFFFFF1F2), Color(0xFFF43F5E)),
  BusUpdateType.notRunning: UpdateMeta(
      'ဘတ်စ်မထွက်သေး', Color(0xFFB45309), Color(0xFFFFFBEB), Color(0xFFF59E0B)),
  BusUpdateType.other:
      UpdateMeta('အခြား', Color(0xFF334155), Color(0xFFF8FAFC), Color(0xFF94A3B8)),
};

class BusUpdate {
  final int? id;
  final String routeId;
  final String? stop;
  final BusUpdateType type;
  final String? note;
  final double? lat;
  final double? lng;
  final String? userId;
  final int upvotes;
  final int? createdAt;

  const BusUpdate({
    this.id,
    required this.routeId,
    this.stop,
    required this.type,
    this.note,
    this.lat,
    this.lng,
    this.userId,
    this.upvotes = 0,
    this.createdAt,
  });

  factory BusUpdate.fromJson(Map<String, dynamic> j) => BusUpdate(
        id: (j['id'] as num?)?.toInt(),
        routeId: j['routeId']?.toString() ?? '',
        stop: j['stop'],
        type: busUpdateTypeFrom(j['type']?.toString() ?? 'other'),
        note: j['note'],
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        userId: j['userId'],
        upvotes: (j['upvotes'] as num?)?.toInt() ?? 0,
        createdAt: (j['createdAt'] as num?)?.toInt(),
      );
}

class Prediction {
  final String stop;
  final int etaMinutes;
  final double distanceKm;
  const Prediction(this.stop, this.etaMinutes, this.distanceKm);
  factory Prediction.fromJson(Map<String, dynamic> j) => Prediction(
        j['stop']?.toString() ?? '',
        (j['etaMinutes'] as num?)?.toInt() ?? 0,
        (j['distanceKm'] as num?)?.toDouble() ?? 0,
      );
}

class BusEstimate {
  final String stop;
  final int etaMinutes;
  final double distanceKm;
  const BusEstimate(this.stop, this.etaMinutes, this.distanceKm);
  factory BusEstimate.fromJson(Map<String, dynamic> j) => BusEstimate(
        j['stop']?.toString() ?? '',
        (j['etaMinutes'] as num?)?.toInt() ?? 0,
        (j['distanceKm'] as num?)?.toDouble() ?? 0,
      );
}

class BusEtaResponse {
  final List<BusEstimate> estimates;
  final String? message;
  const BusEtaResponse(this.estimates, this.message);
}

// ----- Feedback -----
enum FeedbackType { bug, wrongInfo, suggestion, other }

String feedbackTypeKey(FeedbackType t) {
  switch (t) {
    case FeedbackType.bug:
      return 'bug';
    case FeedbackType.wrongInfo:
      return 'wrong_info';
    case FeedbackType.suggestion:
      return 'suggestion';
    case FeedbackType.other:
      return 'other';
  }
}

const feedbackTypeLabels = <FeedbackType, String>{
  FeedbackType.bug: 'အမှား',
  FeedbackType.wrongInfo: 'မှားတဲ့ အချက်အလက်',
  FeedbackType.suggestion: 'အကြံပြုချက်',
  FeedbackType.other: 'အခြား',
};

// ----- Notifications -----
class NotificationItem {
  final int id;
  final String title;
  final String message;
  final String type; // info | update | alert
  final int createdAt;
  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
  });
  factory NotificationItem.fromJson(Map<String, dynamic> j) => NotificationItem(
        id: (j['id'] as num).toInt(),
        title: j['title']?.toString() ?? '',
        message: j['message']?.toString() ?? '',
        type: j['type']?.toString() ?? 'info',
        createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
      );
  }

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  Uri _u(String path) => Uri.parse('${AppConfig.apiBase}$path');

  Future<Map<String, dynamic>> _get(String path) async {
    final res = await http
        .get(_u(path), headers: {'Content-Type': 'application/json'});
    final data = _decode(res.body);
    if (res.statusCode >= 400) {
      throw Exception(data['error'] ?? 'Request failed');
    }
    return data;
  }

  Future<Map<String, dynamic>> _send(String method, String path,
      {Map<String, dynamic>? body, Map<String, String>? headers}) async {
    final req = http.Request(method, _u(path));
    req.headers['Content-Type'] = 'application/json';
    if (headers != null) req.headers.addAll(headers);
    if (body != null) req.body = json.encode(body);
    final streamed = await http.Client().send(req);
    final res = await http.Response.fromStream(streamed);
    final data = _decode(res.body);
    if (res.statusCode >= 400) {
      throw Exception(data['error'] ?? data['message'] ?? 'Request failed');
    }
    return data;
  }

  Map<String, dynamic> _decode(String body) {
    try {
      final d = json.decode(body);
      return d is Map<String, dynamic> ? d : {};
    } catch (_) {
      return {};
    }
  }

  // ---- Bus updates ----
  Future<List<BusUpdate>> fetchBusUpdates({String? routeId, int limit = 50}) async {
    final params = <String, String>{'limit': '$limit'};
    if (routeId != null && routeId.isNotEmpty) params['routeId'] = routeId;
    final q = Uri(queryParameters: params).query;
    final data = await _get('/api/bus-updates?$q');
    final list = (data['updates'] as List?) ?? [];
    return list.map((e) => BusUpdate.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<int?> postBusUpdate(BusUpdate u) async {
    try {
      final data = await _send('POST', '/api/bus-updates', body: {
        'routeId': u.routeId,
        'type': busUpdateTypeKey(u.type),
        if (u.stop != null) 'stop': u.stop,
        if (u.note != null) 'note': u.note,
        if (u.lat != null) 'lat': u.lat,
        if (u.lng != null) 'lng': u.lng,
        if (u.userId != null) 'userId': u.userId,
      });
      return (data['id'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  Future<(List<Prediction>, String?)> fetchPredictions(String routeId) async {
    try {
      final data =
          await _get('/api/predictions?routeId=${Uri.encodeComponent(routeId)}');
      final list = (data['predictions'] as List?) ?? [];
      return (
        list.map((e) => Prediction.fromJson(e as Map<String, dynamic>)).toList(),
        data['message']?.toString()
      );
    } catch (_) {
      return (<Prediction>[], null);
    }
  }

  Future<BusEtaResponse> fetchBusEta(String routeId) async {
    try {
      final data =
          await _get('/api/bus-eta?routeId=${Uri.encodeComponent(routeId)}');
      final list = (data['estimates'] as List?) ?? [];
      return BusEtaResponse(
        list.map((e) => BusEstimate.fromJson(e as Map<String, dynamic>)).toList(),
        data['message']?.toString(),
      );
    } catch (_) {
      return const BusEtaResponse([], null);
    }
  }

  // ---- Feedback ----
  Future<bool> postFeedback({
    required FeedbackType type,
    required String message,
    String? routeId,
    String? userId,
  }) async {
    try {
      await _send('POST', '/api/feedback', body: {
        'type': feedbackTypeKey(type),
        'message': message,
        if (routeId != null && routeId.isNotEmpty) 'routeId': routeId,
        if (userId != null) 'userId': userId,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---- Notifications ----
  Future<List<NotificationItem>> fetchNotifications() async {
    try {
      final data = await _get('/api/notifications?limit=50');
      final list = (data['notifications'] as List?) ?? [];
      return list
          .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ---- Leaderboard ----
  Future<LeaderboardResponse> fetchLeaderboard({
    String scope = 'all',
    String? deviceId,
    int limit = 100,
  }) async {
    try {
      final params = <String, String>{
        'scope': scope,
        'limit': '$limit',
        if (deviceId != null && deviceId.isNotEmpty) 'device_id': deviceId,
      };
      final q = Uri(queryParameters: params).query;
      final data = await _get('/api/leaderboard?$q');
      return LeaderboardResponse.fromJson(data);
    } catch (_) {
      return const LeaderboardResponse(leaderboard: []);
    }
  }

  Future<Map<String, dynamic>> registerLeaderboardUser({
    required String deviceId,
    required String userName,
  }) async {
    try {
      final data = await _send('POST', '/api/leaderboard?action=register',
          body: {
            'device_id': deviceId,
            'user_name': userName,
          });
      return data;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> submitLeaderboardUpdate({
    required String deviceId,
    required String routeId,
    required String type,
    String? stop,
    String? note,
    double? lat,
    double? lng,
  }) async {
    try {
      final data = await _send('POST', '/api/leaderboard?action=submit-update',
          body: {
            'device_id': deviceId,
            'route_id': routeId,
            'type': type,
            if (stop != null && stop.isNotEmpty) 'stop': stop,
            if (note != null && note.isNotEmpty) 'note': note,
            if (lat != null) 'lat': lat,
            if (lng != null) 'lng': lng,
          });
      return data;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<List<RewardItem>> fetchRewards({bool activeOnly = true}) async {
    try {
      final params = <String, String>{'active': activeOnly ? 'true' : 'false'};
      final q = Uri(queryParameters: params).query;
      final data = await _get('/api/rewards?$q');
      final list = (data['rewards'] as List?) ?? [];
      return list.map((e) => RewardItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<RedemptionResult> redeemReward({
    required String deviceId,
    required int rewardId,
    required String claimContact,
  }) async {
    try {
      final data = await _send('POST', '/api/rewards', body: {
        'device_id': deviceId,
        'reward_id': rewardId,
        'claim_contact': claimContact,
      });
      return RedemptionResult.fromJson(data);
    } catch (e) {
      return RedemptionResult(
        ok: false,
        pointsSpent: 0,
        newTotal: 0,
        rewardTitle: '',
      );
    }
  }

  Future<Map<String, dynamic>> voteUpdate({
    required int updateId,
    required String deviceId,
    required int vote, // 1 or -1
  }) async {
    try {
      final data = await _send('POST', '/api/votes',
          body: {'update_id': updateId, 'device_id': deviceId, 'vote': vote});
      return data;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getVoteStatus({
    required int updateId,
    required String deviceId,
  }) async {
    try {
      final params = <String, String>{
        'update_id': '$updateId',
        'device_id': deviceId,
      };
      final q = Uri(queryParameters: params).query;
      final data = await _get('/api/votes?$q');
      return data;
    } catch (_) {
      return {'myVote': 0, 'upvotes': 0, 'downvotes': 0};
    }
  }
}
