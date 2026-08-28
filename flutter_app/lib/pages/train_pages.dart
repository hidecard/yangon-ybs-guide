import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../data/train_repository.dart';
import '../theme.dart';
import '../train_models.dart';
import '../widgets/osm_map.dart';
import '../widgets/route_badge.dart';
import '../widgets/ui_states.dart';

class TransportModeChooser extends StatefulWidget {
  final Widget busPage;
  const TransportModeChooser({super.key, required this.busPage});

  @override
  State<TransportModeChooser> createState() => _TransportModeChooserState();
}

class _TransportModeChooserState extends State<TransportModeChooser> {
  bool _trainLoading = false;
  String? _trainError;

  Future<void> _openTrain() async {
    setState(() {
      _trainLoading = true;
      _trainError = null;
    });
    try {
      await TrainDataRepository.instance.load();
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TrainShell(busPage: widget.busPage)),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _trainError = 'Train data ကို ဖွင့်မရသေးပါ။');
      }
    } finally {
      if (mounted) setState(() => _trainLoading = false);
    }
  }

  void _openBus() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => widget.busPage),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Image.asset('assets/icons/logo.png'),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'YBS AI',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ဘယ်လိုခရီးသွားမလဲ ရွေးချယ်ပါ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _ModeCard(
                    icon: Icons.directions_bus_rounded,
                    color: AppColors.brand,
                    title: 'Bus',
                    subtitle: 'YBS ကားလိုင်းများနှင့် လမ်းကြောင်းရှာဖွေမှု',
                    onTap: _openBus,
                  ),
                  const SizedBox(height: 14),
                  _ModeCard(
                    icon: Icons.train_rounded,
                    color: AppColors.emeraldDark,
                    title: 'Train',
                    subtitle: 'ရထားလမ်းကြောင်း၊ ဘူတာနှင့် အချိန်ဇယား',
                    loading: _trainLoading,
                    onTap: _openTrain,
                  ),
                  if (_trainError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _trainError!,
                      style: const TextStyle(color: AppColors.rose),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text(
                    'Bus အပိုင်းသည် မူရင်းအတိုင်း ဆက်လက်အလုပ်လုပ်ပါမည်။',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.slate500, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool loading;

  const _ModeCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.chevron_right, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class TrainShell extends StatefulWidget {
  final Widget busPage;
  const TrainShell({super.key, required this.busPage});

  @override
  State<TrainShell> createState() => _TrainShellState();
}

class _TrainShellState extends State<TrainShell> {
  int _index = 0;
  final _pages = const [
    TrainHomePage(),
    TrainRoutesPage(),
    TrainStationsPage(),
  ];
  final _items = const [
    (Icons.home_outlined, Icons.home, 'ပင်မ'),
    (Icons.train_outlined, Icons.train, 'လမ်းကြောင်း'),
    (Icons.location_city_outlined, Icons.location_city, 'ဘူတာ'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/icons/logo.png', width: 30, height: 30),
            const SizedBox(width: 9),
            const Text(
              'YBS AI · Train',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Bus သို့ပြန်သွားမည်',
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => widget.busPage),
            ),
            icon: const Icon(Icons.directions_bus_outlined),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 12,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: List.generate(_items.length, (i) {
                final item = _items[i];
                final active = _index == i;
                return Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => setState(() => _index = i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            active ? item.$2 : item.$1,
                            color: active
                                ? AppColors.emeraldDark
                                : AppColors.slate400,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.$3,
                            style: TextStyle(
                              fontSize: 11,
                              color: active
                                  ? AppColors.emeraldDark
                                  : AppColors.slate400,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class TrainHomePage extends StatelessWidget {
  const TrainHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = TrainDataRepository.instance;
    final routes = repo.routes;
    final stations = repo.stations;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.slate700],
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.train_rounded, color: AppColors.amber, size: 32),
              SizedBox(height: 12),
              Text(
                'ရထားခရီးစဉ်ကို လွယ်လွယ်ရှာပါ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'လမ်းကြောင်း၊ ဘူတာနှင့် အချိန်ဇယားများကို offline ကြည့်နိုင်ပါသည်။',
                style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                value: '${routes.length}',
                label: 'ရထားလမ်းကြောင်း',
                icon: Icons.route,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                value: '${stations.length}',
                label: 'ဘူတာ',
                icon: Icons.location_on,
                color: AppColors.emeraldDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ActionTile(
          icon: Icons.search,
          title: 'ရထားလမ်းကြောင်းရှာရန်',
          subtitle: 'Train code၊ မြို့၊ ဘူတာနာမည်ဖြင့် ရှာပါ',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const TrainRoutesPage(standalone: true),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _ActionTile(
          icon: Icons.location_city,
          title: 'ဘူတာများကြည့်ရန်',
          subtitle: 'ဘူတာတည်နေရာနှင့် ဖြတ်သန်းရထားများ',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const TrainStationsPage(standalone: true),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'အကြံပြုထားသော ဘူတာများ',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        ...stations
            .take(5)
            .map((station) => _StationMiniTile(station: station)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: UI.card(),
    child: Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: UI.card(),
    child: ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.brandLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.brand),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.brand),
    ),
  );
}

class TrainRoutesPage extends StatefulWidget {
  final bool standalone;
  const TrainRoutesPage({super.key, this.standalone = false});

  @override
  State<TrainRoutesPage> createState() => _TrainRoutesPageState();
}

class _TrainRoutesPageState extends State<TrainRoutesPage> {
  String _query = '';
  String _type = '';

  @override
  Widget build(BuildContext context) {
    final repo = TrainDataRepository.instance;
    final filtered = repo.searchRoutes(_query, type: _type);
    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              hintText: 'ရထားနံပါတ်၊ မြို့ သို့မဟုတ် ဘူတာဖြင့်ရှာရန်...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _FilterChip(
                label: 'အားလုံး',
                selected: _type.isEmpty,
                onTap: () => setState(() => _type = ''),
              ),
              ...['မြို့တွင်း', 'အမြန်ရထား', 'လူစီးကုန်တင်', 'စာပို့'].map(
                (type) => _FilterChip(
                  label: type,
                  selected: _type == type,
                  onTap: () => setState(() => _type = type),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const YbsEmptyView(
                  icon: Icons.train_outlined,
                  title: 'ရထားလမ်းကြောင်း မတွေ့ပါ',
                  message: 'ရှာဖွေမှုကို ပြန်စမ်းပါ။',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _TrainRouteCard(route: filtered[i]),
                ),
        ),
      ],
    );
    return widget.standalone
        ? Scaffold(
            appBar: AppBar(title: const Text('ရထားလမ်းကြောင်း')),
            body: body,
          )
        : body;
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: selected ? Colors.white : AppColors.textSecondary,
        ),
      ),
      selected: selected,
      selectedColor: AppColors.emeraldDark,
      backgroundColor: Colors.white,
      onSelected: (_) => onTap(),
    ),
  );
}

class _TrainRouteCard extends StatelessWidget {
  final TrainRoute route;
  const _TrainRouteCard({required this.route});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: UI.card(),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TrainRouteDetailPage(route: route)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: route.color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    route.title,
                    style: TextStyle(
                      color: route.color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    route.routeTypeTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.slate400),
              ],
            ),
            const SizedBox(height: 12),
            _Line(
              text: route.originStation,
              time: route.originTime,
              color: AppColors.emeraldDark,
            ),
            const SizedBox(height: 8),
            _Line(
              text: route.destinationStation,
              time: route.destinationTime,
              color: AppColors.rose,
            ),
            const Divider(height: 22),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Pill(route.type, icon: Icons.category_outlined),
                Pill(route.trainModel, icon: Icons.train_outlined),
                if (route.duration.isNotEmpty)
                  Pill(route.duration, icon: Icons.schedule),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _Line extends StatelessWidget {
  final String text;
  final String time;
  final Color color;
  const _Line({required this.text, required this.time, required this.color});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      Text(
        time,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    ],
  );
}

class TrainStationsPage extends StatefulWidget {
  final bool standalone;
  const TrainStationsPage({super.key, this.standalone = false});
  @override
  State<TrainStationsPage> createState() => _TrainStationsPageState();
}

class _TrainStationsPageState extends State<TrainStationsPage> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final filtered = TrainDataRepository.instance.searchStations(_query);
    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              hintText: 'ဘူတာနာမည်ဖြင့်ရှာရန်...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const YbsEmptyView(
                  icon: Icons.location_off_outlined,
                  title: 'ဘူတာ မတွေ့ပါ',
                  message: 'ရှာဖွေမှုကို ပြန်စမ်းပါ။',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _StationMiniTile(station: filtered[i]),
                ),
        ),
      ],
    );
    return widget.standalone
        ? Scaffold(
            appBar: AppBar(title: const Text('ရထားဘူတာများ')),
            body: body,
          )
        : body;
  }
}

class _StationMiniTile extends StatelessWidget {
  final TrainStation station;
  const _StationMiniTile({required this.station});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: UI.card(),
    child: ListTile(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TrainStationDetailPage(station: station),
        ),
      ),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.emeraldLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.location_on, color: AppColors.emeraldDark),
      ),
      title: Text(
        station.title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${station.departures.length} train departures · ${station.latitude.toStringAsFixed(4)}, ${station.longitude.toStringAsFixed(4)}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.emeraldDark),
    ),
  );
}

class TrainRouteDetailPage extends StatefulWidget {
  final TrainRoute route;
  const TrainRouteDetailPage({super.key, required this.route});

  @override
  State<TrainRouteDetailPage> createState() => _TrainRouteDetailPageState();
}

class _TrainRouteDetailPageState extends State<TrainRouteDetailPage> {
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  int _timeMinutes(String value) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) return -1;
    var hour = int.tryParse(match.group(1)!) ?? -1;
    final minute = int.tryParse(match.group(2)!) ?? -1;
    final period = match.group(3)!.toUpperCase();
    if (hour < 1 || hour > 12 || minute < 0 || minute > 59) return -1;
    if (period == 'AM') {
      if (hour == 12) hour = 0;
    } else if (hour != 12) {
      hour += 12;
    }
    return hour * 60 + minute;
  }

  ({int index, String status}) _currentJourney(
    List<TrainStationSchedule> schedules,
    DateTime now,
  ) {
    if (schedules.isEmpty) return (index: -1, status: 'မရရှိပါ');
    final timeline = <int>[];
    var dayOffset = 0;
    var previous = -1;
    for (final item in schedules) {
      final minutes = _timeMinutes(item.time);
      if (minutes < 0) continue;
      if (previous >= 0 && minutes < previous) dayOffset += 1440;
      timeline.add(minutes + dayOffset);
      previous = minutes;
    }
    if (timeline.length != schedules.length || timeline.isEmpty) {
      return (index: 0, status: 'အချိန်မသေချာပါ');
    }

    var target = now.hour * 60 + now.minute;
    final crossesMidnight = timeline.last >= 1440;
    if (target < timeline.first) {
      if (crossesMidnight) {
        target += 1440;
      } else {
        return (index: 0, status: 'မထွက်ခွာသေးပါ');
      }
    }
    if (target >= timeline.last) {
      return (index: timeline.length - 1, status: 'ခရီးစဉ်ပြီးဆုံးပါပြီ');
    }
    for (var i = 0; i < timeline.length - 1; i++) {
      if (target >= timeline[i] && target < timeline[i + 1]) {
        return (index: i, status: 'လက်ရှိရောက်နေပါပြီ');
      }
    }
    return (index: 0, status: 'မထွက်ခွာသေးပါ');
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    final journey = _currentJourney(route.stationSchedules, DateTime.now());
    final stops = route.stationSchedules
        .where((item) => item.latitude != null && item.longitude != null)
        .toList();
    final center = stops.isNotEmpty
        ? LatLng(stops.first.latitude!, stops.first.longitude!)
        : const LatLng(16.8, 96.15);
    final markers = [
      for (int i = 0; i < stops.length; i++)
        if (i == journey.index)
          Marker(
            point: LatLng(stops[i].latitude!, stops[i].longitude!),
            width: 54,
            height: 54,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.rose,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66F43F5E),
                    blurRadius: 2,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(Icons.train, color: Colors.white, size: 28),
            ),
          )
        else
          dotMarker(
            LatLng(stops[i].latitude!, stops[i].longitude!),
            color: i == 0
                ? AppColors.emeraldDark
                : i == stops.length - 1
                ? AppColors.rose
                : Colors.white,
            border: route.color,
            size: i == 0 || i == stops.length - 1 ? 16 : 10,
            label: stops[i].title,
            subtitle: stops[i].time,
          ),
    ];
    final lines = [
      if (stops.length > 1)
        Polyline(
          points: stops
              .map((item) => LatLng(item.latitude!, item.longitude!))
              .toList(),
          color: route.color,
          strokeWidth: 4,
        ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(route.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
        children: [
          SizedBox(
            height: 250,
            child: OsmMap(
              center: center,
              zoom: 8,
              markers: markers,
              polylines: lines,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Pill(route.type, icon: Icons.category_outlined),
                    Pill(route.direction, icon: Icons.swap_vert),
                    Pill(route.trainModel, icon: Icons.train),
                    if (route.duration.isNotEmpty)
                      Pill(route.duration, icon: Icons.schedule),
                  ],
                ),
                const SizedBox(height: 12),
                _CurrentJourneyCard(
                  schedule: route.stationSchedules,
                  activeIndex: journey.index,
                  status: journey.status,
                ),
                const SizedBox(height: 18),
                _InfoGrid(route: route),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'အချိန်ဇယား',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${route.stationSchedules.length} ဘူတာ',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...route.stationSchedules.asMap().entries.map(
                  (entry) => _ScheduleTile(
                    index: entry.key,
                    item: entry.value,
                    last: entry.key == route.stationSchedules.length - 1,
                    active: entry.key == journey.index,
                  ),
                ),
                if (route.description.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text(
                    'အကြောင်းအရာ',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    route.description,
                    style: const TextStyle(
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.slate100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: AppColors.slate500),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Live train location သည် static JSON ထဲတွင် မပါဝင်ပါ။ အချိန်ဇယားကို source update အတိုင်း အသုံးပြုပါ။',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentJourneyCard extends StatelessWidget {
  final List<TrainStationSchedule> schedule;
  final int activeIndex;
  final String status;

  const _CurrentJourneyCard({
    required this.schedule,
    required this.activeIndex,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final station = activeIndex >= 0 && activeIndex < schedule.length
        ? schedule[activeIndex].title
        : 'ဘူတာအချက်အလက် မရရှိပါ';
    final active = status == 'လက်ရှိရောက်နေပါပြီ';
    final color = active ? AppColors.rose : AppColors.brand;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: active ? AppColors.roseLight : AppColors.slate100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Row(
        children: [
          Icon(
            active ? Icons.radio_button_checked : Icons.schedule,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'လက်ရှိအချိန် $currentTime · $status',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  active ? 'ရထားရောက်နေသောဘူတာ: $station' : station,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  final TrainRoute route;
  const _InfoGrid({required this.route});
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      _InfoBox(
        label: 'စမှတ်',
        value: '${route.originStation}\n${route.originTime}',
      ),
      _InfoBox(
        label: 'ဆုံးမှတ်',
        value: '${route.destinationStation}\n${route.destinationTime}',
      ),
      _InfoBox(label: 'ဖြတ်သန်းဘူတာ', value: '${route.totalStations} ခု'),
      _InfoBox(label: 'လမ်းကြောင်း', value: route.way),
    ],
  );
}

class _InfoBox extends StatelessWidget {
  final String label;
  final String value;
  const _InfoBox({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 160,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.slate500),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}

class _ScheduleTile extends StatelessWidget {
  final int index;
  final TrainStationSchedule item;
  final bool last;
  final bool active;
  const _ScheduleTile({
    required this.index,
    required this.item,
    required this.last,
    required this.active,
  });
  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 30,
          child: Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.rose
                      : index == 0
                      ? AppColors.emeraldDark
                      : last
                      ? AppColors.rose
                      : AppColors.slate300,
                  shape: BoxShape.circle,
                  boxShadow: active
                      ? const [
                          BoxShadow(
                            color: Color(0x55F43F5E),
                            blurRadius: 0,
                            spreadRadius: 5,
                          ),
                        ]
                      : null,
                ),
              ),
              if (!last)
                Expanded(child: Container(width: 2, color: AppColors.slate200)),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: active ? AppColors.roseLight : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: active
                    ? Border.all(color: AppColors.rose.withValues(alpha: .25))
                    : null,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                        color: active ? AppColors.rose : AppColors.text,
                      ),
                    ),
                  ),
                  if (active)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Pill(
                        'လက်ရှိ',
                        bg: AppColors.rose,
                        fg: Colors.white,
                        icon: Icons.my_location,
                      ),
                    ),
                  Text(
                    item.time,
                    style: TextStyle(
                      color: active ? AppColors.rose : AppColors.brand,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class TrainStationDetailPage extends StatelessWidget {
  final TrainStation station;
  const TrainStationDetailPage({super.key, required this.station});

  Future<void> _openMap() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${station.latitude},${station.longitude}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final departures = TrainDataRepository.instance.departuresFor(station);
    final point = LatLng(station.latitude, station.longitude);
    final marker = dotMarker(
      point,
      color: AppColors.emeraldDark,
      border: Colors.white,
      size: 18,
      label: station.title,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          station.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        children: [
          SizedBox(
            height: 220,
            child: OsmMap(center: point, zoom: 14, markers: [marker]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('တည်နေရာ', style: UI.label),
                          Text(
                            '${station.latitude.toStringAsFixed(6)}, ${station.longitude.toStringAsFixed(6)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _openMap,
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Maps'),
                    ),
                  ],
                ),
                if (station.description.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text(
                    'အကြောင်းအရာ',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    station.description,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'ဖြတ်သန်းရထားများ (${departures.length})',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                if (departures.isEmpty)
                  const Text(
                    'ဒီဘူတာအတွက် အချိန်ဇယားမတွေ့ပါ။',
                    style: TextStyle(color: AppColors.textSecondary),
                  )
                else
                  ...departures.map(
                    (item) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: UI.card(),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.train,
                          color: AppColors.emeraldDark,
                        ),
                        title: Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${item.routeTypeTitle} · ${item.direction} · ${item.trainModel}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          item.time,
                          style: const TextStyle(
                            color: AppColors.brand,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
