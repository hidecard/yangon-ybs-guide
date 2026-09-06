import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';

import '../data/route_finder.dart';
import '../config.dart';
import '../models.dart';
import '../services/location_service.dart';
import '../services/notify_service.dart';

enum _PassengerViewMode { hud, camera }

/// Passenger-only AR view. The phone is used by a passenger, not the driver.
/// It shows the next stop and destination over the camera while GPS tracks
/// progress along the selected V3 route leg.
class PassengerArPage extends StatefulWidget {
  final PathStep step;
  const PassengerArPage({super.key, required this.step});

  @override
  State<PassengerArPage> createState() => _PassengerArPageState();
}

class _PassengerArPageState extends State<PassengerArPage> {
  CameraController? _camera;
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<CompassEvent>? _compassSub;
  double _heading = 0;
  int _currentIndex = 0;
  double? _distanceToNext;
  double? _distanceToDestination;
  double _routeBearing = 0;
  double? _gpsAccuracy;
  double? _smoothedLat;
  double? _smoothedLng;
  bool _cameraReady = false;
  bool _voiceEnabled = true;
  _PassengerViewMode _viewMode = _PassengerViewMode.hud;
  final Set<String> _alerted = {};

  List<BusStop> get _stops {
    final all = widget.step.route.stopsDetailed;
    final from = all.indexWhere((s) => s.nameMm == widget.step.fromStop);
    if (from >= 0) {
      final to = all.indexWhere(
        (s) => s.nameMm == widget.step.toStop,
        from + 1,
      );
      if (to > from) return all.sublist(from, to + 1);
    }
    return all;
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = 0;
    _initCamera();
    _startTracking();
    _compassSub = FlutterCompass.events?.listen((event) {
      if (mounted && event.heading != null) setState(() => _heading = event.heading!);
    });
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      final back = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(back, ResolutionPreset.medium, enableAudio: false);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _cameraReady = true;
      });
    } catch (_) {
      // AR remains usable as a dark compass view if camera permission is denied.
    }
  }

  Future<void> _startTracking() async {
    if (!await LocationService.instance.ensurePermission()) return;
    final current = await LocationService.instance.currentPosition();
    if (current != null) _updatePosition(current);
    _positionSub = LocationService.instance.watchPosition().listen(_updatePosition);
  }

  void _updatePosition(Position value) {
    final stops = _stops;
    if (stops.isEmpty) return;
    if (value.accuracy.isNaN || value.accuracy > 120) {
      if (mounted) setState(() => _gpsAccuracy = value.accuracy);
      return;
    }
    _smoothedLat = _smoothedLat == null
        ? value.latitude
        : _smoothedLat! + (value.latitude - _smoothedLat!) * .35;
    _smoothedLng = _smoothedLng == null
        ? value.longitude
        : _smoothedLng! + (value.longitude - _smoothedLng!) * .35;
    final latitude = _smoothedLat!;
    final longitude = _smoothedLng!;
    var bestIndex = _currentIndex;
    var bestDistance = double.infinity;
    // Never move backwards: GPS can jump slightly when the bus is moving.
    for (var index = _currentIndex; index < stops.length; index++) {
      final distance = getDistance(latitude, longitude, stops[index].lat, stops[index].lng);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = index;
      }
    }
    final next = bestIndex + 1 < stops.length ? stops[bestIndex + 1] : null;
    final bearing = next == null ? _routeBearing : _bearingBetween(stops[bestIndex], next);
    setState(() {
      _currentIndex = bestIndex;
      _distanceToNext = next == null ? 0 : _routeDistance(latitude, longitude, bestIndex, bestIndex + 1);
      _distanceToDestination = _routeDistance(latitude, longitude, bestIndex, stops.length - 1);
      _gpsAccuracy = value.accuracy;
      _routeBearing = bearing;
    });
    _checkAlerts(stops, bestIndex);
  }

  double _routeDistance(double latitude, double longitude, int from, int to) {
    if (from >= to || from < 0 || to >= _stops.length) return 0;
    var total = getDistance(latitude, longitude, _stops[from].lat, _stops[from].lng);
    for (var index = from; index < to; index++) {
      total += getDistance(
        _stops[index].lat,
        _stops[index].lng,
        _stops[index + 1].lat,
        _stops[index + 1].lng,
      );
    }
    return total;
  }

  double _bearingBetween(BusStop from, BusStop to) {
    final lat1 = from.lat * math.pi / 180;
    final lat2 = to.lat * math.pi / 180;
    final dLng = (to.lng - from.lng) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  Future<void> _checkAlerts(List<BusStop> stops, int index) async {
    final remaining = math.max(0, stops.length - index - 1);
    String? message;
    if (remaining == 3) message = '${widget.step.toStop} သို့ ၃ မှတ်တိုင်လိုပါသည်';
    if (remaining == 1) message = 'ပြင်ဆင်ထားပါ။ နောက်မှတ်တိုင်မှာ ဆင်းရပါမယ်';
    if (remaining == 0) message = '${widget.step.toStop} မှတ်တိုင် ရောက်ပါပြီ';
    if (message == null || !_alerted.add('$remaining:${widget.step.toStop}')) return;
    if (_voiceEnabled) await NotifyService.instance.triggerArrival(message);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _compassSub?.cancel();
    _camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stops = _stops;
    final next = _currentIndex + 1 < stops.length ? stops[_currentIndex + 1] : null;
    final remaining = math.max(0, stops.length - _currentIndex - 1);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_viewMode == _PassengerViewMode.camera && _cameraReady)
            CameraPreview(_camera!)
          else
            const _HudBackground(),
          if (_viewMode == _PassengerViewMode.camera) const _ArShade(),
          SafeArea(
            child: Column(
              children: [
                _topBar(context, remaining),
                _statusCard(next, remaining),
                _progressStrip(stops),
                const Spacer(),
                Transform.rotate(
                  angle: (_routeBearing - _heading) * math.pi / 180,
                  child: const Icon(Icons.navigation_rounded, size: 92, color: Color(0xff5eead4)),
                ),
                const SizedBox(height: 16),
                if (next != null && next.nameMm != widget.step.toStop) _nextStopLabel(next),
                const Spacer(),
                _destinationCard(remaining),
                _bottomBar(context, remaining),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar(BuildContext context, int remaining) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white)),
            Expanded(child: Text('YBS ${widget.step.route.id}  →  ${widget.step.toStop}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800))),
            Text('$remaining stops', style: const TextStyle(color: Colors.white70)),
          ],
        ),
      );

  Widget _statusCard(BusStop? next, int remaining) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Card(
          color: Colors.black.withValues(alpha: .62),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.directions_bus_rounded, color: Color(0xff67e8f9)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(next?.nameMm ?? widget.step.toStop, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(next == null ? 'ဆင်းရမည့်မှတ်တိုင် ရောက်ပါပြီ' : '${_distanceToNext == null ? 'GPS ရှာနေသည်' : '${_distanceToNext!.round()} m'} • $remaining မှတ်တိုင်ကျန်', style: const TextStyle(color: Colors.white70)),
                  Text(_gpsAccuracy == null ? 'GPS စောင့်နေသည်' : 'GPS accuracy: ${_gpsAccuracy!.round()} m', style: TextStyle(color: _gpsAccuracy != null && _gpsAccuracy! <= 40 ? Colors.greenAccent : Colors.orangeAccent, fontSize: 11)),
                ])),
              ],
            ),
          ),
        ),
      );

  Widget _progressStrip(List<BusStop> stops) {
    if (stops.isEmpty) return const SizedBox.shrink();
    final visible = stops.length > 7
        ? <BusStop>[...stops.take(3), stops.last]
        : stops;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
      child: Row(
        children: visible.map((stop) {
          final isCurrent = stop == stops[_currentIndex];
          final isDestination = stop == stops.last;
          return Expanded(
            child: Column(
              children: [
                Icon(
                  isDestination ? Icons.location_on : Icons.circle,
                  size: isCurrent || isDestination ? 19 : 11,
                  color: isDestination
                      ? const Color(0xffffb020)
                      : isCurrent
                          ? const Color(0xff5eead4)
                          : Colors.white54,
                ),
                const SizedBox(height: 4),
                Text(
                  stop.nameMm,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isCurrent || isDestination
                        ? Colors.white
                        : Colors.white60,
                    fontSize: 10,
                    fontWeight: isCurrent || isDestination
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _nextStopLabel(BusStop next) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: BoxDecoration(color: AppColors.brand.withValues(alpha: .94), borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          const Icon(Icons.place_rounded, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(next.nameMm, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
            Text('${_distanceToNext == null ? 'GPS ရှာနေသည်' : '${_distanceToNext!.round()} m'} • နောက်မှတ်တိုင်', style: const TextStyle(color: Colors.white70)),
          ])),
        ]),
      );

  Widget _destinationCard(int remaining) => Container(
        margin: const EdgeInsets.fromLTRB(28, 12, 28, 0),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xffe88900).withValues(alpha: .96),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on_rounded, color: Colors.white, size: 29),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.step.toStop,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${_distanceToDestination == null ? 'GPS ရှာနေသည်' : '${_distanceToDestination!.round()} m'}  •  ${remaining == 0 ? 'ရောက်ပါပြီ' : 'ဆင်းမည့်မှတ်တိုင်'}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _bottomBar(BuildContext context, int remaining) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        child: Row(children: [
          Expanded(child: Text('ဆင်းရန်: ${widget.step.toStop}\n$remaining မှတ်တိုင်လိုပါသည်', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          IconButton(onPressed: () => setState(() => _voiceEnabled = !_voiceEnabled), icon: Icon(_voiceEnabled ? Icons.volume_up : Icons.volume_off, color: Colors.white)),
          IconButton(
            onPressed: () => setState(() => _viewMode = _viewMode == _PassengerViewMode.hud ? _PassengerViewMode.camera : _PassengerViewMode.hud),
            icon: Icon(_viewMode == _PassengerViewMode.hud ? Icons.camera_alt : Icons.dashboard, color: Colors.white),
            tooltip: _viewMode == _PassengerViewMode.hud ? 'Camera view' : 'Passenger HUD',
          ),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.map_rounded, color: Colors.white)),
        ]),
      );
}

class _ArShade extends StatelessWidget {
  const _ArShade();
  @override
  Widget build(BuildContext context) => IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: .62), Colors.transparent, Colors.black.withValues(alpha: .82)]))));
}

class _HudBackground extends StatelessWidget {
  const _HudBackground();
  @override
  Widget build(BuildContext context) => const ColoredBox(
        color: Color(0xff102a33),
        child: Center(
          child: Icon(
            Icons.directions_bus_filled_rounded,
            size: 190,
            color: Color(0x182dd4bf),
          ),
        ),
      );
}
