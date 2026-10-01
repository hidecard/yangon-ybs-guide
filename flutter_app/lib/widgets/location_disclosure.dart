import 'package:flutter/material.dart';

/// Shows the in-app disclosure required before requesting location access.
///
/// This is intentionally shown immediately before the Android permission flow,
/// rather than relying on the privacy policy or Play listing.
Future<bool> showLocationDisclosure(
  BuildContext context, {
  required bool background,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Location data အသုံးပြုမှု'),
      content: SingleChildScrollView(
        child: Text(
          background
              ? 'YBS AI accesses and uses your precise device location while the app is in use, in the background, or the screen is off.\n\n'
                    'Why: Arrival Alert အတွက် သင်ရွေးချယ်ထားသော မှတ်တိုင်အနီးရောက်သောအခါ အသိပေးရန် ဖြစ်ပါသည်။\n\n'
                    'What: သင့်ဖုန်း၏ တိကျသော location data ကို အသုံးပြုပါသည်။\n\n'
                    'How: လက်ရှိတည်နေရာနှင့် ရွေးချယ်ထားသောမှတ်တိုင်အကြား အကွာအဝေးတွက်ချက်ပြီး alert ပြရန် ဖုန်းပေါ်တွင် အသုံးပြုပါသည်။ Location data ကို server သို့ မပို့ပါ၊ မရောင်းပါ၊ third party နှင့် မမျှဝေပါ။ Arrival Alert ကို ပိတ်လိုက်သည်နှင့် background location service ရပ်ပါမည်။'
              : 'YBS AI accesses and uses your precise device location while you use Near Me, maps, route search, or walking directions.\n\n'
                    'Why: အနီးဆုံးမှတ်တိုင်ရှာရန်၊ မြေပုံပေါ်တွင် သင့်တည်နေရာပြရန်နှင့် လမ်းကြောင်းတွက်ချက်ရန် ဖြစ်ပါသည်။\n\n'
                    'What: သင့်ဖုန်း၏ တိကျသော location data ကို အသုံးပြုပါသည်။\n\n'
                    'How: သင့်တည်နေရာကို ဖုန်းပေါ်တွင် လမ်းကြောင်းနှင့် အကွာအဝေးတွက်ချက်ရန် အသုံးပြုပါသည်။ Location data ကို server သို့ မပို့ပါ၊ မရောင်းပါ၊ third party နှင့် မမျှဝေပါ။',
          style: const TextStyle(height: 1.45),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Not now / မလုပ်သေးပါ'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Agree / သဘောတူသည်'),
        ),
      ],
    ),
  );
  return result ?? false;
}
