import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';

/// Local persistence: user id, favorites, trip history, saved trips,
/// last-seen notification. Mirrors the web localStorage helpers.
class LocalStore {
  LocalStore._();
  static final LocalStore instance = LocalStore._();

  SharedPreferences? _prefs;
  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  static const _favRoutesKey = 'ybs-fav-routes';
  static const _favStopsKey = 'ybs-fav-stops';
  static const _tripHistoryKey = 'ybs_trip_history';
  static const _savedTripsKey = 'ybs_saved_trips';
  static const _lastSeenNotifKey = 'ybs_notifications_last_seen';
  static const _lbUserNameKey = 'ybs_lb_user_name';

  // ---- Favorite routes ----
  Future<Set<String>> favRoutes() async {
    final p = await _p;
    final raw = p.getString(_favRoutesKey);
    if (raw == null) return {};
    try {
      return (json.decode(raw) as List).map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> setFavRoutes(Set<String> ids) async {
    final p = await _p;
    await p.setString(_favRoutesKey, json.encode(ids.toList()));
  }

  // ---- Favorite stops ----
  Future<Set<int>> favStops() async {
    final p = await _p;
    final raw = p.getString(_favStopsKey);
    if (raw == null) return {};
    try {
      return (json.decode(raw) as List).map((e) => (e as num).toInt()).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> setFavStops(Set<int> ids) async {
    final p = await _p;
    await p.setString(_favStopsKey, json.encode(ids.toList()));
  }

  // ---- Trip history ----
  Future<List<TripHistoryItem>> tripHistory() async {
    final p = await _p;
    final raw = p.getString(_tripHistoryKey);
    if (raw == null) return [];
    try {
      return (json.decode(raw) as List)
          .map((e) => TripHistoryItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<TripHistoryItem>> addTripHistory({
    required String type,
    required String label,
    String? subtitle,
    String? routeId,
  }) async {
    final p = await _p;
    final list = await tripHistory();
    final item = TripHistoryItem(
      id: '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}',
      type: type,
      label: label,
      subtitle: subtitle,
      routeId: routeId,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    list.insert(0, item);
    final trimmed = list.take(20).toList();
    await p.setString(
        _tripHistoryKey, json.encode(trimmed.map((e) => e.toJson()).toList()));
    return trimmed;
  }

  Future<List<TripHistoryItem>> removeTripHistory(String id) async {
    final p = await _p;
    final list = (await tripHistory()).where((e) => e.id != id).toList();
    await p.setString(
        _tripHistoryKey, json.encode(list.map((e) => e.toJson()).toList()));
    return list;
  }

  Future<void> clearTripHistory() async {
    final p = await _p;
    await p.remove(_tripHistoryKey);
  }

  // ---- Saved trips (favorites) ----
  Future<List<FavoriteTrip>> savedTrips() async {
    final p = await _p;
    final raw = p.getString(_savedTripsKey);
    if (raw == null) return [];
    try {
      final list = (json.decode(raw) as List)
          .map((e) => FavoriteTrip.fromJson(e as Map<String, dynamic>))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveTrip(FavoriteTrip trip) async {
    final p = await _p;
    final list = (await savedTrips())..removeWhere((t) => t.id == trip.id);
    list.insert(0, trip);
    await p.setString(
        _savedTripsKey, json.encode(list.map((e) => e.toJson()).toList()));
  }

  Future<void> deleteTrip(String id) async {
    final p = await _p;
    final list = (await savedTrips()).where((t) => t.id != id).toList();
    await p.setString(
        _savedTripsKey, json.encode(list.map((e) => e.toJson()).toList()));
  }

  // ---- Notifications last-seen ----
  Future<int?> lastSeenNotification() async {
    final p = await _p;
    return p.getInt(_lastSeenNotifKey);
  }

  Future<void> setLastSeenNotification(int id) async {
    final p = await _p;
    await p.setInt(_lastSeenNotifKey, id);
  }

  // ---- Active background arrival alert ----
  // Persisted so the background service can keep monitoring even when the
  // app is closed or the screen is off.
  static const _alertKey = 'ybs_bg_alert';

  Future<void> saveBackgroundAlert({
    required String stopName,
    required double lat,
    required double lng,
    String detail = '',
  }) async {
    final p = await _p;
    await p.setString(
        _alertKey,
        json.encode({
          'stopName': stopName,
          'lat': lat,
          'lng': lng,
          'detail': detail,
          'alerted': false,
        }));
  }

  Future<Map<String, dynamic>?> getBackgroundAlert() async {
    final p = await _p;
    final raw = p.getString(_alertKey);
    if (raw == null) return null;
    try {
      final m = json.decode(raw) as Map<String, dynamic>;
      if (m['stopName'] == null) return null;
      return m;
    } catch (_) {
      return null;
    }
  }

  Future<void> setBackgroundAlertFired(bool fired) async {
    final cur = await getBackgroundAlert();
    if (cur == null) return;
    cur['alerted'] = fired;
    final p = await _p;
    await p.setString(_alertKey, json.encode(cur));
  }

  Future<void> clearBackgroundAlert() async {
    final p = await _p;
    await p.remove(_alertKey);
  }

  // ---- Leaderboard user name ----
  Future<String?> leaderboardUserName() async {
    final p = await _p;
    return p.getString(_lbUserNameKey);
  }

  Future<void> setLeaderboardUserName(String name) async {
    final p = await _p;
    await p.setString(_lbUserNameKey, name);
  }
}

class TripHistoryItem {
  final String id;
  final String type; // search | stop | route
  final String label;
  final String? subtitle;
  final String? routeId;
  final int timestamp;

  const TripHistoryItem({
    required this.id,
    required this.type,
    required this.label,
    this.subtitle,
    this.routeId,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'label': label,
        'subtitle': subtitle,
        'routeId': routeId,
        'timestamp': timestamp,
      };

  factory TripHistoryItem.fromJson(Map<String, dynamic> j) => TripHistoryItem(
        id: j['id'] as String,
        type: j['type'] as String,
        label: j['label'] as String,
        subtitle: j['subtitle'],
        routeId: j['routeId'],
        timestamp: (j['timestamp'] as num).toInt(),
      );
}
