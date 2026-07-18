import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../models.dart';
import '../services/api_service.dart';
import '../services/local_store.dart';
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
  String _userId = '';
  bool _alertActive = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _userId = await LocalStore.instance.getUserId();
    final status = await ApiService.instance.getAlertStatus(_userId);
    if (mounted && status.stopName == widget.stop.nameMm) {
      setState(() => _alertActive = true);
    }
  }

  Future<void> _toggleAlert(List<BusRoute> passing) async {
    final s = widget.stop;
    if (_alertActive) {
      await ApiService.instance.cancelAlert(_userId);
      setState(() => _alertActive = false);
      return;
    }
    final lines = <String>['🚌 ဖြတ်သန်းသွားသော ကားလိုင်းများ (${passing.length}):'];
    for (final r in passing) {
      lines.add('• YBS ${r.id}${r.lineName != null ? ' (${r.lineName})' : ''}');
    }
    final ok = await ApiService.instance.setAlert(_userId,
        stopName: s.nameMm, lat: s.lat, lng: s.lng, detail: lines.join('\n'));
    if (ok) {
      setState(() => _alertActive = true);
    } else if (mounted) {
      _showConnect();
    }
  }

  void _showConnect() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.smart_toy, color: AppColors.blue, size: 40),
        title: const Text('Telegram နှင့် ချိတ်ဆက်ရန်'),
        content: const Text(
            'သတိပေးချက် ရယူရန် သင်၏ Telegram Account ကို အရင် ချိတ်ဆက်ပေးဖို့ လိုအပ်ပါသည်။'),
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
    final state = context.watch<AppState>();
    final stop = widget.stop;
    final passing =
        state.routes.where((r) => r.stops.contains(stop.nameMm)).toList();
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
          IconButton(
            onPressed: () => _toggleAlert(passing),
            icon: Icon(
                _alertActive
                    ? Icons.notifications_active
                    : Icons.notifications_none,
                color: _alertActive ? AppColors.emerald : null),
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
