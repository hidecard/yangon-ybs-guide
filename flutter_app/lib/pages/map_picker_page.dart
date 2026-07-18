import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../data/route_finder.dart';
import '../models.dart';
import '../services/location_service.dart';
import '../state/app_state.dart';
import '../widgets/osm_map.dart';

/// Pick a stop by panning the map; shows stops within 1km of center.
class MapPickerPage extends StatefulWidget {
  final List<BusStop> stops;
  final String title;
  const MapPickerPage({super.key, required this.stops, required this.title});
  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  final _controller = MapController();
  LatLng _center = const LatLng(16.8, 96.15);
  List<(BusStop, double)> _nearby = [];
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _updateNearby(_center);
    _locate();
  }

  void _updateNearby(LatLng center) {
    final found = widget.stops
        .map((s) => (s, getDistance(center.latitude, center.longitude, s.lat, s.lng)))
        .where((e) => e.$2 <= 1.0)
        .toList()
      ..sort((a, b) => a.$2.compareTo(b.$2));
    setState(() => _nearby = found);
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    final p = await LocationService.instance.currentPosition();
    if (!mounted) return;
    setState(() => _locating = false);
    if (p != null) {
      final c = LatLng(p.latitude, p.longitude);
      _controller.move(c, 15);
      _center = c;
      _updateNearby(c);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final markers = _nearby
            .map((e) {
              final (displayName, subtitle) = getDisambiguatedStopDisplay(e.$1, state.stops);
              return dotMarker(LatLng(e.$1.lat, e.$1.lng),
                  color: AppColors.blue, size: 14, label: displayName, subtitle: subtitle);
            })
            .toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.title, style: const TextStyle(fontSize: 16))),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              alignment: Alignment.center,
              children: [
                OsmMap(
                  controller: _controller,
                  center: _center,
                  zoom: 14,
                  markers: markers,
                  onPositionChanged: (cam, _) {
                    _center = cam.center;
                    _updateNearby(cam.center);
                  },
                ),
                // Center crosshair
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.brand, width: 2),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: FloatingActionButton.small(
                    onPressed: _locating ? null : _locate,
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.brand,
                    child: _locating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              color: AppColors.bg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('အနီးဆုံးမှတ်တိုင်များ (${_nearby.length})',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  Expanded(
                    child: _nearby.isEmpty
                        ? const Center(
                            child: Text('ဤနေရာအနီးတွင် မှတ်တိုင်မရှိပါ',
                                style: TextStyle(color: AppColors.slate400)))
                        : ListView.builder(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _nearby.length,
                            itemBuilder: (_, i) {
                              final s = _nearby[i].$1;
                              final d = _nearby[i].$2;
                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(
                                        color: AppColors.borderLight)),
                                child: ListTile(
                                  leading: const Icon(Icons.location_on_outlined,
                                      color: AppColors.brand),
                                  title: Text(s.nameMm,
                                      style: const TextStyle(fontSize: 14)),
                                  subtitle: Text(s.townshipMm,
                                      style: const TextStyle(fontSize: 12)),
                                  trailing: Text(
                                      '${(d * 1000).toStringAsFixed(0)}m',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.brand)),
                                  onTap: () => Navigator.pop(context, s),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
      },
    );
  }
}
