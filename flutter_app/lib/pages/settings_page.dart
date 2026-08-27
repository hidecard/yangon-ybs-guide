import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/modals.dart';
import '../services/notify_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static final _sections = <_Section>[
    _Section(
      Icons.sync,
      AppColors.primary,
      'Application Data',
      'လမ်းကြောင်းနှင့် မှတ်တိုင် အချက်အလက် အပ်ဒိတ်လုပ်ရန်',
      _DataSection(),
    ),
    _Section(
      Icons.notifications_active,
      AppColors.amber,
      'အကြောင်းကြားချက် ဆက်တင်',
      'App ပိတ်ထားသည့်တိုင် သတိပေးချက် ရောက်စေရန်',
      const _NotifSetupSection(),
    ),
    _Section(
      Icons.groups,
      AppColors.violet,
      'အဖွဲ့အစည်း နှင့် စည်းကမ်းချက်များ',
      'ဖန်တီးသူများနှင့် အသုံးပြုမှု စည်းကမ်းများ',
      const _TeamConditionsSection(),
    ),
    _Section(
      Icons.info_outline,
      AppColors.primary,
      'ဆော့ဝဲအကြောင်း',
      'App အသုံးပြုပုံနှင့် ဗားရှင်း',
      const _AboutSection(),
    ),
    _Section(
      Icons.privacy_tip,
      AppColors.emerald,
      'ကိုယ်ရေးအချက်အလက် မူဝါဒ',
      'ဒေတာသိုလှောင်မှုနှင့် လုံခြုံရေး',
      const _PrivacySection(),
    ),
    _Section(
      Icons.auto_awesome,
      const Color(0xFFF59E0B),
      "What's New in V3.3.2",
      'ဗားရှင်းသစ် အချက်အလက်များ',
      const _WhatsNewSection(),
    ),
    _Section(
      Icons.chat_bubble_outline,
      AppColors.brand,
      'အကြံပြုချက် / အမှားတွက်',
      'ကားလိုင်း သို့မဟုတ် App နှင့်ပတ်သက်သော အကြံပြုချက်',
      const _FeedbackSection(),
    ),
    _Section(
      Icons.favorite,
      AppColors.rose,
      'Support This Project',
      'YBS AI ကို ဆက်လက်ဖွံ့ဖြိုးရန် ကူညီပါ',
      const _DonationSection(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ဆက်တင်များ')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _sections.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final s = _sections[i];
          return _MenuRow(
            icon: s.icon,
            color: s.color,
            title: s.title,
            subtitle: s.subtitle,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => s.page),
            ),
          );
        },
      ),
    );
  }
}

class _Section {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget page;
  const _Section(this.icon, this.color, this.title, this.subtitle, this.page);
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _MenuRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title — $subtitle',
      hint: 'အသေးစိတ်ဖွင့်ရန် နှိပ်ပါ',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.slate400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Generic detail page that wraps a section's content in its own Scaffold.
class SettingsSectionPage extends StatelessWidget {
  final String title;
  final Widget child;
  const SettingsSectionPage({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(padding: const EdgeInsets.all(16), children: [child]),
    );
  }
}

Widget _card({required Widget child, Color? color}) => Container(
  padding: const EdgeInsets.all(20),
  decoration: UI.card(color: color),
  child: child,
);

Widget _cardHeader(
  IconData icon,
  Color bg,
  String title,
  String sub, {
  Color iconColor = Colors.white,
}) {
  return Row(
    children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            Text(
              sub,
              style: const TextStyle(fontSize: 13, color: AppColors.slate500),
            ),
          ],
        ),
      ),
    ],
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
        child: Text(
          '$n',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              desc,
              style: const TextStyle(fontSize: 12, color: AppColors.slate500),
            ),
          ],
        ),
      ),
    ],
  ),
);

Widget _kv(String k, String v) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 100,
        child: Text(
          k,
          style: const TextStyle(fontSize: 12, color: AppColors.slate400),
        ),
      ),
      Expanded(
        child: Text(
          v,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
    ],
  ),
);

Widget _link(String k, String url) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 100,
        child: Text(
          k,
          style: const TextStyle(fontSize: 12, color: AppColors.slate400),
        ),
      ),
      Expanded(
        child: InkWell(
          onTap: () =>
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          child: Text(
            url,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.brand,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ],
  ),
);

Widget _feature(String title, String desc) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(Icons.check_circle, size: 16, color: AppColors.emerald),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            Text(
              desc,
              style: const TextStyle(fontSize: 12, color: AppColors.slate500),
            ),
          ],
        ),
      ),
    ],
  ),
);

// ---------------- Application Data ----------------
class _DataSection extends StatefulWidget {
  const _DataSection();
  @override
  State<_DataSection> createState() => _DataSectionState();
}

class _DataSectionState extends State<_DataSection> {
  String _syncStatus = 'idle';
  String? _cacheSize;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _cacheSize = await context.read<AppState>().repo.cacheInfo();
    if (mounted) setState(() {});
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
    return SettingsSectionPage(
      title: 'Application Data',
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardHeader(
              Icons.sync,
              AppColors.primary,
              'Application Data',
              'လမ်းကြောင်းနှင့် မှတ်တိုင်အချက်အလက်များ အပ်ဒိတ်လုပ်ရန်',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Offline Database',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  if (_cacheSize != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Local cache: $_cacheSize',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.slate400,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _syncStatus == 'done'
                            ? AppColors.emerald
                            : AppColors.primary,
                      ),
                      onPressed: _syncStatus == 'updating' ? null : _sync,
                      child: Text(
                        _syncStatus == 'updating'
                            ? 'ခဏစောင့်ပါ...'
                            : _syncStatus == 'done'
                            ? '✓ Sync အောင်မြင်ပါသည်'
                            : 'လမ်းကြောင်းများ Update လုပ်မည်',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- Notification Setup ----------------
class _NotifSetupSection extends StatelessWidget {
  const _NotifSetupSection();
  @override
  Widget build(BuildContext context) {
    return SettingsSectionPage(
      title: 'အကြောင်းကြားချက် ဆက်တင်',
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardHeader(
              Icons.notifications_active,
              AppColors.amber,
              'အကြောင်းကြားချက် ဆက်တင်',
              'App ပိတ်ထားသည့်တိုင် သတိပေးချက် ရောက်စေရန်',
            ),
            const SizedBox(height: 14),
            const Text(
              'အချို့ ဖုန်းများတွင် ဘက်ထရီ သက်သာစေရန် App များကို အလိုအလျောက် ပိတ်တတ်ပါသည်။ '
              'သတိပေးချက် အပြည့်အဝရရှိစေရန် အောက်ပါအဆင့်များအတိုင်း ဆက်တင် လုပ်ပေးပါ -',
              style: TextStyle(fontSize: 13, color: AppColors.slate600),
            ),
            const SizedBox(height: 14),
            _step(
              1,
              'Battery (ဘက်ထရီ) သတိပေးချက်',
              'Settings → Battery → Battery optimization သို့သွားပါ။ "YBS AI" ကို ရှာပြီး "Don\'t optimize" (သို့မဟုတ် "Unrestricted") ဟု သတ်မှတ်ပါ။',
            ),
            _step(
              2,
              'Notification (အကြောင်းကြားချက်) ခွင့်ပြု',
              'Settings → Apps → YBS AI → Notifications သို့သွားပါ။ "Show notifications" ကို ဖွင့်ပါ။ "Admin Notifications" နှင့် "Arrival Alerts" channel များကို "Important" သို့မဟုတ် "Urgent" သတ်မှတ်ပါ။',
            ),
            _step(
              3,
              'Autostart / Auto-launch',
              'Settings → Apps → YBS AI (သို့မဟုတ် "Manage apps") → Autostart / Auto-launch ကို ဖွင့်ပါ (Xiaomi, Oppo, Vivo, Huawei စသည့် ဖုန်းများတွင် လိုအပ်ပါသည်)။',
            ),
            _step(
              4,
              'Background data (ဒေတာ) ခွင့်ပြု',
              'Settings → Apps → YBS AI → Mobile data သို့သွားပါ။ "Allow background data" ကို ဖွင့်ပါ သို့မဟုတ် "Data usage while Data saver is on" ကို ခွင့်ပြုပါ။',
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.amberLight,
                borderRadius: BorderRadius.circular(12),
              ),
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
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await NotifyService.instance.requestPermission();
                  await NotifyService.instance.speakTest();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'TTS စမ်းသပ်စာသားကို ဖွင့်ပြီးပါပြီ။ အသံမထွက်ပါက ဖုန်း TTS settings တွင် Myanmar/Burmese voice ကို ထည့်ပါ။',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.record_voice_over, size: 18),
                label: const Text('မြန်မာအသံ (TTS) စမ်းသပ်မည်'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.slate700,
                ),
                onPressed: () => launchUrl(
                  Uri.parse('app-settings:'),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.settings, size: 18),
                label: const Text('Setting ကို ဖွင့်မည်'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- Team & Conditions ----------------
class _TeamConditionsSection extends StatelessWidget {
  const _TeamConditionsSection();
  @override
  Widget build(BuildContext context) {
    return SettingsSectionPage(
      title: 'အဖွဲ့အစည်း နှင့် စည်းကမ်းချက်များ',
      child: Column(
        children: [
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardHeader(
                  Icons.groups,
                  AppColors.violet,
                  'အဖွဲ့အစည်း',
                  'YBS AI ကို ဖန်တီးသူများ',
                ),
                const SizedBox(height: 16),
                _kv('Founder & Developer', 'Arkar Yan'),
                _kv('Design', 'YBS AI Team'),
                _kv('Contact', 'info@arkaryan.net'),
                _link('Website', 'https://www.arkaryan.net/'),
                _link('TikTok', 'https://www.tiktok.com/@ybs.ai.mm'),
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 14),
                const Text(
                  'YBS AI Team သည် ရန်ကုန်မြို့တော် အများပြည်သူ၏ ကားလိုင်းသုံးစွဲအတွက် '
                  'လွယ်ကူပြီး အဆင်ပြေသော ဝန်ဆောင်မှုတစ်ခုကို ပံ့ပိုးပေးရန် ရည်မှန်းထားပါသည်။',
                  style: TextStyle(fontSize: 13, color: AppColors.slate600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardHeader(
                  Icons.description,
                  AppColors.violet,
                  'စည်းကမ်းချက်များ',
                  'ဝန်ဆောင်မှုကို အသုံးပြုရာတွင်',
                ),
                const SizedBox(height: 14),
                _condition(
                  '၁။ ဤ app သည် ရန်ကုန်မြို့တော် အများပြည်သူ ကားလိုင်း (YBS) အချက်အလက်များကို လွယ်ကူစွာ ရှာဖွေနိုင်ရန် ရည်ရွယ်ပါသည်။',
                ),
                _condition(
                  '၂။ လမ်းကြောင်း၊ အချိန်၊ ကားလိုင်းအချက်အလက်များသည် ခန့်မှန်းချက်သာ ဖြစ်ပြီး တကယ့်အခြေအနေနှင့် ကွဲလွဲနိုင်ပါသည်။',
                ),
                _condition(
                  '၃။ အသုံးပြုသူများသည် မိမိတာဝန်ခံချက်ဖြင့် အသုံးပြုရမည့် ဝန်ဆောင်မှုဖြစ်ပါသည်။',
                ),
                _condition(
                  '၄။ အချက်အလက်မှားယွင်းပါက အကြံပြုချက်ပေးပို့ရန် တိုက်တွန်းအပ်ပါသည်။',
                ),
                _condition(
                  '၅။ App မှ ရရှိနိုင်သော အချက်အလက်များကို ကိုယ်တိုက်မှတ်ထားပြီး အခြားဝန်ဆောင်မှုများနှင့် မျှဝေပါ။',
                ),
                _condition(
                  '၆။ သတိပေးချက် မှတ်တိုင်နှင့် အခြေအနေကို အသုံးပြုသူများအနေနဲ့ မိမိတာဝန်ခံချက် ဖြင့် အသုံးပြုပါ။',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _condition(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Icon(Icons.circle, size: 6, color: AppColors.slate400),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: AppColors.slate600),
          ),
        ),
      ],
    ),
  );
}

// ---------------- About Software ----------------
class _AboutSection extends StatelessWidget {
  const _AboutSection();
  @override
  Widget build(BuildContext context) {
    return SettingsSectionPage(
      title: 'ဆော့ဝဲအကြောင်း',
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardHeader(
              Icons.info_outline,
              AppColors.primary,
              'About Software',
              'YBS AI အကြောင်း',
            ),
            const SizedBox(height: 16),
            _kv('App Name', 'YBS AI'),
            _kv('Version', AppConfig.appVersion),
            _kv('Platform', 'Flutter (Android / iOS / Web)'),
            _kv('Developer', 'Arkar Yan'),
            _kv('Contact', 'info@arkaryan.net'),
            _link('Website', 'https://www.arkaryan.net/'),
            _link('Facebook', 'https://www.facebook.com/share/1d9kEym9Wq/'),
            _link('TikTok', 'https://www.tiktok.com/@ybs.ai.mm'),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 14),
            const Text(
              'YBS AI သည် ရန်ကုန်မြို့ရှိ အများပြည်သူ ကားလိုင်းများကို လမ်းကြောင်းရှာဖွေခြင်း၊ '
              'မြေပုံကြည့်ရှုခြင်း၊ အချိန်နှင့်အလိုက် ကားရောက်မည့်ခန့်မှန်းချက်နှင့် သတိပေးစနစ်များ ပါဝင်သော '
              'အခမဲ့ ဝန်ဆောင်မှု ဖြစ်ပါသည်။',
              style: TextStyle(fontSize: 13, color: AppColors.slate600),
            ),
            const SizedBox(height: 12),
            const Text(
              'ဤ app သည် လူမှုရေးရာ၊ ကျန်းမာရေး၊ ပညာရေး နှင့် အခြားအခင်းအကျင်းများအတွက် '
              'လမ်းကြောင်းရှာဖွေရန် အသုံးပြုနိုင်ပါသည်။ လမ်းကြောင်းများသည် မကြာခဏပြောင်းလဲပါသည်။ '
              'အချက်အလက်များသည် ခန့်မှန်းချက်သာဖြစ်ပါသည်။',
              style: TextStyle(fontSize: 13, color: AppColors.slate600),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- Privacy Policy ----------------
class _PrivacySection extends StatelessWidget {
  const _PrivacySection();
  @override
  Widget build(BuildContext context) {
    return SettingsSectionPage(
      title: 'ကိုယ်ရေးအချက်အလက် မူဝါဒ',
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardHeader(
              Icons.privacy_tip,
              AppColors.emerald,
              'ကိုယ်ရေးအချက်အလက် မူဝါဒ',
              'ဒေတာသိုလှောင်မှုနှင့် လုံခြုံရေး',
            ),
            const SizedBox(height: 14),
            _privacy(
              'ကားလိုင်းနှင့် မှတ်တိုင် အချက်အလက်များကို သင့်ဖုန်းအတွင်း (offline) သိုလှောင်ပါသည်။',
            ),
            _privacy(
              'သင်၏ တည်နေရာဒေတာကို မှတ်တိုင်အနီးရောက်သတိပေးချက်အတွက်သာ ယာယီအသုံးပြုပြီး ဆာဗာသို့ မပို့ပါ။',
            ),
            _privacy(
              'ကျွန်ုပ်တို့သည် သင့်ကိုယ်ရေးအချက်အလက်ကို တတိယအဖွဲ့အစည်းသို့ မရောင်းချပါ။',
            ),
            _privacy(
              'အချက်အလက်ဖျက်ရန် သို့မဟုတ် မေးမြန်းလိုပါက info@arkaryan.net သို့ ဆက်သွယ်နိုင်ပါသည်။',
            ),
            _privacy(
              'App သည် အချက်အလက် စုဆည်းခြင်းများ မပြုလုပ်ပါ။ လိုအပ်ပါက အချက်အလက် ရရှိနိုင်ခြေမရှိပါ။',
            ),
            _privacy(
              'အသုံးပြုသူ၏ မှတ်တိုင်နှင့် တည်နေရာအချက်အလက်များကို လုံခြုံစွာ ထိန်းသိမ်းထားပါသည်။',
            ),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 14),
            const Text(
              'ဤကိုယ်ရေးအချက်အလက် မူဝါဒသည် YBS AI app အတွက် အသုံးပြုသူများ၏ '
              'ကိုယ်ရေးအချက်အလက်များကို လုံခြုံစွာ ထိန်းသိမ်းရန် ရည်ရွယ်ထားပါသည်။',
              style: TextStyle(fontSize: 12, color: AppColors.slate500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _privacy(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Icon(Icons.lock, size: 14, color: AppColors.emerald),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: AppColors.slate600),
          ),
        ),
      ],
    ),
  );
}

// ---------------- What's New ----------------
class _WhatsNewSection extends StatelessWidget {
  const _WhatsNewSection();
  @override
  Widget build(BuildContext context) {
    return SettingsSectionPage(
      title: "What's New",
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardHeader(
              Icons.auto_awesome,
              const Color(0xFFF59E0B),
              "What's New in V3.3.2",
              'ဗားရှင်းသစ် အချက်အလက်များ',
            ),
            const SizedBox(height: 16),
            _feature(
              'AI-Powered Assistant',
              'လမ်းကြောင်းများကို မြန်မာလို မေးမြန်းနိုင်ခြင်း။',
            ),
            _feature(
              'Advanced Route Finding',
              'အမြန်ဆုံးနှင့် အဆင်ပြေဆုံး လမ်းကြောင်းများကို ရှာဖွေပေးခြင်း။',
            ),
            _feature(
              'Live Bus Location',
              'ကားများ၏ အချိန်နှင့်အလိုက် နေရာများကို မြေပုံတွင် ကြည့်ရှုနိုင်ခြင်း။',
            ),
            _feature(
              'Offline Maps',
              'Internet မရှိသည့်တိုင် လမ်းကြောင်းများနှင့် မှတ်တိုင်များကို အသုံးပြုနိုင်ခြင်း။',
            ),
            _feature(
              'Stop-to-Stop Navigation',
              'မှတ်တိုင်မှ မှတ်တိုင်သို့ အဆင့်ဆင့် လမ်းကြောင်းပြနိုင်ခြင်း။',
            ),
            _feature(
              'Smart Notifications',
              'App ပိတ်ထားသည့်တိုင် မှတ်တိုင်အနီးရောက်သတိပေးချက် ရောက်ရှိစေခြင်း။',
            ),
            _feature(
              'Bus Updates Feed',
              'လိုင်းအလိုက် ကားသွားလာချိန်နှင့် အခြေအနေများကို တင်ပြခြင်း။',
            ),
            _feature(
              'Cross-platform Web Fix',
              'Flutter web တွင် route data ကို ပုံမှန်ဖတ်ရှုနိုင်ပြီး blank screen မဖြစ်တော့ပါ။',
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- Feedback ----------------
class _FeedbackSection extends StatelessWidget {
  const _FeedbackSection();
  @override
  Widget build(BuildContext context) {
    return SettingsSectionPage(
      title: 'အကြံပြုချက်',
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardHeader(
              Icons.chat_bubble_outline,
              AppColors.brandLight,
              'အကြံပြုချက် / အမှားတွက်',
              'ကားလိုင်း သို့မဟုတ် App နှင့်ပတ်သက်သော အကြံပြုချက် ပို့ပါ။',
              iconColor: AppColors.brand,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
                onPressed: () => FeedbackDialog.show(context),
                child: const Text('အကြံပြုချက် ပို့မည်'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- Donation ----------------
class _DonationSection extends StatelessWidget {
  const _DonationSection();

  @override
  Widget build(BuildContext context) {
    return SettingsSectionPage(
      title: 'Support',
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.slate800],
          ),
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFFFBBF24),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Support This Project',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'YBS AI ကို ဆက်လက်ဖွံ့ဖြိုးရန် ကူညီနိုင်ပါသည်',
                        style: TextStyle(
                          color: AppColors.slate300,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _payRow(context, 'Kpay', '09446941632'),
            const SizedBox(height: 8),
            _payRow(context, 'Wave Money', '09758430371'),
          ],
        ),
      ),
    );
  }

  Widget _payRow(BuildContext context, String label, String number) {
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
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.slate400,
                    fontSize: 10,
                  ),
                ),
                Text(
                  number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: number));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('ကူးယူပြီးပါပြီ')));
            },
            icon: const Icon(Icons.copy, color: AppColors.slate400, size: 18),
          ),
        ],
      ),
    );
  }
}
