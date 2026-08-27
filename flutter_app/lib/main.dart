import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config.dart';
import 'state/app_state.dart';
import 'services/notify_service.dart';
import 'services/background_alert_service.dart';
import 'theme.dart';
import 'pages/home_page.dart';
import 'pages/routes_page.dart';
import 'pages/find_route_page.dart';
import 'pages/ybs_new_page.dart';
import 'pages/assistant_page.dart';
import 'pages/favorites_page.dart';
import 'pages/settings_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializePlatformServices();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: const YbsApp(),
    ),
  );
}

Future<void> _initializePlatformServices() async {
  // Service initialization is best-effort: notifications/background execution
  // can be unavailable on web or denied by the user, but must not block startup.
  try {
    await NotifyService.instance.init();
  } catch (_) {}
  try {
    await initBackgroundAlertService();
  } catch (_) {}
}

class YbsApp extends StatelessWidget {
  const YbsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YBS AI',
      debugShowCheckedModeBanner: false,
      // Keep the original light-mode visual design regardless of device theme.
      theme: AppTheme.light(),
      themeMode: ThemeMode.light,
      home: const RootShell(),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  final _pages = const [
    HomePage(),
    AssistantPage(),
    if (AppConfig.showYbsNew) YbsNewPage(),
    RoutesPage(),
    FindRoutePage(),
    FavoritesPage(),
  ];

  static const _navItems = [
    (Icons.home_outlined, Icons.home, 'ပင်မ'),
    (Icons.chat_bubble_outline, Icons.chat_bubble, 'Assistant'),
    if (AppConfig.showYbsNew)
      (Icons.campaign_outlined, Icons.campaign, 'YBS New'),
    (Icons.directions_bus_outlined, Icons.directions_bus, 'လိုင်းများ'),
    (Icons.search, Icons.search, 'လမ်းကြောင်း'),
    (Icons.star_border, Icons.star, 'အကြိုက်'),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (state.loading) {
      return const _SplashScreen();
    }
    if (state.initError != null) {
      return _StartupErrorScreen(message: state.initError!);
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.directions_bus,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'YBS AI',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.text,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                AppConfig.appVersion,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate400,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'ဆက်တင်များ',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: TabSwitcher(
        onSwitch: _selectTab,
        child: IndexedStack(index: _index, children: _pages),
      ),
      bottomNavigationBar: _YbsBottomNav(
        index: _index,
        items: _navItems,
        onTap: _selectTab,
      ),
    );
  }

  void _selectTab(int index) {
    if (!mounted || index < 0 || index >= _pages.length) return;
    if (_index == index) return;
    setState(() => _index = index);
  }
}

class _YbsBottomNav extends StatelessWidget {
  final int index;
  final List<(IconData, IconData, String)> items;
  final ValueChanged<int> onTap;
  const _YbsBottomNav({
    required this.index,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(items.length, (i) {
              final item = items[i];
              final active = i == index;
              return Expanded(
                child: _NavItem(
                  active: active,
                  icon: active ? item.$2 : item.$1,
                  label: item.$3,
                  onTap: () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final bool active;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _NavItem({
    required this.active,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: label,
      hint: active ? 'လက်ရှိစာမျက်နှာ' : 'ဖွင့်ရန်နှိပ်ပါ',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            style: TextStyle(
              fontSize: 11,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? AppColors.brand : AppColors.slate400,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: active ? AppColors.brand : AppColors.slate400,
                ),
                const SizedBox(height: 4),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  final String message;
  const _StartupErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.roseLight,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.cloud_off_outlined,
                  size: 40,
                  color: AppColors.rose,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'YBS AI',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => context.read<AppState>().init(),
                icon: const Icon(Icons.refresh),
                label: const Text('ပြန်လည်ကြိုးစားမည်'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BouncingBus(),
            SizedBox(height: 18),
            Text(
              'YBS AI',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: AppColors.text,
              ),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text(
                  'အချက်အလက်များ ရယူနေပါသည်...',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BouncingBus extends StatefulWidget {
  const _BouncingBus();
  @override
  State<_BouncingBus> createState() => _BouncingBusState();
}

class _BouncingBusState extends State<_BouncingBus>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) =>
          Transform.translate(offset: Offset(0, -10 * _c.value), child: child),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.directions_bus, size: 40, color: Colors.white),
      ),
    );
  }
}
