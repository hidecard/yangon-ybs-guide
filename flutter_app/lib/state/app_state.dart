import 'package:flutter/material.dart';
import '../data/data_repository.dart';
import '../models.dart';
import '../services/local_store.dart';

/// Global app state: data, favorites, saved trips, user id.
class AppState extends ChangeNotifier {
  final repo = DataRepository.instance;
  final store = LocalStore.instance;

  bool loading = true;
  Set<String> favRoutes = {};
  Set<int> favStops = {};
  List<FavoriteTrip> savedTrips = [];
  String? pendingSearchStart;
  String? pendingSearchEnd;
  String? leaderboardUserName;

  List<BusRoute> get routes => repo.routes;
  List<BusStop> get stops => repo.stops;

  Future<void> init() async {
    try {
      favRoutes = await store.favRoutes();
      favStops = await store.favStops();
      savedTrips = await store.savedTrips();
      leaderboardUserName = await store.leaderboardUserName();

      await repo.load();
    } catch (_) {}

    loading = false;
    notifyListeners();
  }

  Future<void> reloadData() async {
    await repo.load(forceReload: true);
    notifyListeners();
  }

  bool isFavRoute(String id) => favRoutes.contains(id);
  bool isFavStop(int id) => favStops.contains(id);

  Future<void> toggleFavRoute(String id) async {
    if (favRoutes.contains(id)) {
      favRoutes.remove(id);
    } else {
      favRoutes.add(id);
    }
    await store.setFavRoutes(favRoutes);
    notifyListeners();
  }

  Future<void> toggleFavStop(int id) async {
    if (favStops.contains(id)) {
      favStops.remove(id);
    } else {
      favStops.add(id);
    }
    await store.setFavStops(favStops);
    notifyListeners();
  }

  Future<void> saveTrip(List<PathStep> steps) async {
    final id = '${DateTime.now().millisecondsSinceEpoch}';
    final trip = FavoriteTrip(
        id: id, steps: steps, createdAt: DateTime.now().millisecondsSinceEpoch);
    await store.saveTrip(trip);
    savedTrips = await store.savedTrips();
    notifyListeners();
  }

  Future<void> deleteTrip(String id) async {
    await store.deleteTrip(id);
    savedTrips = await store.savedTrips();
    notifyListeners();
  }

  List<BusRoute> routesForStop(String stopName, {int? limit}) {
    final list = routes.where((r) => r.stops.contains(stopName)).toList();
    if (limit != null && list.length > limit) return list.sublist(0, limit);
    return list;
  }

  void setPendingSearch(String start, String end) {
    pendingSearchStart = start;
    pendingSearchEnd = end;
    notifyListeners();
  }

  (String?, String?) getPendingSearchAndClear() {
    final result = (pendingSearchStart, pendingSearchEnd);
    pendingSearchStart = null;
    pendingSearchEnd = null;
    notifyListeners();
    return result;
  }
}
