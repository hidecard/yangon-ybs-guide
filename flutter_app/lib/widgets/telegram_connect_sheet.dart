import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../services/api_service.dart';
import '../services/local_store.dart';

/// Telegram connect bottom sheet (link account, show/cancel alert).
class TelegramConnectSheet extends StatefulWidget {
  const TelegramConnectSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TelegramConnectSheet(),
    );
  }

  @override
  State<TelegramConnectSheet> createState() => _TelegramConnectSheetState();
}

class _TelegramConnectSheetState extends State<TelegramConnectSheet> {
  AlertStatus? _status;
  String _userId = '';
  bool _busy = false;
  String _msg = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _userId = await LocalStore.instance.getUserId();
    final s = await ApiService.instance.getAlertStatus(_userId);
    if (mounted) setState(() => _status = s);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.smart_toy, color: AppColors.blue),
                  const SizedBox(width: 8),
                  const Text('Telegram ချိတ်ဆက်',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'မှတ်တိုင် နီးကပ်လျှင် သတိပေးခံရန် သင့် Telegram ကို ချိတ်ဆက်ပါ။',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              if (_status?.stopName != null)
                _alertActiveBox()
              else if (_status?.linked == true)
                _linkedBox()
              else
                _connectBox(),
              if (_msg.isNotEmpty) ...[
                const SizedBox(height: 10),
                Center(
                    child: Text(_msg,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary))),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _alertActiveBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.emeraldLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🔔 ${_status!.stopName} မှတ်တိုင်သို့ ရောက်လျှင် သတိပေးပါမည်။',
              style:
                  const TextStyle(fontSize: 14, color: AppColors.emeraldDark)),
          const SizedBox(height: 6),
          const Text('Bot သို့ Live Location ပို့ပေးပါ။',
              style: TextStyle(fontSize: 12, color: AppColors.emeraldDark)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      await ApiService.instance.cancelAlert(_userId);
                      setState(() {
                        _status = AlertStatus(linked: _status!.linked);
                        _msg = '🚫 သတိပေးချက် ပယ်ဖျက်ပြီးပါပြီ။';
                        _busy = false;
                      });
                    },
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.rose),
              child: const Text('သတိပေးချက် ပယ်ဖျက်မည်'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _linkedBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.emeraldLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: const Text(
        '✅ ချိတ်ဆက်ပြီးပါပြီ။ မှတ်တိုင်တစ်ခုချက် ဖွင့်ပြီး "သတိပေးပါ" ကို နှိပ်ပါ။',
        style: TextStyle(fontSize: 14, color: AppColors.emeraldDark),
      ),
    );
  }

  Widget _connectBox() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF26A5E4),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () => launchUrl(
                Uri.parse(LocalStore.instance.connectUrl(_userId)),
                mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.send),
            label: const Text('Telegram နဲ့ ချိတ်ဆက်မည်'),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bot ကို အရင် ဖွင့်ထားပြီးသားဆိုရင် /start ကုဒ်ကို ပို့ပါ:',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.slate100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  '/start $_userId',
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
