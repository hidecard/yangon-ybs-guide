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
import 'widgets/telegram_connect_sheet.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  NotifyService.instance.init();
  initBackgroundAlertService();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: const YbsApp(),
    ),
  );
}

class YbsApp extends StatelessWidget {
  const YbsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YBS Guide',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.light(),
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
    YbsNewPage(),
    RoutesPage(),
    FindRoutePage(),
    FavoritesPage(),
  ];

  static const _navItems = [
    (Icons.home_outlined, Icons.home, 'ပင်မ'),
    (Icons.chat_bubble_outline, Icons.chat_bubble, 'Assistant'),
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

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.directions_bus,
                  size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text('YBS Guide',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.text)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: AppColors.slate100,
                  borderRadius: BorderRadius.circular(4)),
              child: const Text(AppConfig.appVersion,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate400)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Telegram ချိတ်ဆက်',
            onPressed: () => TelegramConnectSheet.show(context),
            icon: const Icon(Icons.smart_toy_outlined),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsPage())),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: TabSwitcher(
        onSwitch: (i) => setState(() => _index = i),
        child: IndexedStack(index: _index, children: _pages),
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: AppColors.brandLight,
          labelTextStyle: WidgetStateProperty.all(
              const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
        ),
        child: NavigationBar(
          height: 66,
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: _navItems
              .map((it) => NavigationDestination(
                    icon: Icon(it.$1, color: AppColors.slate400),
                    selectedIcon: Icon(it.$2, color: AppColors.brand),
                    label: it.$3,
                  ))
              .toList(),
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
            Text('YBS Guide',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: AppColors.text)),
            SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 8),
                Text('အချက်အလက်များ ရယူနေပါသည်...',
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 13)),
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
      vsync: this, duration: const Duration(milliseconds: 700))
    ..repeat(reverse: true);

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
            borderRadius: BorderRadius.circular(24)),
        child: const Icon(Icons.directions_bus, size: 40, color: Colors.white),
      ),
    );
  }
}
