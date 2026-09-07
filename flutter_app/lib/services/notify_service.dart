import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import 'api_service.dart';

/// Local arrival alert: vibration + system notification + Burmese TTS.
/// Mirrors triggerArrivalNotify() in the web app.
class NotifyService {
  NotifyService._();
  static final NotifyService instance = NotifyService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final FlutterTts _tts = FlutterTts();
  bool _inited = false;

  Future<void> init() async {
    if (_inited) return;
    _inited = true;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    // On Android 8+ a notification only shows if its channel exists. Create
    // the channels up-front (with the logo icon) so arrival + admin alerts
    // are never silently dropped.
    try {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      const arrival = AndroidNotificationChannel(
        'ybs_arrival',
        'Arrival Alerts',
        description: 'Notifies when approaching a bus stop',
        importance: Importance.high,
      );
      const admin = AndroidNotificationChannel(
        'ybs_admin',
        'Admin Notifications',
        description: 'Important announcements from YBS AI',
        importance: Importance.high,
      );
      await androidPlugin?.createNotificationChannel(arrival);
      await androidPlugin?.createNotificationChannel(admin);
    } catch (_) {}
    try {
      await _tts.setLanguage('my-MM');
      await _tts.setSpeechRate(0.9);
    } catch (_) {}
  }

  Future<void> requestPermission() async {
    await init();
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (_) {}
  }

  Future<void> speak(String text) async {
    await init();
    try {
      await _tts.stop();
      await _tts.setLanguage('my-MM');
      await _tts.setSpeechRate(0.9);
      await _tts.setVolume(1.0);
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> speakTest() async {
    await speak(
      'မြန်မာဘာသာ အသံစမ်းသပ်မှု ဖြစ်ပါတယ်။ နောက်မှတ်တိုင် ရောက်ခါနီးပါပြီ။',
    );
  }

  Future<void> triggerArrival(String message, {bool speak = false}) async {
    await init();
    try {
      final hasVib = await Vibration.hasVibrator();
      if (hasVib) {
        Vibration.vibrate(pattern: [0, 200, 120, 200]);
      }
    } catch (_) {}
    try {
      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'YBS AI',
        message,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'ybs_arrival',
            'Arrival Alerts',
            channelDescription: 'Notifies when approaching a bus stop',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (_) {}
    if (speak) await this.speak(message);
  }

  Future<void> showAdminNotification(NotificationItem notif) async {
    await init();
    try {
      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'YBS AI',
        notif.message,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'ybs_admin',
            'Admin Notifications',
            channelDescription: 'Important announcements from YBS AI',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (_) {}
  }
}
