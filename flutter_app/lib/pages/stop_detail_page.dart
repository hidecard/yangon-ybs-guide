import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../services/location_service.dart';
import '../theme.dart';
import '../util/nav.dart';
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
            Text(
              stop.nameMm,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            Text(
              stop.townshipMm,
              style: const TextStyle(fontSize: 11, color: AppColors.slate400),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => state.toggleFavStop(stop.id),
            icon: Icon(
              isFav ? Icons.star : Icons.star_border,
              color: isFav ? AppColors.amber : null,
            ),
          ),
        ],
      ),
      body: ListView(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.blueLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'မှတ်တိုင်တည်နေရာ',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${stop.lat.toStringAsFixed(5)}, ${stop.lng.toStringAsFixed(5)}',
                        style: const TextStyle(
                          color: AppColors.slate600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'မြေပုံဖွင့်မည်',
                  onPressed: () => _openMap(stop),
                  icon: const Icon(Icons.open_in_new, color: AppColors.blue),
                ),
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
                        'လမ်း',
                        stop.roadMm.isEmpty ? '—' : stop.roadMm,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openWalkingDirections(stop),
                    icon: const Icon(Icons.directions_walk),
                    label: const Text('ဒီမှတ်တိုင်သို့ လမ်းလျှောက်လမ်းညွှန်'),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Text(
                      'ဖြတ်သန်းသွားသော ကားလိုင်းများ',
                      style: UI.sectionTitle,
                    ),
                    const Spacer(),
                    Pill('${passing.length} လိုင်း'),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: passing
                      .map(
                        (r) => InkWell(
                          onTap: () => Nav.openRoute(context, r),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                RouteBadge(
                                  routeId: r.id,
                                  color: r.color,
                                  small: true,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'YBS ${r.id}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMap(BusStop stop) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1'
      '&query=${stop.lat},${stop.lng}',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('မြေပုံ app ဖွင့်မရပါ')));
    }
  }

  Future<void> _openWalkingDirections(BusStop stop) async {
    final position = await LocationService.instance.currentPosition();
    if (!mounted) return;
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('လမ်းလျှောက်လမ်းညွှန်အတွက် GPS ဖွင့်ပါ')),
      );
      return;
    }
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=${position.latitude},${position.longitude}'
      '&destination=${stop.lat},${stop.lng}'
      '&travelmode=walking',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('လမ်းညွှန် app ဖွင့်မရပါ')));
    }
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
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
