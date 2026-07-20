import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/nav.dart';
import '../widgets/osm_map.dart';
import '../widgets/route_badge.dart';

class StopDetailPage extends StatefulWidget {
  final BusStop stop;
  const StopDetailPage({super.key, required this.stop});
  @override
  State<StopDetailPage> createState() => _StopDetailPageState();
}

class _StopDetailPageState extends State<StopDetailPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final stop = widget.stop;
    // Each route has separate forward/backward entries (ids like "1" and
    // "1_suffix"). Show each base line number only once so the stop page
    // doesn't list the same route twice for its two directions.
    final seenLines = <String>{};
    final passing = <BusRoute>[];
    for (final r in state.routes) {
      if (!r.stops.contains(stop.nameMm)) continue;
      final base = r.id.split('_').first;
      if (seenLines.contains(base)) continue;
      seenLines.add(base);
      passing.add(r);
    }
    final isFav = state.isFavStop(stop.id);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(stop.nameMm,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
            Text(stop.townshipMm,
                style:
                    const TextStyle(fontSize: 11, color: AppColors.slate400)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => state.toggleFavStop(stop.id),
            icon: Icon(isFav ? Icons.star : Icons.star_border,
                color: isFav ? AppColors.amber : null),
          ),
        ],
      ),
      body: ListView(
        children: [
          SizedBox(
            height: 200,
            child: OsmMap(
              center: LatLng(stop.lat, stop.lng),
              zoom: 16,
              markers: [
                dotMarker(LatLng(stop.lat, stop.lng),
                    color: AppColors.blue, size: 20, label: stop.nameMm)
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _infoBox('မြို့နယ်', stop.townshipMm)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _infoBox(
                            'လမ်း', stop.roadMm.isEmpty ? '—' : stop.roadMm)),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Text('ဖြတ်သန်းသွားသော ကားလိုင်းများ',
                        style: UI.sectionTitle),
                    const Spacer(),
                    Pill('${passing.length} လိုင်း'),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: passing
                      .map((r) => InkWell(
                            onTap: () => Nav.openRoute(context, r),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: AppColors.borderLight),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  RouteBadge(
                                      routeId: r.id,
                                      color: r.color,
                                      small: true),
                                  const SizedBox(width: 8),
                                  Text('YBS ${r.id}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: UI.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: UI.label),
          const SizedBox(height: 4),
          Text(value,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
