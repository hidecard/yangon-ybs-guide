import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:vibration/vibration.dart';

import '../config.dart';
import 'local_store.dart';

/// Vibration pattern used for the arrival alert (ms): vibrate, pause, repeat.
const _vibratePattern = [0, 400, 150, 400, 150, 400, 150, 400];

/// Native channel used to acquire/release a wake lock + turn the screen on
/// so the arrival alert (vibration + notification) is delivered even when the
/// device is asleep (screen off or app closed).
const _wakeLockChannel = MethodChannel('net.arkaryan.ybs_guide/wakelock');

Future<void> _releaseWakeLock() async {
  try {
    await _wakeLockChannel.invokeMethod('release');
  } catch (_) {}
}

/// Threshold (km) at which the background service fires the arrival alert.
const _arrivalThresholdKm = 0.2;

/// How often the background service polls the server for admin notifications
/// and for the current GPS position (used for arrival alerts). Kept modest so
/// it works without draining the battery noticeably.
const _pollInterval = Duration(seconds: 30);

double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return R * c;
}

Future<Map<String, dynamic>?> _fetchLatestNotification() async {
  try {
    final res = await http
        .get(Uri.parse('${AppConfig.apiBase}/api/notifications?limit=1'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode >= 400) return null;
    final data = json.decode(res.body);
    final list = data is Map ? (data['notifications'] as List?) : null;
    if (list == null || list.isEmpty) return null;
    return list.first as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Android foreground service notification (keeps the service alive even
  // when the app is closed / screen is off).
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((e) async {
      await service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((e) async {
      await service.setAsBackgroundService();
    });
    service.on('stopService').listen((e) async {
      await _releaseWakeLock();
      await service.stopSelf();
    });

    await service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: 'YBS AI သတိပေး အလုပ်လုပ်နေသည်',
      content: 'မှတ်တိုင်အနီးရောက်လျှင် နှင့် Admin သတင်းများ ရောက်လျှင် အလိုအလျောက် သတိပေးပါမည်',
    );
  }

  final plugin = FlutterLocalNotificationsPlugin();
  final tts = FlutterTts();
  try {
    // Explicitly use the launcher icon (the logo) as the default small icon.
    await plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ));
  } catch (_) {}
  try {
    await tts.setLanguage('my-MM');
    await tts.setSpeechRate(0.9);
  } catch (_) {}

  // Hold a partial wake lock (via the native channel) so the periodic timer
  // keeps firing and the vibration / notification are actually delivered
  // while the device is asleep (screen off or app closed).
  try {
    await _wakeLockChannel.invokeMethod('acquire');
  } catch (_) {}

  Future<void> vibrateStrong() async {
    try {
      if (await Vibration.hasVibrator()) {
        // Strong, repeating pattern so it's noticeable when not looking.
        Vibration.vibrate(pattern: _vibratePattern, repeat: -1);
        // Keep re-triggering for devices that ignore `repeat`, so the alert
        // doesn't stop after a single burst while the screen is off.
        for (int i = 0; i < 3; i++) {
          await Future.delayed(const Duration(milliseconds: 1400));
          if (await Vibration.hasVibrator()) {
            Vibration.vibrate(pattern: _vibratePattern);
          }
        }
        Vibration.cancel();
      }
    } catch (_) {}
  }

  Future<void> fireAlert(String stopName, String detail) async {
    // Wake the screen + turn it on (works even with screen off / app closed,
    // in addition to the fullScreenIntent notification below).
    try {
      await _wakeLockChannel.invokeMethod('wakeScreen');
    } catch (_) {}
    // Vibrate first (works even with screen off / app closed).
    vibrateStrong();
    try {
      await plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'YBS AI',
        '$stopName မှတ်တိုင်အနီးရောက်ပါပြီ${detail.isNotEmpty ? '\n$detail' : ''}',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'ybs_arrival',
            'Arrival Alerts',
            channelDescription: 'Notifies when approaching a bus stop',
            importance: Importance.max,
            priority: Priority.max,
            // Wake the device + show over lock screen when screen is off.
            fullScreenIntent: true,
            category: AndroidNotificationCategory.alarm,
            visibility: NotificationVisibility.public,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
      );
    } catch (_) {}
    try {
      await tts.speak('$stopName မှတ်တိုင်အနီးရောက်ပါပြီ');
    } catch (_) {}
  }

  Future<void> fireAdminNotification(Map<String, dynamic> notif) async {
    final id = (notif['id'] as num?)?.toInt() ?? 0;
    final message = notif['message']?.toString() ?? '';
    try {
      await plugin.show(
        id > 0 ? id : DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'YBS AI',
        message,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'ybs_admin',
            'Admin Notifications',
            channelDescription: 'Important announcements from YBS AI',
            importance: Importance.high,
            priority: Priority.high,
            visibility: NotificationVisibility.public,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
      );
    } catch (_) {}
  }

  // Poll loop runs for the whole lifetime of the service (both app-open and
  // app-closed). It checks (a) new admin notifications and (b) the active
  // arrival alert's GPS distance.
  Timer.periodic(_pollInterval, (timer) async {
    // ---- (a) Admin notifications ----
    try {
      final latest = await _fetchLatestNotification();
      if (latest != null) {
        final id = (latest['id'] as num?)?.toInt() ?? 0;
        final lastSeen = await LocalStore.instance.lastSeenNotification();
        if (id != lastSeen) {
          await LocalStore.instance.setLastSeenNotification(id);
          await fireAdminNotification(latest);
        }
      }
    } catch (_) {}

    // ---- (b) Arrival alert (only if a stop alert is active) ----
    final alert = await LocalStore.instance.getBackgroundAlert();
    if (alert == null) return; // No active stop alert -> keep polling admin only.

    // Already fired once -> keep monitoring but don't re-alert.
    if (alert['alerted'] == true) return;

    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      try {
        pos = await Geolocator.getLastKnownPosition();
      } catch (_) {}
    }
    if (pos == null) return;

    final d = _haversineKm(
      pos.latitude,
      pos.longitude,
      (alert['lat'] as num).toDouble(),
      (alert['lng'] as num).toDouble(),
    );

    if (d <= _arrivalThresholdKm) {
      await fireAlert(
        alert['stopName'] as String,
        (alert['detail'] as String?) ?? '',
      );
      await LocalStore.instance.setBackgroundAlertFired(true);
    }
  });
}

/// Initializes the background service (configuration only; does not start it).
Future<void> initBackgroundAlertService() async {
  final service = FlutterBackgroundService();

  const androidChannel = AndroidNotificationChannel(
    'ybs_bg',
    'Background Service',
    description: 'Keeps arrival alerts and admin notifications running in the background',
    importance: Importance.low,
  );

  final flutterLocalNotifications = FlutterLocalNotificationsPlugin();
  await flutterLocalNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(androidChannel);

  // Arrival alert channel: must be MAX importance so fullScreenIntent can wake
  // the device / show over the lock screen when the screen is off.
  await flutterLocalNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          'ybs_arrival',
          'Arrival Alerts',
          description: 'Notifies when approaching a bus stop',
          importance: Importance.max,
        ),
      );

  // Admin notification channel: HIGH importance so it shows even when the app
  // is closed / never opened since boot.
  await flutterLocalNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          'ybs_admin',
          'Admin Notifications',
          description: 'Important announcements from YBS AI',
          importance: Importance.high,
        ),
      );

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      autoStartOnBoot: true,
      isForegroundMode: true,
      notificationChannelId: 'ybs_bg',
      initialNotificationTitle: 'YBS AI',
      initialNotificationContent: 'သတိပေး ဝန်ဆောင်မှု အလုပ်လုပ်နေသည်',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  // iOS background execution; monitoring handled by the same onStart logic.
  onStart(service);
  return true;
}

/// Starts (or restarts) the background service with an active alert.
/// If the service is already running, we simply persist the alert and signal
/// the running instance to keep going — there is no need to restart it.
Future<void> startBackgroundAlert({
  required String stopName,
  required double lat,
  required double lng,
  String detail = '',
}) async {
  await LocalStore.instance.saveBackgroundAlert(
    stopName: stopName,
    lat: lat,
    lng: lng,
    detail: detail,
  );
  final service = FlutterBackgroundService();
  if (!await service.isRunning()) {
    await service.startService();
  }
}

/// Stops the background service and clears the persisted alert.
Future<void> stopBackgroundAlert() async {
  await LocalStore.instance.clearBackgroundAlert();
  // NOTE: We intentionally do NOT stop the whole service here, because it also
  // delivers admin notifications. The arrival-alert loop simply no-ops once
  // there is no active alert. To fully stop the service, use
  // `FlutterBackgroundService().invoke('stopService')`.
}
