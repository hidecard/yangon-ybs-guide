import 'dart:async';
import 'package:flutter/material.dart';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../data/route_finder.dart';
import '../models.dart';
import '../services/api_service.dart';
import '../services/background_alert_service.dart';
import '../services/local_store.dart';
import '../services/location_service.dart';
import '../services/notify_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'package:flutter_map/flutter_map.dart';
import '../util/nav.dart';
import '../widgets/osm_map.dart';
import '../widgets/route_badge.dart';
import 'map_picker_page.dart';



class RoutePlanDetailPage extends StatefulWidget {
  final List<PathStep> steps;
  final bool canSave;
  const RoutePlanDetailPage(
      {super.key, required this.steps, this.canSave = true});
  @override
  State<RoutePlanDetailPage> createState() => _RoutePlanDetailPageState();
}

class _RoutePlanDetailPageState extends State<RoutePlanDetailPage> {
  final _mapController = MapController();
  StreamSubscription<Position>? _posSub;
  ({double lat, double lng})? _livePos;
  int _activeStep = 0;
  bool _arrivalEnabled = false;
  String? _arrivalMessage;
  final Set<String> _alerted = {};
  String _prevStopKey = '';

  String _userId = '';
  String? _activeAlertStop;
  bool _tripSaved = false;

  // Editable start/end so the user can re-plan from "Near Me" or a map pick.
  String _start = '';
  String _end = '';
  bool _searching = false;
  bool _locating = false;

  List<PathStep> get steps => widget.steps;

  final Map<String, BusStop> _stopsByName = {};

  @override
  void initState() {
    super.initState();
    for (final st in steps) {
      for (final s in st.route.stopsDetailed) {
        _stopsByName.putIfAbsent(s.nameMm, () => s);
      }
    }
    if (steps.isNotEmpty) {
      _start = steps.first.fromStop;
      _end = steps.last.toStop;
    }
    _init();
    _startWatch();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    _userId = await LocalStore.instance.getUserId();
    final status = await ApiService.instance.getAlertStatus(_userId);
    if (mounted && status.stopName != null) {
      setState(() => _activeAlertStop = status.stopName);
    }
  }

  void _startWatch() async {
    if (!await LocationService.instance.ensurePermission()) return;
    _posSub = LocationService.instance.watchPosition().listen((p) {
      setState(() => _livePos = (lat: p.latitude, lng: p.longitude));
      _recomputeActive();
      _checkArrival();
    });
  }

  void _recomputeActive() {
    if (_livePos == null || steps.isEmpty) return;
    int best = 0;
    double bestDist = double.infinity;
    for (int idx = 0; idx < steps.length; idx++) {
      final from = _stopsByName[steps[idx].fromStop];
      final to = _stopsByName[steps[idx].toStop];
      if (from == null || to == null) continue;
      final dFrom =
          getDistance(_livePos!.lat, _livePos!.lng, from.lat, from.lng);
      final dTo = getDistance(_livePos!.lat, _livePos!.lng, to.lat, to.lng);
      final m = dFrom < dTo ? dFrom : dTo;
      if (m < bestDist) {
        bestDist = m;
        best = idx;
      }
    }
    if (best != _activeStep) setState(() => _activeStep = best);
  }

  void _checkArrival() {
    if (!_arrivalEnabled || _livePos == null) return;
    final active = steps[_activeStep];
    final detailed = active.route.stopsDetailed;
    final leg = _findLeg(detailed, active.fromStop, active.toStop);
    if (leg == null) return;
    final sub = detailed.sublist(leg.$1, leg.$2 + 1);

    int cur = 0;
    double min = double.infinity;
    for (int i = 0; i < sub.length; i++) {
      final d = getDistance(_livePos!.lat, _livePos!.lng, sub[i].lat, sub[i].lng);
      if (d < min) {
        min = d;
        cur = i;
      }
    }

    void tryAlert(BusStop? stop, String key, String Function(String) build) {
      if (stop == null) return;
      final d = getDistance(_livePos!.lat, _livePos!.lng, stop.lat, stop.lng);
      if (d < 0.2 && !_alerted.contains(key)) {
        _alerted.add(key);
        final msg = build(stop.nameMm);
        setState(() => _arrivalMessage = msg);
        NotifyService.instance.triggerArrival(msg);
      }
    }

    final next = cur + 1 < sub.length ? sub[cur + 1] : null;
    tryAlert(next, 'next-${next?.nameMm}', (n) => 'နောက်မှတ်တိုင် ကတော့ $n ပါ');

    if (_activeStep == steps.length - 1) {
      final last = steps.last;
      final lastDetailed = last.route.stopsDetailed;
      final destIdx = lastDetailed.indexWhere((s) => s.nameMm == last.toStop);
      if (destIdx >= 0) {
        tryAlert(lastDetailed[destIdx], 'dest-${last.toStop}',
            (n) => 'ဆင်းမည့်မှတ်တိုင် ကတော့ $n ပါ');
      }
    }

    final stop = sub[cur];
    final key = 'arrive-$_activeStep-${stop.nameMm}';
    if (key != _prevStopKey) {
      _prevStopKey = key;
      final msg = '${stop.nameMm} မှတ်တိုင် ရောက်ပါပီ';
      setState(() => _arrivalMessage = msg);
      NotifyService.instance.triggerArrival(msg);
    }
  }

  Future<void> _toggleAlert(String stopName, int stepIndex) async {
    if (_activeAlertStop == stopName) {
      await ApiService.instance.cancelAlert(_userId);
      await stopBackgroundAlert();
      setState(() => _activeAlertStop = null);
      return;
    }
    final stop = _stopsByName[stopName];
    if (stop == null) return;
    final detail = _buildDetail(stepIndex);
    final ok = await ApiService.instance.setAlert(_userId,
        stopName: stopName, lat: stop.lat, lng: stop.lng, detail: detail);
    if (ok) {
      setState(() => _activeAlertStop = stopName);
      // Keep alerting even when the app is closed / screen is off.
      await startBackgroundAlert(
          stopName: stopName, lat: stop.lat, lng: stop.lng, detail: detail);
      if (mounted) _showSetDialog(stopName);
    } else if (mounted) {
      _showConnectDialog();
    }
  }

  Future<void> _useCurrentLocation() async {
    final state = context.read<AppState>();
    setState(() => _locating = true);
    final p = await LocationService.instance.currentPosition();
    if (!mounted) return;
    setState(() => _locating = false);
    if (p == null || state.stops.isEmpty) return;
    BusStop nearest = state.stops.first;
    double minD = getDistance(p.latitude, p.longitude, nearest.lat, nearest.lng);
    for (final s in state.stops) {
      final d = getDistance(p.latitude, p.longitude, s.lat, s.lng);
      if (d < minD) {
        minD = d;
        nearest = s;
      }
    }
    setState(() => _start = nearest.nameMm);
  }

  Future<void> _openPicker(bool isStart) async {
    final state = context.read<AppState>();
    final selected = await Navigator.push<BusStop>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerPage(
          stops: state.stops,
          title: isStart
              ? 'စတင်မည့်မှတ်တိုင် ရွေးချယ်ပါ'
              : 'ဆင်းမည့်မှတ်တိုင် ရွေးချယ်ပါ',
        ),
      ),
    );
    if (selected != null) {
      setState(() {
        if (isStart) {
          _start = selected.nameMm;
        } else {
          _end = selected.nameMm;
        }
      });
    }
  }

  Future<void> _replan() async {
    if (_start.trim().isEmpty || _end.trim().isEmpty) return;
    final state = context.read<AppState>();
    setState(() => _searching = true);
    final direct = await state.repo.findDirectRoutes(_start.trim(), _end.trim());
    final List<SearchResult> found = direct.isNotEmpty
        ? direct
            .map((r) => SearchResult(
                  steps: [
                    PathStep(
                        route: r,
                        fromStop: _start.trim(),
                        toStop: _end.trim())
                  ],
                  transferCount: 0,
                  totalDistance: 0,
                ))
            .toList()
        : performBFS(_start.trim(), _end.trim(), state.routes, state.stops);
    if (!mounted) return;
    setState(() => _searching = false);
    if (found.isNotEmpty) {
      await LocalStore.instance.addTripHistory(
          type: 'search', label: _start.trim(), subtitle: _end.trim());
      // Replace this page with a freshly planned one.
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => RoutePlanDetailPage(steps: found.first.steps)),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('လမ်းကြောင်း မတွေ့ပါ')),
      );
    }
  }

  String _buildDetail(int stepIndex) {
    final lines = <String>['🚌 လမ်းကြောင်းအစီအစဉ် (Route Plan):'];
    for (int i = 0; i < steps.length; i++) {
      final r = steps[i].route;
      final ln = r.lineName != null ? ' (${r.lineName})' : '';
      final marker = i == stepIndex ? '  ◀️ ဤမှတ်တိုင်သို့ သတိပေးထားပါသည်' : '';
      lines.add(
          '${i + 1}. YBS ${r.id}$ln — စီး: ${steps[i].fromStop} → ဆင်း: ${steps[i].toStop}$marker');
    }
    return lines.join('\n');
  }

  void _showSetDialog(String stopName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.check_circle,
            color: AppColors.emerald, size: 40),
        title: const Text('သတိပေးချက်သတ်မှတ်ပြီးပါပြီ'),
        content: Text(
            '"$stopName" မှတ်တိုင်သို့ ရောက်ရှိရန် နီးကပ်လာပါက Telegram မှတစ်ဆင့် သတိပေးပါမည်။'),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ကောင်းပါပြီ')),
        ],
      ),
    );
  }

  void _showConnectDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.smart_toy, color: AppColors.blue, size: 40),
        title: const Text('Telegram နှင့် ချိတ်ဆက်ရန်'),
        content: const Text(
            'သတိပေးချက်များ ရယူနိုင်ရန်အတွက် Telegram Account ကို အရင် ချိတ်ဆက်ပေးဖို့ လိုအပ်ပါသည်။'),
        actions: [
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.blue),
            onPressed: () => launchUrl(
                Uri.parse(LocalStore.instance.connectUrl(_userId)),
                mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.send),
            label: const Text('ချိတ်ဆက်မည်'),
          ),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('နောက်မှလုပ်မည်')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = steps[_activeStep];
    final state = context.read<AppState>();
    final markers = <Marker>[];
    final polylines = <Polyline>[];

    final detailed = active.route.stopsDetailed;

    // A route may list the same stop name more than once (a forward +
    // backward / out-and-back leg). Pick the SHORTEST forward span that goes
    // from the boarding stop to the alighting stop, so return-leg selections
    // resolve to the correct leg instead of falling back to the whole route.
    final leg = _findLeg(detailed, active.fromStop, active.toStop);
    final List<BusStop> visible =
        leg != null ? detailed.sublist(leg.$1, leg.$2 + 1) : detailed;

    // Some routes list the same stop name twice (a forward + backward leg),
    // which would draw the path out-and-back and duplicate markers. Keep each
    // stop only once, in first-seen order (from -> to direction), so
    // overlapping legs are shown a single time even when names repeat.
    final seenNames = <String>{};
    final uniqueVisible = <BusStop>[];
    for (final s in visible) {
      if (seenNames.contains(s.nameMm)) continue;
      seenNames.add(s.nameMm);
      uniqueVisible.add(s);
    }

    // Role labels for the whole plan: boarding, each transfer, and the final
    // alighting stop.
    final roleByStop = <String, String>{};
    if (steps.isNotEmpty) {
      roleByStop[steps.first.fromStop] = 'စီးရမည့်မှတ်တိုင်';
      for (int i = 1; i < steps.length; i++) {
        roleByStop[steps[i].fromStop] = 'ကားပြောင်းစီးရမည့်မှတ်တိုင်';
      }
      roleByStop[steps.last.toStop] = 'ဆင်းရမည့်မှတ်တိုင်';
    }

    // Show each stop marker only once, even when names are duplicated along the
    // forward/backward leg.
    final markerNames = <String>{};
    for (final s in uniqueVisible) {
      final isFrom = s.nameMm == active.fromStop;
      final isTo = s.nameMm == active.toStop;
      if (markerNames.contains(s.nameMm)) continue;
      markerNames.add(s.nameMm);
      final (displayName, subtitle) = getDisambiguatedStopDisplay(s, state.stops);
      final role = roleByStop[s.nameMm];
      markers.add(dotMarker(
        LatLng(s.lat, s.lng),
        color: isFrom
            ? AppColors.emerald
            : isTo
                ? AppColors.rose
                : Colors.white,
        border: isFrom || isTo ? Colors.white : Colors.black,
        size: isFrom || isTo ? 18 : 12,
        label: role ?? displayName,
        subtitle: role != null ? displayName : subtitle,
      ));
    }

    // Also label boarding / transfer / alighting points that belong to other
    // steps of the plan (outside the active leg) so they show on the map too.
    for (final entry in roleByStop.entries) {
      if (markerNames.contains(entry.key)) continue;
      final st = _stopsByName[entry.key];
      if (st == null) continue;
      markerNames.add(entry.key);
      final color = entry.value == 'ဆင်းရမည့်မှတ်တိုင်'
          ? AppColors.rose
          : entry.value == 'စီးရမည့်မှတ်တိုင်'
              ? AppColors.emerald
              : AppColors.amber;
      markers.add(dotMarker(
        LatLng(st.lat, st.lng),
        color: color,
        border: Colors.white,
        size: 18,
        label: entry.value,
        subtitle: st.nameMm,
      ));
    }

    final deduped =
        uniqueVisible.map((s) => LatLng(s.lat, s.lng)).toList(growable: false);

    if (deduped.length > 1) {
      polylines.add(Polyline(
        points: deduped,
        color: active.route.color,
        strokeWidth: 5,
      ));
    }

    if (_livePos != null) {
      markers.add(dotMarker(LatLng(_livePos!.lat, _livePos!.lng),
          color: AppColors.blue, size: 16, border: Colors.white,
          label: 'မိမိနေရာ'));
    }

    final center = uniqueVisible.isNotEmpty
        ? LatLng(uniqueVisible.first.lat, uniqueVisible.first.lng)
        : const LatLng(16.8, 96.15);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Route Plan Detail',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            Text('${steps.length - 1} Transfers',
                style:
                    const TextStyle(fontSize: 10, color: AppColors.slate400)),
          ],
        ),
        actions: [
          if (widget.canSave)
            IconButton(
              onPressed: () async {
                await context.read<AppState>().saveTrip(steps);
                setState(() => _tripSaved = true);
              },
              icon: Icon(_tripSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: _tripSaved ? AppColors.amber : null),
            ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 340,
            child: Stack(
              children: [
                OsmMap(
                  controller: _mapController,
                  center: center,
                  zoom: 13,
                  markers: markers,
                  polylines: polylines,
                ),
                if (_livePos != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Pill('Live GPS Active',
                            bg: Colors.white, fg: AppColors.emerald),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () {
                            setState(
                                () => _arrivalEnabled = !_arrivalEnabled);
                            if (_arrivalEnabled) {
                              NotifyService.instance.requestPermission();
                            }
                          },
                          child: Pill(
                            _arrivalEnabled
                                ? 'ရောက်ခါနီး သတိပေးချက်: ဖွင့်'
                                : 'ရောက်ခါနီး သတိပေးချက်',
                            icon: Icons.notifications_none,
                            bg: _arrivalEnabled
                                ? AppColors.amberLight
                                : Colors.white,
                            fg: _arrivalEnabled
                                ? AppColors.brandHover
                                : AppColors.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_arrivalMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.amberLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_active,
                            size: 18, color: AppColors.amber),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(_arrivalMessage!,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF92400E)))),
                        IconButton(
                            onPressed: () =>
                                setState(() => _arrivalMessage = null),
                            icon: const Icon(Icons.close, size: 16)),
                      ],
                    ),
                  ),
                ...steps.asMap().entries.map((e) => _stepCard(e.key, e.value)),
                _intermediateStops(active),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Start/End search header with "Near Me" and map-picker, so users can
  /// re-plan the trip directly from this page.

  Widget _stepCard(int idx, PathStep st) {
    final isActive = idx == _activeStep;
    final isTransfer = idx > 0;
    final fromStop = _stopsByName[st.fromStop];
    final toStop = _stopsByName[st.toStop];
    final isLastStep = idx == steps.length - 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isActive ? AppColors.brand : AppColors.borderLight,
            width: isActive ? 1.4 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RouteBadge(
                  routeId: st.route.id, color: st.route.color, small: true),
              const SizedBox(width: 8),
              Text('YBS ${st.route.id}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (isTransfer)
                const Pill('ကားပြောင်းစီးရမည့်မှတ်တိုင်',
                    bg: AppColors.amberLight, fg: AppColors.brandHover),
              if (isActive)
                const Pill('လက်ရှိစီးရမည့်ကား',
                    bg: AppColors.brandLight, fg: AppColors.brandHover),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                      color: AppColors.emerald, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        isLastStep
                            ? 'မိမိစီးရမည့်နေရာ (သင့်တည်နေရာ)'
                            : 'စီးရမည့်မှတ်တိုင်',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.emeraldDark)),
                    Text(st.fromStop,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    if (fromStop != null)
                      Text(
                          _stopSubtitle(fromStop),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.slate400)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                      color: AppColors.rose, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('မိမိဆင်းရမည့်နေရာ',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.rose)),
                    Text(st.toStop,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    if (toStop != null)
                      Text(
                          _stopSubtitle(toStop),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.slate400)),
                  ],
                ),
              ),
              _alertButton(st.toStop, idx),
            ],
          ),
        ],
      ),
    );
  }

  /// "road · township" subtitle so a same-named stop is clearly identified.
  String _stopSubtitle(BusStop s) {
    final road = s.roadMm.isNotEmpty ? s.roadMm : null;
    final township = s.townshipMm.isNotEmpty ? s.townshipMm : null;
    if (road != null && township != null && road != township) {
      return '$road · $township';
    }
    return road ?? township ?? '';
  }

  /// Finds the best (shortest forward) contiguous leg from [fromStop] to
  /// [toStop] in [detailed]. Handles out-and-back routes where the same stop
  /// name appears multiple times by picking the smallest forward span, so a
  /// selection on the return leg still resolves to the correct segment.
  (int, int)? _findLeg(
      List<BusStop> detailed, String fromStop, String toStop) {
    final fromIdxs = <int>[];
    final toIdxs = <int>[];
    for (int i = 0; i < detailed.length; i++) {
      if (detailed[i].nameMm == fromStop) fromIdxs.add(i);
      if (detailed[i].nameMm == toStop) toIdxs.add(i);
    }
    if (fromIdxs.isEmpty || toIdxs.isEmpty) return null;
    int bestFrom = -1;
    int bestTo = -1;
    int bestLen = 1 << 30;
    for (final f in fromIdxs) {
      for (final t in toIdxs) {
        if (t > f && (t - f) < bestLen) {
          bestLen = t - f;
          bestFrom = f;
          bestTo = t;
        }
      }
    }
    if (bestFrom < 0) return null;
    return (bestFrom, bestTo);
  }

  /// Shows only the stops between the active step's board/alight stops
  /// (excludes the start and end markers).
  Widget _intermediateStops(PathStep active) {
    final detailed = active.route.stopsDetailed;
    final leg = _findLeg(detailed, active.fromStop, active.toStop);
    if (leg == null) return const SizedBox.shrink();
    final fromIdx = leg.$1;
    final toIdx = leg.$2;
    if (toIdx - fromIdx <= 1) {
      return const SizedBox.shrink();
    }
    final between = <BusStop>[];
    final seen = <String>{};
    for (int i = fromIdx + 1; i < toIdx; i++) {
      final s = detailed[i];
      if (seen.contains(s.nameMm)) continue;
      seen.add(s.nameMm);
      between.add(s);
    }
    if (between.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: UI.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ဖြတ်ရမည့်မှတ်တိုင်များ (${between.length})',
              style: UI.label),
          const SizedBox(height: 10),
          for (int i = 0; i < between.length; i++) ...[
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.slate100,
                    shape: BoxShape.circle,
                  ),
                  child: Text('${fromIdx + i + 2}',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.slate500)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(between[i].nameMm,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
            if (i < between.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _alertButton(String stop, int idx) {
    final active = _activeAlertStop == stop;
    return TextButton.icon(
      onPressed: () => _toggleAlert(stop, idx),
      style: TextButton.styleFrom(
        backgroundColor: active ? AppColors.emerald : Colors.white,
        foregroundColor: active ? Colors.white : AppColors.slate700,
        side: BorderSide(
            color: active ? AppColors.emeraldDark : AppColors.slate200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      icon: Icon(active ? Icons.check_circle : Icons.notifications_none,
          size: 14),
      label: Text(active ? 'ယူပြီးပါပြီ' : 'သတိပေးချက်',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
