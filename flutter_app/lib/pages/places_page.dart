import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../data/route_finder.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../state/app_state.dart';

class PlacesPage extends StatefulWidget {
  const PlacesPage({super.key});
  @override
  State<PlacesPage> createState() => _PlacesPageState();
}

class _PlacesPageState extends State<PlacesPage> {
  final _search = TextEditingController();
  List<PlaceCategory> _categories = const [];
  List<PlaceItem> _places = const [];
  String? _category;
  String _searchMode = 'place';
  bool _loading = true;
  bool _locating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategoriesAndPlaces();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadCategoriesAndPlaces() async {
    setState(() { _loading = true; _error = null; });
    final categories = await ApiService.instance.fetchPlaceCategories();
    final places = await ApiService.instance.fetchPlaces(category: _category);
    if (!mounted) return;
    setState(() { _categories = categories; _places = places; _loading = false; });
  }

  Future<void> _searchPlaces() async {
    FocusScope.of(context).unfocus();
    setState(() { _loading = true; _error = null; });
    final text = _search.text.trim();
    final places = await ApiService.instance.fetchPlaces(
      category: _category,
      stopName: _searchMode == 'stop' ? text : null,
      busNumber: _searchMode == 'bus' ? text : null,
    );
    if (!mounted) return;
    setState(() { _places = places; _loading = false; });
  }

  Future<void> _nearby() async {
    setState(() => _locating = true);
    final position = await LocationService.instance.currentPosition();
    if (!mounted) return;
    if (position == null) {
      setState(() { _locating = false; _error = 'တည်နေရာ မရရှိသေးပါ။ Location permission ကို Allow လုပ်ပါ။'; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    final places = await ApiService.instance.fetchPlaces(
      category: _category, lat: position.latitude, lng: position.longitude, radiusMeters: 5000,
    );
    if (!mounted) return;
    setState(() { _places = places; _loading = false; _locating = false; });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('လည်ပတ်စရာ နေရာများ')),
      body: RefreshIndicator(
        onRefresh: _loadCategoriesAndPlaces,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            const Text('Places', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('အနီးအနားရှိ နေရာများ၊ အရေးပေါ်ဝန်ဆောင်မှုများနှင့် အများပြည်သူဝန်ဆောင်မှုများကို ရှာဖွေပါ။', style: TextStyle(color: AppColors.slate500, fontSize: 12, height: 1.4)),
            const SizedBox(height: 16),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _categoryChip(null, 'အားလုံး'),
                  ..._categories.map((c) => _categoryChip(c.slug, c.nameMy.isEmpty ? c.nameEn : c.nameMy)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'place', label: Text('နေရာ'), icon: Icon(Icons.search)),
                ButtonSegment(value: 'stop', label: Text('မှတ်တိုင်'), icon: Icon(Icons.pin_drop_outlined)),
                ButtonSegment(value: 'bus', label: Text('ကားနံပါတ်'), icon: Icon(Icons.directions_bus_outlined)),
              ],
              selected: {_searchMode},
              onSelectionChanged: (v) { setState(() => _searchMode = v.first); },
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(
                controller: _search,
                onSubmitted: (_) => _searchPlaces(),
                decoration: InputDecoration(
                  hintText: _searchMode == 'stop' ? 'ဥပမာ - ဆူးလေ' : _searchMode == 'bus' ? 'ဥပမာ - 36' : 'နေရာရှာရန်...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.text.isEmpty ? null : IconButton(icon: const Icon(Icons.clear), onPressed: () { _search.clear(); setState(() {}); }),
                ),
                onChanged: (_) => setState(() {}),
              )),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: _searchPlaces, icon: const Icon(Icons.arrow_forward)),
            ]),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _locating ? null : _nearby,
              icon: _locating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location),
              label: const Text('ကျွန်ုပ်အနီးရှိ နေရာများ'),
            ),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: AppColors.rose, fontSize: 12))),
            const SizedBox(height: 14),
            if (_loading) const Center(child: Padding(padding: EdgeInsets.all(28), child: CircularProgressIndicator()))
            else if (_places.isEmpty) _emptyState()
            else ..._places.map((p) => _placeCard(p, appState)),
          ],
        ),
      ),
    );
  }

  Widget _categoryChip(String? slug, String label) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(label: Text(label), selected: _category == slug, onSelected: (_) { setState(() => _category = slug); _loadCategoriesAndPlaces(); }),
  );

  Widget _emptyState() => Container(
    padding: const EdgeInsets.all(28), decoration: BoxDecoration(color: AppColors.slate100, borderRadius: BorderRadius.circular(16)),
    child: const Column(children: [Icon(Icons.place_outlined, size: 42, color: AppColors.slate400), SizedBox(height: 10), Text('နေရာအချက်အလက် မတွေ့ပါ', style: TextStyle(fontWeight: FontWeight.w600)), SizedBox(height: 4), Text('ရှာဖွေမှုကို ပြောင်းပြီး ထပ်စမ်းကြည့်ပါ။', style: TextStyle(color: AppColors.slate500, fontSize: 12))]),
  );

  ({String stops, String buses}) _transportInfo(PlaceItem p, AppState state) {
    if (p.nearbyStops.isNotEmpty && p.busNumbers.isNotEmpty) {
      return (stops: p.nearbyStops, buses: p.busNumbers);
    }
    if (p.lat == null || p.lng == null || state.stops.isEmpty) {
      return (stops: p.nearbyStops, buses: p.busNumbers);
    }
    final nearest = state.stops
        .map((stop) => (stop: stop, distance: getDistance(p.lat!, p.lng!, stop.lat, stop.lng)))
        .where((item) => item.distance <= 2.0)
        .toList()
      ..sort((a, b) => a.distance.compareTo(b.distance));
    final selected = nearest.take(3).toList();
    final stopText = p.nearbyStops.isNotEmpty
        ? p.nearbyStops
        : selected.map((item) => item.stop.nameMm).join('၊ ');
    final routeIds = <String>{};
    for (final item in selected) {
      routeIds.addAll(state.routesForStop(item.stop.nameMm, limit: 20).map((route) => route.id));
    }
    final busText = p.busNumbers.isNotEmpty ? p.busNumbers : routeIds.join(', ');
    return (stops: stopText, buses: busText);
  }

  Widget _placeCard(PlaceItem p, AppState state) {
    final transport = _transportInfo(p, state);
    return Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (p.imageUrls.isNotEmpty) ...[
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            p.imageUrls.first,
            width: double.infinity,
            height: 150,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: 12),
      ],
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.brandLight, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.place, color: AppColors.brand)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.nameMy.isEmpty ? p.name : p.nameMy, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          if (p.nameMy.isNotEmpty && p.name.isNotEmpty && p.name != p.nameMy) Text(p.name, style: const TextStyle(color: AppColors.slate500, fontSize: 11)),
          if (p.categoryName.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(p.categoryName, style: const TextStyle(color: AppColors.brand, fontSize: 11))),
        ])),
        if (p.actionUrl.isNotEmpty) IconButton(icon: const Icon(Icons.open_in_new), onPressed: () => launchUrl(Uri.tryParse(p.actionUrl) ?? Uri()))
      ]),
      if (p.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(p.description, style: const TextStyle(fontSize: 12, height: 1.4))),
      if (p.address.isNotEmpty) _detail(Icons.location_on_outlined, p.address),
      _detail(Icons.pin_drop_outlined, transport.stops.isEmpty ? 'အနီးမှတ်တိုင်: မတွေ့ပါ' : 'အနီးမှတ်တိုင်: ${transport.stops}'),
      _detail(Icons.directions_bus_outlined, transport.buses.isEmpty ? 'ကားလိုင်း: မတွေ့ပါ' : 'ကားလိုင်း: ${transport.buses}'),
    ])),
  );
  }

  Widget _detail(IconData icon, String text) => Padding(padding: const EdgeInsets.only(top: 7), child: Row(children: [Icon(icon, size: 16, color: AppColors.slate500), const SizedBox(width: 7), Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: AppColors.slate600)))]));
}
