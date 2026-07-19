import 'dart:math' as math;
import '../models.dart';

double getDistance(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return R * c;
}

/// BFS route planner (max 2 transfers), mirrors performBFS in App.tsx.
List<SearchResult> performBFS(
  String start,
  String end,
  List<BusRoute> allRoutes,
  List<BusStop> allStops,
) {
  final stopMap = <String, BusStop>{};
  for (final s in allStops) {
    stopMap[s.nameMm] = s;
  }

  final routeStopPositions = <String, Map<String, List<int>>>{};
  for (final r in allRoutes) {
    final idxMap = <String, List<int>>{};
    for (int i = 0; i < r.stops.length; i++) {
      idxMap.putIfAbsent(r.stops[i], () => []).add(i);
    }
    routeStopPositions[r.id] = idxMap;
  }

  double calcPathDistance(List<PathStep> path) {
    double total = 0;
    for (final step in path) {
      final from = stopMap[step.fromStop];
      final to = stopMap[step.toStop];
      if (from != null && to != null) {
        total += getDistance(from.lat, from.lng, to.lat, to.lng);
      }
    }
    return total;
  }

  final queue = <_QueueItem>[
    _QueueItem(currentStop: start, path: [], usedRouteIds: {}),
  ];
  // Best (fewest transfers, then shortest distance) cost seen to reach a stop
  // via a given set of used routes. Lets us re-explore a stop only when it
  // yields a genuinely better plan, instead of a single global `visited` set
  // that permanently blocks valid transfer points.
  final bestCost = <String, int>{};
  final finalResults = <SearchResult>[];
  const maxTransfers = 2;

  int costOf(List<PathStep> path) =>
      path.length * 100000 + calcPathDistance(path).round().toInt();

  while (queue.isNotEmpty) {
    final item = queue.removeAt(0);
    final currentStop = item.currentStop;

    if (item.path.length > maxTransfers + 1) continue;

    // Skip only if a cheaper path to this exact state already exists.
    final key = '$currentStop|${item.usedRouteIds.join(',')}';
    final c = costOf(item.path);
    final prev = bestCost[key];
    if (prev != null && prev <= c) continue;
    bestCost[key] = c;

    final availableRoutes =
        allRoutes.where((r) => r.stops.contains(currentStop));
    for (final route in availableRoutes) {
      if (item.usedRouteIds.contains(route.id)) continue;

      final newUsed = {...item.usedRouteIds, route.id};
      final positions = routeStopPositions[route.id]?[currentStop] ?? [];

      for (final pos in positions) {
        final destIdx = route.stops.indexOf(end, pos + 1);
        if (destIdx != -1) {
          final stepPath = [
            ...item.path,
            PathStep(route: route, fromStop: currentStop, toStop: end),
          ];
          finalResults.add(SearchResult(
            steps: stepPath,
            transferCount: stepPath.length - 1,
            totalDistance: calcPathDistance(stepPath),
          ));
          continue;
        }

        if (item.path.length <= maxTransfers) {
          // Visit EVERY downstream stop on the route (no step skipping),
          // so no valid transfer point is missed.
          for (int i = pos + 1; i < route.stops.length; i++) {
            final nextStop = route.stops[i];
            final stepPath = [
              ...item.path,
              PathStep(route: route, fromStop: currentStop, toStop: nextStop),
            ];
            queue.add(_QueueItem(
              currentStop: nextStop,
              path: stepPath,
              usedRouteIds: {...newUsed},
            ));
          }
        }
      }
    }
    if (finalResults.length >= 10) break;
  }

  finalResults.sort((a, b) {
    final t = a.transferCount.compareTo(b.transferCount);
    if (t != 0) return t;
    return a.totalDistance.compareTo(b.totalDistance);
  });
  return finalResults;
}

class _QueueItem {
  final String currentStop;
  final List<PathStep> path;
  final Set<String> usedRouteIds;
  _QueueItem({
    required this.currentStop,
    required this.path,
    required this.usedRouteIds,
  });
}

/// Resolve the precise [BusStop] for a name when several stops share the
/// same name (e.g. the same stop on a route's forward + backward leg, or two
/// physically different stops with identical names in different areas).
///
/// [hint] is the user's intended location (e.g. current GPS, or the other
/// end of the trip). When provided we pick the same-named stop closest to it,
/// which also keeps the chosen direction consistent with the trip. Without a
/// hint we return the first match by id order.
BusStop? resolveStopByName(
  String name,
  List<BusStop> allStops, {
  ({double lat, double lng})? hint,
}) {
  BusStop? best;
  double bestScore = double.infinity;
  for (final s in allStops) {
    if (s.nameMm != name) continue;
    double score;
    if (hint != null) {
      // Prefer the stop nearest the hint; break ties by id for stability.
      score = getDistance(hint.lat, hint.lng, s.lat, s.lng);
    } else {
      score = s.id.toDouble();
    }
    if (score < bestScore) {
      bestScore = score;
      best = s;
    }
  }
  return best;
}

/// Build disambiguated stop options for autocomplete (name [road]).
List<StopOption> buildDisambiguatedStops(List<BusStop> stops) {
  final seen = <String>{};
  final options = <StopOption>[];
  for (final stop in stops) {
    final road = stop.roadMm.isNotEmpty ? stop.roadMm : stop.townshipMm;
    final key = '${stop.nameMm}|$road';
    if (seen.contains(key)) continue;
    seen.add(key);
    options.add(StopOption(
      raw: stop.nameMm,
      display: '${stop.nameMm} [$road]',
      id: stop.id,
    ));
  }
  options.sort((a, b) => a.display.compareTo(b.display));
  return options;
}

/// Get disambiguated display for a stop (adds road/township if needed).
/// Returns a tuple of (displayName, subtitle) where subtitle is the road/township.
(String, String?) getDisambiguatedStopDisplay(BusStop stop, List<BusStop> allStops) {
  // Check if there are other stops with the same name
  final hasDuplicates = allStops.any((s) => s.nameMm == stop.nameMm && s.id != stop.id);
  
  if (!hasDuplicates) {
    return (stop.nameMm, null);
  }
  
  final road = stop.roadMm.isNotEmpty ? stop.roadMm : stop.townshipMm;
  return (stop.nameMm, road);
}

/// Local NLP: extract start/end stop names from Burmese text.
/// Mirrors extractStopsFromText in App.tsx.
Map<String, String?>? extractStopsFromText(
    String text, List<String> allStopNames) {
  final normalized = text.trim();
  final sorted = [...allStopNames]..sort((a, b) => b.length.compareTo(a.length));

  final found = <_FoundStop>[];
  for (final name in sorted) {
    if (normalized.contains(name)) {
      final index = normalized.indexOf(name);
      final overlapping = found.any((s) =>
          (index >= s.index && index < s.index + s.name.length) ||
          (index + name.length > s.index &&
              index + name.length <= s.index + s.name.length));
      if (!overlapping) {
        found.add(_FoundStop(name, index));
      }
    }
  }

  found.sort((a, b) => a.index.compareTo(b.index));
  if (found.isEmpty) return null;

  String? start;
  String? end;
  const toKeywords = ['ကို', 'သို့', 'သွားချင်တာ'];

  if (found.length >= 2) {
    start = found[0].name;
    end = found[1].name;
  } else {
    final after = normalized.substring(found[0].index + found[0].name.length);
    final isDest = toKeywords.any((k) => after.contains(k));
    if (isDest) {
      end = found[0].name;
    } else {
      start = found[0].name;
    }
  }

  return {'start': start, 'end': end};
}

class _FoundStop {
  final String name;
  final int index;
  _FoundStop(this.name, this.index);
}

/// Levenshtein edit distance (used for fuzzy Burmese stop-name matching).
int _levenshtein(String a, String b) {
  final m = a.length;
  final n = b.length;
  if (m == 0) return n;
  if (n == 0) return m;
  var prev = List<int>.generate(n + 1, (i) => i);
  var curr = List<int>.filled(n + 1, 0);
  for (int i = 1; i <= m; i++) {
    curr[0] = i;
    for (int j = 1; j <= n; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      curr[j] = [
        prev[j] + 1,
        curr[j - 1] + 1,
        prev[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    final tmp = prev;
    prev = curr;
    curr = tmp;
  }
  return prev[n];
}

/// Resolve a (possibly partial / misspelled) user query fragment to the
/// closest known stop name. Tries exact containment first, then prefix /
/// substring, then a fuzzy Levenshtein match within a small threshold scaled
/// to the name length. Returns null if nothing is close enough.
String? resolveStopName(String query, List<String> allStopNames) {
  final q = query.trim();
  if (q.isEmpty) return null;

  // 1) Exact match (case/space insensitive).
  for (final name in allStopNames) {
    if (name == q) return name;
  }

  // 2) The query contains a full known stop name (handles fragments like
  //    "မြေနီကုန်း" embedded in a longer sentence).
  String? bestContained;
  int bestLen = 0;
  for (final name in allStopNames) {
    if (q.contains(name) && name.length > bestLen) {
      bestContained = name;
      bestLen = name.length;
    }
  }
  if (bestContained != null) return bestContained;

  // 3) Prefix / substring match.
  final lower = q.toLowerCase();
  for (final name in allStopNames) {
    if (name.toLowerCase().startsWith(lower) || name.toLowerCase().contains(lower)) {
      return name;
    }
  }

  // 4) Fuzzy match with a length-scaled threshold.
  int threshold = q.length <= 4 ? 1 : (q.length <= 8 ? 2 : 3);
  String? fuzzy;
  int fuzzyDist = threshold + 1;
  for (final name in allStopNames) {
    final d = _levenshtein(lower, name.toLowerCase());
    if (d < fuzzyDist) {
      fuzzyDist = d;
      fuzzy = name;
    }
  }
  return fuzzyDist <= threshold ? fuzzy : null;
}

String timeAgo(int? ms) {
  if (ms == null) return '';
  final diff = DateTime.now().millisecondsSinceEpoch - ms;
  final m = (diff / 60000).floor();
  if (m < 1) return 'ယခု';
  if (m < 60) return '$m မိနစ် အကြာ';
  final h = (m / 60).floor();
  if (h < 24) return '$h နာရီ အကြာ';
  final d = (h / 24).floor();
  return '$d ရက် အကြာ';
}
