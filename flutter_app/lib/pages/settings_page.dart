import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../services/api_service.dart';
import '../services/local_store.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/modals.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _syncStatus = 'idle';
  String? _cacheSize;
  String _userId = '';
  AlertStatus? _tg;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _userId = await LocalStore.instance.getUserId();
    if (!mounted) return;
    _cacheSize = await context.read<AppState>().repo.cacheInfo();
    final tg = await ApiService.instance.getAlertStatus(_userId);
    if (mounted) setState(() => _tg = tg);
  }

  Future<void> _sync() async {
    setState(() => _syncStatus = 'updating');
    await context.read<AppState>().reloadData();
    if (!mounted) return;
    _cacheSize = await context.read<AppState>().repo.cacheInfo();
    if (!mounted) return;
    setState(() => _syncStatus = 'done');
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _syncStatus = 'idle');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _dataCard(),
          const SizedBox(height: 16),
          _telegramCard(),
          const SizedBox(height: 16),
          _notifSetupCard(),
          const SizedBox(height: 16),
          _developerCard(),
          const SizedBox(height: 16),
          _whatsNewCard(),
          const SizedBox(height: 16),
          _feedbackCard(),
          const SizedBox(height: 16),
          _donationCard(),
        ],
      ),
    );
  }

  Widget _card({required Widget child, Color? color}) => Container(
        padding: const EdgeInsets.all(20),
        decoration: UI.card(color: color),
        child: child,
      );

  Widget _cardHeader(IconData icon, Color bg, String title, String sub,
      {Color iconColor = Colors.white}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration:
              BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15)),
              Text(sub,
                  style:
                      const TextStyle(fontSize: 13, color: AppColors.slate500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dataCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.sync, AppColors.primary, 'Application Data',
              'လမ်းကြောင်းနှင့် မှတ်တိုင်အချက်အလက်များ အပ်ဒိတ်လုပ်ရန်'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Offline Database',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
                if (_cacheSize != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Local cache: $_cacheSize',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.slate400)),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: _syncStatus == 'done'
                            ? AppColors.emerald
                            : AppColors.primary),
                    onPressed: _syncStatus == 'updating' ? null : _sync,
                    child: Text(_syncStatus == 'updating'
                        ? 'ခဏစောင့်ပါ...'
                        : _syncStatus == 'done'
                            ? '✓ Sync အောင်မြင်ပါသည်'
                            : 'လမ်းကြောင်းများ Update လုပ်မည်'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _telegramCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.smart_toy, AppColors.blue, 'Telegram သတိပေးချက်',
              'မှတ်တိုင် နီးကပ်လျှင် သတိပေးခံရန် ချိတ်ဆက်ပါ'),
          const SizedBox(height: 16),
          if (_tg?.stopName != null)
            _infoBox(AppColors.emeraldLight,
                '🔔 ${_tg!.stopName} မှတ်တိုင်သို့ ရောက်လျှင် သတိပေးပါမည်။')
          else if (_tg?.linked == true)
            _infoBox(AppColors.emeraldLight,
                '✅ ချိတ်ဆက်ပြီးပါပြီ။ မှတ်တိုင်တစ်ခုချက် ဖွင့်ပြီး "သတိပေးပါ" ကို နှိပ်ပါ။')
          else
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF26A5E4)),
                    onPressed: () => launchUrl(
                        Uri.parse(LocalStore.instance.connectUrl(_userId)),
                        mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.send),
                    label: const Text('Telegram နဲ့ ချိတ်ဆက်မည်'),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: AppColors.slate100,
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Expanded(
                          child: SelectableText('/start $_userId',
                              style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600))),
                      TextButton(
                        onPressed: () => Clipboard.setData(
                            ClipboardData(text: _userId)),
                        child: const Text('ကူးယူ'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _notifSetupCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.notifications_active, AppColors.amber,
              'အကြောင်းကြားချက် ဆက်တင်',
              'App ပိတ်ထားသည့်တိုင် သတိပေးချက် ရောက်စေရန်'),
          const SizedBox(height: 14),
          const Text(
            'အချို့ ဖုန်းများတွင် ဘက်ထရီ သက်သာစေရန် App များကို အလိုအလျောက် ပိတ်တတ်ပါသည်။ '
            'သတိပေးချက် အပြည့်အဝရရှိစေရန် အောက်ပါအဆင့်များအတိုင်း ဆက်တင် လုပ်ပေးပါ -',
            style: TextStyle(fontSize: 13, color: AppColors.slate600),
          ),
          const SizedBox(height: 14),
          _step(1, 'Battery (ဘက်ထရီ) သတိပေးချက်',
              'Settings → Battery → Battery optimization သို့သွားပါ။ "YBS Guide" ကို ရှာပြီး "Don\'t optimize" (သို့မဟုတ် "Unrestricted") ဟု သတ်မှတ်ပါ။'),
          _step(2, 'Notification (အကြောင်းကြားချက်) ခွင့်ပြု',
              'Settings → Apps → YBS Guide → Notifications သို့သွားပါ။ "Show notifications" ကို ဖွင့်ပါ။ "Admin Notifications" နှင့် "Arrival Alerts" channel များကို "Important" သို့မဟုတ် "Urgent" သတ်မှတ်ပါ။'),
          _step(3, 'Autostart / Auto-launch',
              'Settings → Apps → YBS Guide (သို့မဟုတ် "Manage apps") → Autostart / Auto-launch ကို ဖွင့်ပါ (Xiaomi, Oppo, Vivo, Huawei စသည့် ဖုန်းများတွင် လိုအပ်ပါသည်)။'),
          _step(4, 'Background data (ဒေတာ) ခွင့်ပြု',
              'Settings → Apps → YBS Guide → Mobile data သို့သွားပါ။ "Allow background data" ကို ဖွင့်ပါ သို့မဟုတ် "Data usage while Data saver is on" ကို ခွင့်ပြုပါ။'),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.amberLight,
                borderRadius: BorderRadius.circular(12)),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.amber, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'အထက်ပါအဆင့်များ ပြီးပါက App ကို ပိတ်ထားသည့်တိုင် Admin သတင်းများ နှင့် မှတ်တိုင်အနီးရောက်သတိပေးချက်များ အလိုအလျောက် ရောက်ရှိပါမည်။',
                    style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _step(int n, String title, String desc) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.amber,
                shape: BoxShape.circle,
              ),
              child: Text('$n',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(desc,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.slate500)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _infoBox(Color bg, String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Text(text,
            style: const TextStyle(
                fontSize: 14, color: AppColors.emeraldDark)),
      );

  Widget _developerCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.info_outline, AppColors.primary, 'Developer Info',
              'ဆော့ဝဲရေးသားသူ အချက်အလက်'),
          const SizedBox(height: 16),
          _kv('App Name', 'YBS Guide'),
          _kv('Version', AppConfig.appVersion),
          _kv('Developer', 'Arkar Yan'),
          _kv('Contact', 'info@arkaryan.net'),
          _kv('Website', 'https://www.arkaryan.net/'),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 100,
                child: Text(k,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.slate400))),
            Expanded(
                child: Text(v,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500))),
          ],
        ),
      );

  Widget _whatsNewCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.auto_awesome, const Color(0xFFF59E0B),
              "What's New in V3.1", 'ဗားရှင်းသစ် အချက်အလက်များ'),
          const SizedBox(height: 16),
          _feature('AI-Powered Assistant',
              'လမ်းကြောင်းများကို မြန်မာလို မေးမြန်းနိုင်ခြင်း။'),
          _feature('Telegram Alert System',
              'မှတ်တိုင်နီးကပ်လျှင် Telegram မှတဆင့် သတိပေးချက်ပေးပို့ခြင်း။'),
          _feature('Advanced Route Finding',
              'အမြန်ဆုံးနှင့် အဆင်ပြေဆုံး လမ်းကြောင်းများကို ရှာဖွေပေးခြင်း။'),
        ],
      ),
    );
  }

  Widget _feature(String title, String desc) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle,
                size: 16, color: AppColors.emerald),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(desc,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.slate500)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _feedbackCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.chat_bubble_outline, AppColors.brandLight,
              'အကြံပြုချက် / အမှားတွက်',
              'ကားလိုင်း သို့မဟုတ် App နှင့်ပတ်သက်သော အကြံပြုချက် ပို့ပါ။',
              iconColor: AppColors.brand),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style:
                  FilledButton.styleFrom(backgroundColor: AppColors.brand),
              onPressed: () => FeedbackDialog.show(context),
              child: const Text('အကြံပြုချက် ပို့မည်'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _donationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.slate800]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.auto_awesome,
                    color: Color(0xFFFBBF24), size: 20),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Support This Project',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
                    Text('YBS Guide ကို ဆက်လက်ဖွံ့ဖြိုးရန် ကူညီနိုင်ပါသည်',
                        style: TextStyle(
                            color: AppColors.slate300, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _payRow('Kpay', '09446941632'),
          const SizedBox(height: 8),
          _payRow('Wave Money', '09758430371'),
        ],
      ),
    );
  }

  Widget _payRow(String label, String number) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppColors.slate400, fontSize: 10)),
                Text(number,
                    style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: number));
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ကူးယူပြီးပါပြီ')));
            },
            icon: const Icon(Icons.copy, color: AppColors.slate400, size: 18),
          ),
        ],
      ),
    );
  }
}
