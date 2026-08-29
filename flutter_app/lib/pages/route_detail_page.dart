import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../config.dart';
import '../data/route_finder.dart';
import '../models.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/notify_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/nav.dart';
import '../widgets/modals.dart';
import '../widgets/osm_map.dart';
import '../widgets/route_badge.dart';

class RouteDetailPage extends StatefulWidget {
  final BusRoute route;
  const RouteDetailPage({super.key, required this.route});
  @override
  State<RouteDetailPage> createState() => _RouteDetailPageState();
}

class _RouteDetailPageState extends State<RouteDetailPage> {
  final _mapController = MapController();
  StreamSubscription<Position>? _posSub;
  ({double lat, double lng})? _livePos;
  bool _tracking = false;
  bool _arrivalEnabled = false;
  String? _arrivalMessage;
  final Set<String> _alerted = {};
  int _prevArriveIdx = -1;

  List<Prediction> _predictions = [];
  String? _predictionMsg;
  bool _loadingPred = false;

  List<BusUpdate> _busPositions = [];
  bool _loadingBusPos = false;

  List<BusEstimate> _busEta = [];
  String? _busEtaMsg;
  Timer? _etaTimer;
  Timer? _busPosTimer;

  static const _arrivalThresholdKm = 0.2;

  List<BusStop> get _stops => widget.route.stopsDetailed;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _loadPredictions();
    _loadBusEta();
    _loadBusPositions();
    _etaTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _loadBusEta(),
    );
    _busPosTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadBusPositions(),
    );
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _etaTimer?.cancel();
    _busPosTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPredictions() async {
    setState(() => _loadingPred = true);
    final (preds, msg) = await ApiService.instance.fetchPredictions(
      widget.route.id,
    );
    if (!mounted) return;
    setState(() {
      _predictions = preds;
      _predictionMsg = msg;
      _loadingPred = false;
    });
  }

  Future<void> _loadBusEta() async {
    final data = await ApiService.instance.fetchBusEta(widget.route.id);
    if (!mounted) return;
    setState(() {
      _busEta = data.estimates;
      _busEtaMsg = data.message;
    });
  }

  Future<void> _loadBusPositions() async {
    setState(() => _loadingBusPos = true);
    final updates = await ApiService.instance.fetchBusUpdates(
      routeId: widget.route.id,
      limit: 50,
    );
    if (!mounted) return;
    setState(() {
      _busPositions = updates
          .where((u) => u.lat != null && u.lng != null)
          .toList();
      _loadingBusPos = false;
    });
  }

  int get _activeIndex {
    if (_livePos == null || _stops.isEmpty) return -1;
    int minIdx = 0;
    double minDist = getDistance(
      _livePos!.lat,
      _livePos!.lng,
      _stops[0].lat,
      _stops[0].lng,
    );
    for (int i = 0; i < _stops.length; i++) {
      final d = getDistance(
        _livePos!.lat,
        _livePos!.lng,
        _stops[i].lat,
        _stops[i].lng,
      );
      if (d < minDist) {
        minDist = d;
        minIdx = i;
      }
    }
    return minDist < 0.5 ? minIdx : -1;
  }

  void _centerOnLivePosition() {
    final position = _livePos;
    if (position == null) return;
    _mapController.move(LatLng(position.lat, position.lng), 15);
  }

  void _startTracking() async {
    if (!await LocationService.instance.ensurePermission()) return;
    _posSub?.cancel();
    _posSub = LocationService.instance.watchPosition().listen((p) {
      setState(() {
        _livePos = (lat: p.latitude, lng: p.longitude);
        _tracking = true;
      });
      _checkArrival();
    });
  }

  void _checkArrival() {
    if (!_arrivalEnabled || _livePos == null) return;
    final active = _activeIndex;
    if (active >= 0 && active + 1 < _stops.length) {
      final next = _stops[active + 1];
      final d = getDistance(_livePos!.lat, _livePos!.lng, next.lat, next.lng);
      final key = 'next-${next.nameMm}';
      if (d < _arrivalThresholdKm && !_alerted.contains(key)) {
        _alerted.add(key);
        final msg = 'နောက်မှတ်တိုင် ကတော့ ${next.nameMm} ပါ';
        setState(() => _arrivalMessage = msg);
        NotifyService.instance.triggerArrival(msg);
      }
    }
    if (active >= 0 && active != _prevArriveIdx) {
      _prevArriveIdx = active;
      final stop = _stops[active];
      final msg = '${stop.nameMm} မှတ်တိုင် ရောက်ပါပီ';
      setState(() => _arrivalMessage = msg);
      NotifyService.instance.triggerArrival(msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final route = widget.route;
        final active = _activeIndex;

        final markers = <Marker>[];

        // Some routes list the same stop more than once (forward + backward /
        // out-and-back leg). Show each stop NAME only once, in first-seen
        // order, so the map markers, the path and the stop list below don't
        // duplicate the return-leg stops.
        final seenStops = <String>{};
        final uniqueStops = <BusStop>[];
        for (final stop in _stops) {
          if (seenStops.contains(stop.nameMm)) continue;
          seenStops.add(stop.nameMm);
          uniqueStops.add(stop);
        }

        for (int i = 0; i < uniqueStops.length; i++) {
          final stop = uniqueStops[i];
          final isFirst = i == 0;
          final isLast = i == uniqueStops.length - 1;
          markers.add(
            dotMarker(
              LatLng(stop.lat, stop.lng),
              color: isFirst
                  ? AppColors.emerald
                  : isLast
                  ? AppColors.rose
                  : Colors.white,
              border: isFirst || isLast ? Colors.white : route.color,
              size: isFirst || isLast ? 16 : 10,
              label: stop.nameMm,
            ),
          );
        }

        for (final b in _busPositions) {
          markers.add(
            dotMarker(LatLng(b.lat!, b.lng!), color: AppColors.blue, size: 16),
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

        final polylines = <Polyline>[
          if (uniqueStops.isNotEmpty)
            Polyline(
              points: uniqueStops.map((s) => LatLng(s.lat, s.lng)).toList(),
              color: route.color,
              strokeWidth: 4,
            ),
        ];

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                RouteBadge(routeId: route.id, color: route.color, small: true),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        route.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if ((route.operator ?? '').isNotEmpty)
                        Text(
                          route.operator!,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.slate400,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                onPressed: () async {
                  final ok = await ReportUpdateDialog.show(
                    context,
                    routeId: route.id,
                    routeLabel: route.displayName,
                  );
                  if (ok == true) _loadBusPositions();
                },
                icon: const Icon(Icons.campaign, color: AppColors.amber),
              ),
            ],
          ),
          body: Column(
            children: [
              // Keep the map fixed. Only the stop information below scrolls.
              SizedBox(
                height: 220,
                child: Stack(
                  children: [
                    OsmMap(
                      controller: _mapController,
                      center: _stops.isNotEmpty
                          ? LatLng(_stops.first.lat, _stops.first.lng)
                          : const LatLng(16.8, 96.15),
                      zoom: 12,
                      markers: markers,
                      polylines: polylines,
                    ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Column(
                        children: [
                          _fab(
                            icon: _tracking
                                ? Icons.navigation
                                : Icons.my_location,
                            color: _tracking
                                ? AppColors.brand
                                : AppColors.slate600,
                            onTap: _tracking
                                ? _centerOnLivePosition
                                : _startTracking,
                          ),
                          if (_tracking) ...[
                            const SizedBox(height: 8),
                            _fab(
                              icon: _arrivalEnabled
                                  ? Icons.notifications_active
                                  : Icons.notifications_none,
                              color: _arrivalEnabled
                                  ? AppColors.amber
                                  : AppColors.slate400,
                              onTap: () {
                                setState(
                                  () => _arrivalEnabled = !_arrivalEnabled,
                                );
                                if (_arrivalEnabled) {
                                  NotifyService.instance.requestPermission();
                                }
                              },
                            ),
                          ],
                          const SizedBox(height: 8),
                          _fab(
                            icon: _loadingBusPos
                                ? Icons.hourglass_empty
                                : Icons.directions_bus,
                            color: AppColors.brand,
                            badge: _busPositions.length,
                            onTap: _loadBusPositions,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_tracking && _livePos != null)
                            _guidanceCard(uniqueStops, active),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'စုစုပေါင်းမှတ်တိုင်',
                                    style: UI.label,
                                  ),
                                  Text(
                                    '${uniqueStops.length}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _stops.isNotEmpty
                                          ? _stops.first.nameMm
                                          : '—',
                                      textAlign: TextAlign.end,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 12,
                                      color: AppColors.slate200,
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                    ),
                                    Text(
                                      _stops.isNotEmpty
                                          ? _stops.last.nameMm
                                          : '—',
                                      textAlign: TextAlign.end,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          if (_arrivalMessage != null) _arrivalBanner(),
                          if (_loadingPred ||
                              _predictions.isNotEmpty ||
                              _predictionMsg != null)
                            _predictionsBox(),
                          if (_busEta.isNotEmpty || _busEtaMsg != null)
                            _busEtaBox(),
                          const SizedBox(height: 8),
                          Text(
                            'မှတ်တိုင်များ (${uniqueStops.length})',
                            style: UI.label,
                          ),
                          const SizedBox(height: 8),
                          ...uniqueStops.asMap().entries.map(
                            (e) => _stopTile(
                              e.key,
                              e.value,
                              active,
                              uniqueStops.length,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _guidanceCard(List<BusStop> stops, int active) {
    if (stops.isEmpty) return const SizedBox.shrink();
    final safeActive = active.clamp(0, stops.length - 1);
    final current = stops[safeActive];
    final next = safeActive + 1 < stops.length ? stops[safeActive + 1] : null;
    final isNearDestination =
        next != null && safeActive + 1 == stops.length - 1;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isNearDestination
            ? AppColors.amberLight
            : const Color(0xFFE8F8EE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isNearDestination
              ? const Color(0xFFFCD34D)
              : const Color(0xFF86EFAC),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'လက်ရှိတည်နေရာ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isNearDestination
                  ? const Color(0xFF92400E)
                  : AppColors.emeraldDark,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${current.nameMm} မှတ်တိုင် ရောက်ပါပြီ',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isNearDestination
                    ? Icons.notifications_active
                    : Icons.arrow_forward,
                size: 18,
                color: isNearDestination
                    ? AppColors.amber
                    : AppColors.emeraldDark,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  next == null
                      ? 'ဒီလမ်းကြောင်း၏ နောက်ဆုံးမှတ်တိုင် ဖြစ်ပါသည်'
                      : isNearDestination
                      ? 'သင်ဆင်းရမည့်မှတ်တိုင်: ${next.nameMm} (ရောက်ခါနီးပါပြီ)'
                      : 'နောက်ရောက်မည့်မှတ်တိုင်: ${next.nameMm}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fab({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    int badge = 0,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.white.withValues(alpha: 0.95),
          shape: const CircleBorder(),
          elevation: 2,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(icon, color: color, size: 20),
            ),
          ),
        ),
        if (badge > 0)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              width: 16,
              height: 16,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.brand,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$badge',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _arrivalBanner() {
    return Container(
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
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF92400E),
              ),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _arrivalMessage = null),
            icon: const Icon(Icons.close, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _predictionsBox() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.schedule, size: 14, color: AppColors.slate500),
              SizedBox(width: 6),
              Text(
                'အချိန်နှင့်အလိုက် ရောက်မည့် မှတ်တိုင်များ',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loadingPred)
            const Text(
              'တွက်ချက်နေပါသည်...',
              style: TextStyle(fontSize: 12, color: AppColors.slate400),
            )
          else if (_predictionMsg != null && _predictions.isEmpty)
            _liveDataFallback(_predictionMsg!, _loadPredictions)
          else if (_predictions.isEmpty)
            _liveDataFallback('Live ခန့်မှန်းချက် မရရှိသေးပါ', _loadPredictions)
          else
            ..._predictions.map((p) => _etaRow(p.stop, p.etaMinutes)),
        ],
      ),
    );
  }

  Widget _busEtaBox() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.emeraldLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.schedule, size: 14, color: AppColors.emeraldDark),
              SizedBox(width: 6),
              Text(
                'ကားလာမည့် အချိန် ခန့်မှန်းချက်',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.emeraldDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_busEtaMsg != null && _busEta.isEmpty)
            _liveDataFallback(_busEtaMsg!, _loadBusEta)
          else if (_busEta.isEmpty)
            _liveDataFallback('ကားလာမည့်အချိန် မရရှိသေးပါ', _loadBusEta)
          else
            ..._busEta
                .take(6)
                .map((e) => _etaRow(e.stop, e.etaMinutes, green: true)),
        ],
      ),
    );
  }

  Widget _liveDataFallback(String message, VoidCallback retry) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            '$message\nOffline route data ကို ဆက်သုံးနိုင်ပါသည်။',
            style: const TextStyle(fontSize: 12, color: AppColors.slate500),
          ),
        ),
        TextButton(onPressed: retry, child: const Text('ထပ်ကြိုးစားမည်')),
      ],
    );
  }

  Widget _etaRow(String stop, int eta, {bool green = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              stop,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            '~$eta မိနစ်',
            style: TextStyle(
              fontSize: 12,
              fontWeight: green ? FontWeight.w600 : FontWeight.w400,
              color: green ? AppColors.emeraldDark : AppColors.slate500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stopTile(int idx, BusStop s, int active, int total) {
    final isFirst = idx == 0;
    final isLast = idx == total - 1;
    final isActive = idx == active;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFE8F8EE) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isActive
            ? Border.all(color: const Color(0xFF86EFAC))
            : Border.all(color: Colors.transparent),
      ),
      child: ListTile(
        onTap: () => Nav.openStop(context, s),
        leading: CircleAvatar(
          backgroundColor: isActive
              ? AppColors.emerald
              : isFirst
              ? Colors.green
              : isLast
              ? Colors.red
              : Colors.blueGrey,
          child: Text(
            '${idx + 1}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        title: Text(
          s.nameMm,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${s.roadMm}လမ်း၊ ${s.townshipMm}မြို့နယ်',
              style: const TextStyle(fontSize: 12),
            ),
            if (isFirst)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'အစမှတ်တိုင်',
                  style: TextStyle(fontSize: 10, color: AppColors.emeraldDark),
                ),
              ),
            if (isLast)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'ဆင်းရမည့်မှတ်တိုင်',
                  style: TextStyle(fontSize: 10, color: AppColors.rose),
                ),
              ),
          ],
        ),
        trailing: isActive
            ? const Pill(
                'လက်ရှိရောက်နေပါပြီ',
                bg: Color(0xFFD1FAE5),
                fg: AppColors.emeraldDark,
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
