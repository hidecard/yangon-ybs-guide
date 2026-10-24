import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../data/route_finder.dart';
import '../models.dart';
import '../services/api_service.dart';
import '../services/local_store.dart';
import '../services/location_service.dart';
import '../services/notify_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/nav.dart';
import '../pages/assistant_page.dart';
import '../pages/find_route_page.dart';
import '../pages/routes_page.dart';
import '../widgets/route_badge.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    _loadNotif();
  }

  Future<void> _loadNotif() async {
    final items = await ApiService.instance.fetchNotifications();
    if (items.isEmpty || !mounted) return;
    final latest = items.first;
    final lastSeen = await LocalStore.instance.lastSeenNotification();
    if (latest.id != lastSeen) {
      await LocalStore.instance.setLastSeenNotification(latest.id);
      // Request permission and show phone notification instead of UI card
      await NotifyService.instance.requestPermission();
      await NotifyService.instance.showAdminNotification(latest);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    final quickActions = [
      (
        Icons.search,
        'လမ်းကြောင်း ရှာရန်',
        AppColors.primary,
        AppConfig.findRouteTab,
      ),
      (
        Icons.directions_bus,
        'ကားလိုင်းများ',
        AppColors.brand,
        AppConfig.routesTab,
      ),
      if (AppConfig.showYbsNew)
        (
          Icons.campaign,
          'YBS New',
          const Color(0xFFB45309),
          AppConfig.ybsNewTab,
        ),
      (
        Icons.chat_bubble,
        'Assistant',
        AppColors.violet,
        AppConfig.assistantTab,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        const Center(
          child: Column(
            children: [
              Text(
                'ရန်ကုန် YBS လမ်းညွှန်',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'ကားလိုင်းရှာဖွေခြင်း၊ လမ်းကြောင်းရှာခြင်းနှင့် မြေပုံကြည့်ရှုခြင်း — အားလုံးတစ်နေရာတည်း',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.slate500, fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: quickActions
              .map((a) => _quickAction(a.$1, a.$2, a.$3, a.$4))
              .toList(),
        ),
        const Text('ခရီးသွားရန် အကြံပြုချက်များ', style: UI.sectionTitle),
        const SizedBox(height: 12),
        ..._travelTips.map(_tipCard),
        const SizedBox(height: 12),
        _RecentSearches(state: state),
      ],
    );
  }

  Widget _quickAction(IconData icon, String label, Color color, int tabIndex) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openQuickAction(context, tabIndex),
      child: Container(
        decoration: UI.card(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  void _openQuickAction(BuildContext context, int tabIndex) {
    // Open the three primary actions as independent routes. This keeps the
    // tap target reliable even when the optional YBS New tab is hidden and
    // avoids relying on a stale IndexedStack position from a saved build.
    if (tabIndex == AppConfig.findRouteTab) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const FindRoutePage(withScaffold: true),
        ),
      );
      return;
    }
    if (tabIndex == AppConfig.routesTab) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const _QuickActionPage(
            title: 'ကားလိုင်းများ',
            child: RoutesPage(),
          ),
        ),
      );
      return;
    }
    if (tabIndex == AppConfig.assistantTab) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const _QuickActionPage(
            title: 'Assistant',
            child: AssistantPage(),
          ),
        ),
      );
      return;
    }
    _switchTab(context, tabIndex);
  }

  void _switchTab(BuildContext context, int index) {
    final switchTab = TabSwitcher.of(context);
    if (switchTab != null && index >= 0) switchTab(index);
  }

  Widget _tipCard((IconData, String, String) tip) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: UI.card(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.slate100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(tip.$1, size: 18, color: AppColors.slate600),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tip.$2,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tip.$3,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.slate500,
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

const _travelTips = <(IconData, String, String)>[
  (
    Icons.info_outline,
    'ရာသီဥတု ပြင်ဆင်မှု',
    'နေပူရင် ဦးထုပ်/နေကာမျက်မှန်၊ မိုးရွာရင် ထီးဆောင်သွားပါ။',
  ),
  (
    Icons.person_outline,
    'လုံခြုံရေး သတိပေးချက်',
    'လူကျပ်တဲ့အချိန်မှာ ခိတ်နှိုက်နဲ့ သူခိုးတွေကို အထူးသတိထားပါ။',
  ),
  (
    Icons.navigation_outlined,
    'မှတ်တိုင်မကျော်စေရန်',
    'အိပ်ပျော်မသွားအောင် ဖုန်းအချက်ပေးသံ ပေးထားပါ။',
  ),
  (
    Icons.credit_card,
    'YBS ကတ် အကြံပြုချက်',
    'ကတ်ထဲ ငွေကြိုတင်ဖြည့်ပြီး လက်ကျန်ငွေကို ပုံမှန်စစ်ဆေးပါ။',
  ),
];

/// InheritedWidget to let child pages switch bottom-nav tabs.
class _QuickActionPage extends StatelessWidget {
  final String title;
  final Widget child;
  const _QuickActionPage({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: child,
    );
  }
}

class TabSwitcher extends InheritedWidget {
  final void Function(int) onSwitch;
  const TabSwitcher({super.key, required this.onSwitch, required super.child});
  static void Function(int)? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TabSwitcher>()?.onSwitch;
  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => false;
}

// ---------- Nearest stops card ----------
class _NearestStopsCard extends StatefulWidget {
  final AppState state;
  const _NearestStopsCard({required this.state});
  @override
  State<_NearestStopsCard> createState() => _NearestStopsCardState();
}

class _NearestStopsCardState extends State<_NearestStopsCard> {
  ({double lat, double lng})? _pos;
  bool _locating = false;
  String? _error;

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    final p = await LocationService.instance.currentPosition();
    if (!mounted) return;
    if (p == null) {
      setState(() {
        _error =
            'တည်နေရာ မရရှိသေးပါ။ Location ဖွင့်ထားပြီး permission ကို Allow လုပ်ပါ။';
        _locating = false;
      });
      return;
    }
    setState(() {
      _pos = (lat: p.latitude, lng: p.longitude);
      _locating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final nearest = _pos == null
        ? <(BusStop, double)>[]
        : (state.stops
                  .map(
                    (s) => (s, getDistance(_pos!.lat, _pos!.lng, s.lat, s.lng)),
                  )
                  .toList()
                ..sort((a, b) => a.$2.compareTo(b.$2)))
              .take(5)
              .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _locating ? null : _locate,
                  borderRadius: BorderRadius.circular(10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: AppColors.rose.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          size: 18,
                          color: AppColors.rose,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'အနီးနားမှတ်တိုင်များ',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'ယခုနေရာအနီးရှိ မှတ်တိုင်များ',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.slate500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _locating ? null : _locate,
                style: FilledButton.styleFrom(
                  backgroundColor: _pos == null
                      ? AppColors.rose
                      : AppColors.slate100,
                  foregroundColor: _pos == null
                      ? Colors.white
                      : AppColors.slate600,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                icon: _locating
                    ? const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.gps_fixed, size: 13),
                label: Text(
                  _pos == null ? 'ယခု နေရာ' : 'ပြန်ရယူ',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_pos == null && _error == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '“ယခုနေရာ” ကိုနှိပ်ပြီး သင့်အနီးရှိ မှတ်တိုင်များနှင့် ကားလိုင်းများကို ကြည့်ရှုနိုင်ပါသည်။',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.slate500,
                  height: 1.35,
                ),
              ),
            ),
          if (_error != null)
            Text(
              _error!,
              style: const TextStyle(fontSize: 12, color: AppColors.rose),
            ),
          ...nearest.map((e) => _stopRow(context, state, e.$1, e.$2)),
        ],
      ),
    );
  }

  Widget _stopRow(
    BuildContext context,
    AppState state,
    BusStop stop,
    double distance,
  ) {
    final passing = state.routesForStop(stop.nameMm, limit: 3);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Nav.openStop(context, stop),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 18,
                color: AppColors.rose,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.nameMm,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: passing.isEmpty
                          ? [
                              const Text(
                                'ကားလိုင်း မတွေ့ပါ',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.slate400,
                                ),
                              ),
                            ]
                          : passing
                                .map(
                                  (r) => RouteBadge(
                                    routeId: r.id,
                                    color: r.color,
                                    small: true,
                                  ),
                                )
                                .toList(),
                    ),
                  ],
                ),
              ),
              Pill(
                '${(distance * 1000).toStringAsFixed(0)}m',
                bg: AppColors.rose.withValues(alpha: 0.12),
                fg: AppColors.rose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Recent searches ----------
class _RecentSearches extends StatefulWidget {
  final AppState state;
  const _RecentSearches({required this.state});
  @override
  State<_RecentSearches> createState() => _RecentSearchesState();
}

class _RecentSearchesState extends State<_RecentSearches> {
  List<TripHistoryItem> _history = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final h = await LocalStore.instance.tripHistory();
    if (mounted) setState(() => _history = h);
  }

  @override
  Widget build(BuildContext context) {
    if (_history.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('မကြာခင် ရှာဖွေခဲ့', style: UI.sectionTitle),
            const Spacer(),
            TextButton.icon(
              onPressed: () async {
                await LocalStore.instance.clearTripHistory();
                _load();
              },
              icon: const Icon(Icons.delete_outline, size: 14),
              label: const Text('ဖယ်ရှားမည်'),
              style: TextButton.styleFrom(foregroundColor: AppColors.slate400),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._history.map(
          (item) => InkWell(
            onTap: () => _onTapItem(context, item),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: UI.card(),
              child: Row(
                children: [
                  Icon(
                    item.type == 'search'
                        ? Icons.search
                        : item.type == 'route'
                        ? Icons.directions_bus
                        : Icons.location_on_outlined,
                    size: 18,
                    color: AppColors.brand,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        if (item.subtitle != null)
                          Text(
                            item.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.slate400,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    timeAgo(item.timestamp),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.slate400,
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      await LocalStore.instance.removeTripHistory(item.id);
                      _load();
                    },
                    icon: const Icon(Icons.close, size: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _onTapItem(BuildContext context, TripHistoryItem item) {
    switch (item.type) {
      case 'route':
        final r = widget.state.repo.routeById(item.routeId ?? '');
        if (r != null) Nav.openRoute(context, r);
        break;
      case 'stop':
        final stop = widget.state.stops
            .where((s) => s.nameMm == item.label)
            .firstOrNull;
        if (stop != null) Nav.openStop(context, stop);
        break;
      case 'search':
      default:
        // Push a fresh Find Route page pre-filled with the search. (The page
        // lives in a persistent IndexedStack, so simply switching tabs would
        // not re-read the pending search — a fresh route ensures it loads.)
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FindRoutePage(
              initialStart: item.label,
              initialEnd: item.subtitle ?? '',
              withScaffold: true,
            ),
          ),
        );
        break;
    }
  }
}
