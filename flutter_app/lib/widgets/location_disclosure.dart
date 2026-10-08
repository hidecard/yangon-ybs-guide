import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _locationDisclosureAcceptedKey = 'location_disclosure_v3_accepted';

/// Shows the in-app prominent disclosure immediately before location permission.
Future<bool> showLocationDisclosure(
  BuildContext context, {
  required bool background,
}) async {
  var accepted = false;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Location data use'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                background
                    ? 'YBS AI collects and uses your precise device location while the app is in use, in the background, or when the screen is off.\n\n'
                          'Why: to calculate your distance from the selected bus stop and send an Arrival Alert when you are nearby.\n\n'
                          'How: location is processed on your device for distance and alert calculations. Background location is used only while you have explicitly enabled Arrival Alert and stops when the alert is cleared or completed.\n\n'
                          'Sharing: GPS coordinates are not sent to our API, sold, or shared with third parties.\n\n'
                          'မြန်မာ: Arrival Alert ဖွင့်ထားချိန်တွင် app နောက်ကွယ်နှင့် screen ပိတ်ထားချိန်၌ မှတ်တိုင်နီးကပ်မှုတွက်ချက်ရန် location ကို အသုံးပြုပါသည်။ GPS ကို server သို့ မပို့ပါ၊ မရောင်းပါ၊ third party နှင့် မမျှဝေပါ။'
                    : 'YBS AI collects and uses your precise device location when you choose Near Me, map picking, live tracking, route search, or walking directions.\n\n'
                          'Why: to find nearby bus stops, show your position on a map, calculate route distance, and provide walking directions.\n\n'
                          'How: location is processed on your device for nearby-stop, map, route, and distance calculations.\n\n'
                          'Sharing: GPS coordinates are not sent to our API, sold, or shared with third parties.\n\n'
                          'မြန်မာ: အနီးဆုံးမှတ်တိုင်ရှာရန်၊ မြေပုံပေါ်တွင် တည်နေရာပြရန်နှင့် အကွာအဝေးတွက်ရန် location ကို အသုံးပြုပါသည်။ GPS ကို server သို့ မပို့ပါ။',
                style: const TextStyle(height: 1.45),
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: accepted,
                onChanged: (value) => setState(() => accepted = value ?? false),
                title: const Text(
                  'I understand and agree to this location data use.\nတည်နေရာဒေတာ အသုံးပြုမှုကို နားလည်ပြီး သဘောတူပါသည်။',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not now / မလုပ်သေးပါ'),
          ),
          FilledButton(
            onPressed: accepted
                ? () => Navigator.of(dialogContext).pop(true)
                : null,
            child: const Text('Continue / ဆက်လုပ်မည်'),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

/// Shows the disclosure on a fresh install/update before the main app screen.
class LocationDisclosureGate extends StatefulWidget {
  final Widget child;
  const LocationDisclosureGate({super.key, required this.child});

  @override
  State<LocationDisclosureGate> createState() => _LocationDisclosureGateState();
}

class _LocationDisclosureGateState extends State<LocationDisclosureGate> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showIfNeeded());
  }

  Future<void> _showIfNeeded() async {
    if (!mounted || _checked) return;
    _checked = true;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    if (prefs.getBool(_locationDisclosureAcceptedKey) == true) return;
    final accepted = await showLocationDisclosure(context, background: true);
    if (accepted) {
      await prefs.setBool(_locationDisclosureAcceptedKey, true);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
