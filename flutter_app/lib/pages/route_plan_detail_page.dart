import 'dart:async';
import 'package:flutter/material.dart';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../data/route_finder.dart';
import '../models.dart';
import '../services/local_store.dart';
import '../services/location_service.dart';
import '../services/notify_service.dart';
import '../services/background_alert_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/osm_map.dart';
import '../widgets/route_badge.dart';
import 'map_picker_page.dart';

class RoutePlanDetailPage extends StatefulWidget {
  final List<PathStep> steps;
  final bool canSave;
  const RoutePlanDetailPage({
    super.key,
    required this.steps,
    this.canSave = true,
  });
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
  String _backgroundAlertKey = '';

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
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  Future<void> _startWatch() async {
    if (_posSub != null) return;
    if (!await LocationService.instance.ensurePermission()) return;
    if (!mounted) return;
    _posSub = LocationService.instance.watchPosition().listen((p) {
      if (!mounted) return;
      setState(() => _livePos = (lat: p.latitude, lng: p.longitude));
      _recomputeActive();
      _checkArrival();
    });
  }

  Future<void> _stopWatch() async {
    await _posSub?.cancel();
    _posSub = null;
    await stopBackgroundAlert();
    _backgroundAlertKey = '';
    if (mounted) {
      setState(() {
        _livePos = null;
        _arrivalMessage = null;
      });
    }
  }

  /// Selects the route leg whose ordered stop sequence is closest to the user.
  /// Looking only at from/to endpoints caused the active leg to remain wrong
  /// while the user was between stops.
  void _recomputeActive() {
    if (_livePos == null || steps.isEmpty) return;
    int best = _activeStep;
    double bestDist = double.infinity;
    for (int idx = 0; idx < steps.length; idx++) {
      final detailed = steps[idx].route.stopsDetailed;
      final leg = _findLeg(detailed, steps[idx].fromStop, steps[idx].toStop);
      if (leg == null) continue;
      for (final stop in detailed.sublist(leg.$1, leg.$2 + 1)) {
        final d = getDistance(_livePos!.lat, _livePos!.lng, stop.lat, stop.lng);
        if (d < bestDist) {
          bestDist = d;
          best = idx;
        }
      }
    }
    if (best != _activeStep && mounted) setState(() => _activeStep = best);
  }

  ({BusStop current, BusStop? next, double currentDistance})? _progressForActive() {
    if (_livePos == null || steps.isEmpty) return null;
    final active = steps[_activeStep];
    final detailed = active.route.stopsDetailed;
    final leg = _findLeg(detailed, active.fromStop, active.toStop);
    if (leg == null) return null;
    final sub = detailed.sublist(leg.$1, leg.$2 + 1);
    if (sub.isEmpty) return null;
    var current = sub.first;
    var currentDistance = double.infinity;
    var currentIndex = 0;
    for (int i = 0; i < sub.length; i++) {
      final d = getDistance(_livePos!.lat, _livePos!.lng, sub[i].lat, sub[i].lng);
      if (d < currentDistance) {
        current = sub[i];
        currentDistance = d;
        currentIndex = i;
      }
    }
    return (
      current: current,
      next: currentIndex + 1 < sub.length ? sub[currentIndex + 1] : null,
      currentDistance: currentDistance,
    );
  }

  Future<void> _syncBackgroundAlert(BusStop? next) async {
    if (!_arrivalEnabled || next == null) return;
    final key = '$_activeStep:${next.nameMm}:${next.lat}:${next.lng}';
    if (key == _backgroundAlertKey) return;
    final active = steps[_activeStep];
    final detailed = active.route.stopsDetailed;
    final leg = _findLeg(detailed, active.fromStop, active.toStop);
    if (leg == null) return;
    final sub = detailed.sublist(leg.$1, leg.$2 + 1);
    var nextIndex = sub.indexWhere((s) => s.nameMm == next.nameMm);
    if (nextIndex < 0) return;
    final queue = sub.skip(nextIndex).map((stop) => <String, dynamic>{
      'stopName': stop.nameMm,
      'lat': stop.lat,
      'lng': stop.lng,
      'detail': stop.nameMm == active.toStop
          ? 'သင်ဆင်းရမည့်မှတ်တိုင် ရောက်ခါနီးပါပြီ'
          : 'နောက်မှတ်တိုင် ရောက်ခါနီးပါပြီ',
    }).toList();
    _backgroundAlertKey = key;
    await startBackgroundAlertQueue(queue);
  }

  void _checkArrival() {
    if (!_arrivalEnabled || _livePos == null || steps.isEmpty) return;
    final progress = _progressForActive();
    if (progress == null) return;
    _syncBackgroundAlert(progress.next);

    final next = progress.next;
    if (next != null) {
      final d = getDistance(_livePos!.lat, _livePos!.lng, next.lat, next.lng);
      final key = 'next-$_activeStep-${next.nameMm}';
      if (d <= 0.2 && !_alerted.contains(key)) {
        _alerted.add(key);
        final msg = _activeStep == steps.length - 1 && next.nameMm == steps.last.toStop
            ? 'သင်ဆင်းရမည့်မှတ်တိုင် ${next.nameMm} ရောက်ခါနီးပါပြီ'
            : 'နောက်ရောက်မည့်မှတ်တိုင် ${next.nameMm} ပါ';
        if (mounted) setState(() => _arrivalMessage = msg);
        NotifyService.instance.triggerArrival(msg);
      }
    }

    final arrivedKey = 'arrive-$_activeStep-${progress.current.nameMm}';
    if (arrivedKey != _prevStopKey && progress.currentDistance <= 0.12) {
      _prevStopKey = arrivedKey;
      final msg = '${progress.current.nameMm} မှတ်တိုင် ရောက်ပါပြီ။ နောက်ရောက်မည့်မှတ်တိုင်က ${progress.next?.nameMm ?? 'မရှိတော့ပါ'} ပါ';
      if (mounted) setState(() => _arrivalMessage = msg);
      NotifyService.instance.triggerArrival(msg);
      if (progress.next == null) {
        stopBackgroundAlert();
      }
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
    double minD = getDistance(
      p.latitude,
      p.longitude,
      nearest.lat,
      nearest.lng,
    );
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
    final direct = await state.repo.findDirectRoutes(
      _start.trim(),
      _end.trim(),
    );
    final List<SearchResult> found = direct.isNotEmpty
        ? direct
              .map(
                (r) => SearchResult(
                  steps: [
                    PathStep(
                      route: r,
                      fromStop: _start.trim(),
                      toStop: _end.trim(),
                    ),
                  ],
                  transferCount: 0,
                  totalDistance: 0,
                ),
              )
              .toList()
        : performBFS(_start.trim(), _end.trim(), state.routes, state.stops);
    if (!mounted) return;
    setState(() => _searching = false);
    if (found.isNotEmpty) {
      await LocalStore.instance.addTripHistory(
        type: 'search',
        label: _start.trim(),
        subtitle: _end.trim(),
      );
      // Replace this page with a freshly planned one.
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RoutePlanDetailPage(steps: found.first.steps),
          ),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('လမ်းကြောင်း မတွေ့ပါ')));
    }
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
    final List<BusStop> visible = leg != null
        ? detailed.sublist(leg.$1, leg.$2 + 1)
        : detailed;

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
      final (displayName, _) = getDisambiguatedStopDisplay(s, state.stops);
      markers.add(
        dotMarker(
          LatLng(s.lat, s.lng),
          color: isFrom
              ? AppColors.emerald
              : isTo
              ? AppColors.rose
              : Colors.white,
          border: isFrom || isTo ? Colors.white : Colors.black,
          size: isFrom || isTo ? 18 : 12,
          label: displayName,
        ),
      );
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
      markers.add(
        dotMarker(
          LatLng(st.lat, st.lng),
          color: color,
          border: Colors.white,
          size: 18,
          label: st.nameMm,
        ),
      );
    }

    final deduped = uniqueVisible
        .map((s) => LatLng(s.lat, s.lng))
        .toList(growable: false);

    if (deduped.length > 1) {
      polylines.add(
        Polyline(points: deduped, color: active.route.color, strokeWidth: 5),
      );
    }

    if (_livePos != null) {
      markers.add(
        Marker(
          point: LatLng(_livePos!.lat, _livePos!.lng),
          width: 120,
          height: 64,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.directions_car,
                  size: 26,
                  color: Colors.white,
                ),
              ),
              Positioned(
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.blue,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Text(
                    'မိမိ နေရာ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
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
            const Text(
              'Route Plan Detail',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            Text(
              '${steps.length - 1} Transfers',
              style: const TextStyle(fontSize: 10, color: AppColors.slate400),
            ),
          ],
        ),
        actions: [
          if (widget.canSave)
            IconButton(
              onPressed: () async {
                await context.read<AppState>().saveTrip(steps);
                setState(() => _tripSaved = true);
              },
              icon: Icon(
                _tripSaved ? Icons.bookmark : Icons.bookmark_border,
                color: _tripSaved ? AppColors.amber : null,
              ),
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
                Positioned(
                  top: 12,
                  left: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_livePos != null)
                        const Pill(
                          'Live GPS Active',
                          bg: Colors.white,
                          fg: AppColors.emerald,
                        ),
                      if (_livePos != null) const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _toggleArrival,
                        child: Pill(
                          _arrivalEnabled
                              ? 'ရောက်ခါနီး သတိပေးချက်: ဖွင့်'
                              : 'GPS + ရောက်ခါနီး သတိပေးချက် ဖွင့်ရန်',
                          icon: _arrivalEnabled
                              ? Icons.notifications_active
                              : Icons.notifications_none,
                          bg: _arrivalEnabled ? AppColors.amber : Colors.white,
                          fg: _arrivalEnabled ? Colors.white : AppColors.slate500,
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
                        const Icon(
                          Icons.notifications_active,
                          size: 18,
                          color: AppColors.amber,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _arrivalMessage!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              setState(() => _arrivalMessage = null),
                          icon: const Icon(Icons.close, size: 16),
                        ),
                      ],
                    ),
                  ),
                if (_arrivalEnabled && _livePos != null) _progressCard(),
                _replanCard(),
                ...steps.asMap().entries.map((e) => _stepCard(e.key, e.value)),

                _intermediateStops(active),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleArrival() async {
    final enabled = !_arrivalEnabled;
    if (!enabled) {
      setState(() => _arrivalEnabled = false);
      await _stopWatch();
      return;
    }
    final permissionGranted = await LocationService.instance.ensurePermission();
    if (!permissionGranted || !mounted) return;
    await NotifyService.instance.requestPermission();
    if (!mounted) return;
    setState(() => _arrivalEnabled = true);
    await _startWatch();
  }

  Widget _progressCard() {
    final progress = _progressForActive();
    if (progress == null) return const SizedBox.shrink();
    final destination = steps[_activeStep].toStop;
    final nearDestination = progress.next?.nameMm == destination;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: nearDestination ? AppColors.amberLight : AppColors.brandLight,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'လက်ရှိမှတ်တိုင်',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: nearDestination ? AppColors.brandHover : AppColors.brand,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${progress.current.nameMm} မှတ်တိုင် ရောက်ပါပြီ',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              progress.next == null
                  ? 'ဒီလမ်းကြောင်း၏ နောက်ဆုံးမှတ်တိုင် ဖြစ်ပါသည်'
                  : nearDestination
                      ? 'သင်ဆင်းရမည့်မှတ်တိုင် ${progress.next!.nameMm} ရောက်ခါနီးပါပြီ'
                      : 'နောက်ရောက်မည့်မှတ်တိုင်: ${progress.next!.nameMm}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _replanCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ခရီးစဉ် ပြန်ရွေးရန်',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text(_start, overflow: TextOverflow.ellipsis)),
                IconButton(
                  tooltip: 'စတင်မှတ်တိုင် ရွေးရန်',
                  onPressed: () => _openPicker(true),
                  icon: const Icon(Icons.place_outlined),
                ),
                IconButton(
                  tooltip: 'လက်ရှိနေရာ အသုံးပြုရန်',
                  onPressed: _locating ? null : _useCurrentLocation,
                  icon: _locating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                ),
              ],
            ),
            const Divider(height: 4),
            Row(
              children: [
                Expanded(child: Text(_end, overflow: TextOverflow.ellipsis)),
                IconButton(
                  tooltip: 'ဆင်းမှတ်တိုင် ရွေးရန်',
                  onPressed: () => _openPicker(false),
                  icon: const Icon(Icons.flag_outlined),
                ),
                FilledButton.icon(
                  onPressed: _searching ? null : _replan,
                  icon: _searching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.alt_route),
                  label: const Text('ပြန်ရှာမည်'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _walkingGuideCard(int idx, BusStop? target) {
    if (target == null) return const SizedBox.shrink();

    final BusStop? transferOrigin = idx > 0
        ? _stopsByName[steps[idx - 1].toStop]
        : null;
    final origin = idx == 0
        ? (_livePos == null
              ? null
              : LatLng(_livePos!.lat, _livePos!.lng))
        : transferOrigin == null
        ? null
        : LatLng(transferOrigin.lat, transferOrigin.lng);
    final distanceKm = origin == null
        ? null
        : getDistance(origin.latitude, origin.longitude, target.lat, target.lng);
    final distanceMeters = distanceKm == null ? null : (distanceKm * 1000).round();
    final walkingMinutes = distanceMeters == null
        ? null
        : (distanceMeters / 80).ceil() < 1
        ? 1
        : (distanceMeters / 80).ceil();
    final title = idx == 0
        ? 'သင့်နေရာမှ စီးရမည့်မှတ်တိုင်သို့'
        : 'ကားပြောင်းစီးရန် လမ်းလျှောက်ရမည့်အကွာအဝေး';

    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_walk, size: 18, color: AppColors.blue),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            target.nameMm,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          if (distanceMeters == null)
            const Text(
              'လမ်းလျှောက်အကွာအဝေးတွက်ရန် GPS ဖွင့်ပါ',
              style: TextStyle(fontSize: 12, color: AppColors.slate500),
            )
          else
            Text(
              'ခန့်မှန်း ${distanceMeters < 1000 ? '$distanceMeters မီတာ' : '${(distanceMeters / 1000).toStringAsFixed(1)} ကီလိုမီတာ'} • လမ်းလျှောက်ချိန် ${walkingMinutes} မိနစ်',
              style: const TextStyle(fontSize: 12, color: AppColors.slate600),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: origin == null
                      ? (idx == 0 ? _startWatch : null)
                      : () => _openWalkingDirections(origin, target),
                  icon: Icon(origin == null ? Icons.my_location : Icons.navigation, size: 16),
                  label: Text(origin == null ? 'GPS ဖွင့်ရန်' : 'လမ်းညွှန်စမည်'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openWalkingDirections(LatLng origin, BusStop target) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=${origin.latitude},${origin.longitude}'
      '&destination=${target.lat},${target.lng}'
      '&travelmode=walking',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('လမ်းညွှန် app ဖွင့်မရပါ')),
      );
    }
  }

  Widget _stepCard(int idx, PathStep st) {
    final isActive = idx == _activeStep;
    final isTransfer = idx > 0;
    final fromStop = _stopsByName[st.fromStop];
    final toStop = _stopsByName[st.toStop];
    final isLastStep = idx == steps.length - 1;
    final fromLabel = _stopLabel(fromStop, st.fromStop);
    final toLabel = _stopLabel(toStop, st.toStop);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? AppColors.brand : AppColors.borderLight,
          width: isActive ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RouteBadge(
                routeId: st.route.id,
                color: st.route.color,
                small: true,
              ),
              const SizedBox(width: 8),
              if (st.route.lineName != null)
                Text(
                  '(${st.route.lineName})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              const Spacer(),
              if (isTransfer)
                const Pill(
                  'ကားပြောင်းစီးရမည့်မှတ်တိုင်',
                  bg: AppColors.amberLight,
                  fg: AppColors.brandHover,
                ),
              if (isActive)
                const Pill(
                  'လက်ရှိစီးရမည့်ကား',
                  bg: AppColors.brandLight,
                  fg: AppColors.brandHover,
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
                  color: AppColors.emerald,
                  shape: BoxShape.circle,
                ),
              ),
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
                        color: AppColors.emeraldDark,
                      ),
                    ),
                    Text(
                      fromLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (fromStop != null)
                      Text(
                        _stopSubtitle(fromStop),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.slate400,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          _walkingGuideCard(idx, fromStop),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                  color: AppColors.rose,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'မိမိဆင်းရမည့်နေရာ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.rose,
                      ),
                    ),
                    Text(
                      toLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (toStop != null)
                      Text(
                        _stopSubtitle(toStop),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.slate400,
                        ),
                      ),
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

  String _stopLabel(BusStop? stop, String fallback) {
    if (stop == null) return fallback;
    final parts = <String>[];
    if (stop.roadMm.isNotEmpty) parts.add(stop.roadMm);
    if (stop.townshipMm.isNotEmpty && stop.townshipMm != stop.roadMm) {
      parts.add(stop.townshipMm);
    }
    if (parts.isEmpty) return stop.nameMm;
    return '${stop.nameMm} (${parts.join(' · ')})';
  }

  /// Finds the best (shortest forward) contiguous leg from [fromStop] to
  /// [toStop] in [detailed]. Handles out-and-back routes where the same stop
  /// name appears multiple times by picking the smallest forward span, so a
  /// selection on the return leg still resolves to the correct segment.
  (int, int)? _findLeg(List<BusStop> detailed, String fromStop, String toStop) {
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
          Text('ဖြတ်ရမည့်မှတ်တိုင်များ (${between.length})', style: UI.label),
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
                  child: Text(
                    '${fromIdx + i + 2}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.slate500,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    between[i].nameMm,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
    final isArrivalOn = _arrivalEnabled;
    return TextButton.icon(
      onPressed: () {
        setState(() => _arrivalEnabled = !_arrivalEnabled);
        if (_arrivalEnabled) {
          NotifyService.instance.requestPermission();
        }
      },
      style: TextButton.styleFrom(
        backgroundColor: isArrivalOn ? AppColors.amber : Colors.white,
        foregroundColor: isArrivalOn ? Colors.white : AppColors.slate700,
        side: BorderSide(
          color: isArrivalOn ? AppColors.amber : AppColors.slate200,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      icon: Icon(
        isArrivalOn ? Icons.notifications_active : Icons.notifications_none,
        size: 14,
      ),
      label: Text(
        isArrivalOn ? 'ရောက်ခါနီး သတိပေးချက်: ဖွင့်' : 'ရောက်ခါနီး သတိပေးချက်',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
