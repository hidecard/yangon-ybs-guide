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
const _wakeLockChannel = MethodChannel('net.arkaryan.ybs_guide/wakelock');

Future<void> _releaseWakeLock() async {
  try {
    await _wakeLockChannel.invokeMethod('release');
  } catch (_) {}
}

/// Threshold (km) at which the background service fires the arrival alert.
const _arrivalThresholdKm = 0.2;

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

/// Polling intervals (ms) configuration
const _idlePollIntervalMs = 60000;
const _farPollIntervalMs = 60000;
const _approachingPollIntervalMs = 30000;
const _closePollIntervalMs = 10000;

/// Speed-based backoff interval (ms) when the vehicle is stationary or stuck in traffic (< 2 m/s)
const _trafficJamBackoffIntervalMs = 30000;

const _approachingThresholdKm = 2.0;
const _closeThresholdKm = 0.5;

/// Computes the dynamic polling interval by considering both Proximity and Speed.
Future<int> _computePollInterval() async {
  final alert = await LocalStore.instance.getBackgroundAlert();
  if (alert == null || alert['alerted'] == true) return _idlePollIntervalMs;

  Position? pos;
  try {
    pos = await Geolocator.getLastKnownPosition();
  } catch (_) {}

  if (pos == null) return _farPollIntervalMs;

  final d = _haversineKm(
    pos.latitude,
    pos.longitude,
    (alert['lat'] as num).toDouble(),
    (alert['lng'] as num).toDouble(),
  );

  if (d > _approachingThresholdKm) return _farPollIntervalMs;

  try {
    pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 3),
      ),
    );
  } catch (_) {}

  if (pos != null && pos.speed < 2.0 && d <= _closeThresholdKm) {
    return _trafficJamBackoffIntervalMs;
  }

  if (d > _closeThresholdKm) return _approachingPollIntervalMs;
  return _closePollIntervalMs;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
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
      title: 'YBS Guide သတိပေးချက် မောင်းနှင်နေသည်',
      content: 'မှတ်တိုင်အနီးရောက်လျှင် အလိုအလျောက် အသံဖြင့် သတိပေးပါမည်။',
    );
  }

  final plugin = FlutterLocalNotificationsPlugin();
  final tts = FlutterTts();

  try {
    await plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ));
  } catch (_) {}

  try {
    await tts.setLanguage('my-MM');
    await tts.setSpeechRate(0.85);
  } catch (_) {}

  try {
    await _wakeLockChannel.invokeMethod('acquire');
  } catch (_) {}

  Future<void> vibrateStrong() async {
    try {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(pattern: _vibratePattern, repeat: -1);
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
    try {
      await _wakeLockChannel.invokeMethod('wakeScreen');
    } catch (_) {}

    vibrateStrong();

    try {
      await plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'YBS Guide ရောက်ရှိခြင်း သတိပေးချက်',
        '$stopName မှတ်တိုင်သို့ ရောက်ရှိရန် မီတာ ၂၀၀ သာ လိုပါတော့သည်။${detail.isNotEmpty ? '\n$detail' : ''}',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'ybs_arrival',
            'Arrival Alerts',
            channelDescription: 'Notifies when approaching a bus stop',
            importance: Importance.max,
            priority: Priority.max,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.alarm,
            visibility: NotificationVisibility.public,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
      );
    } catch (_) {}

    try {
      await tts.speak('$stopName မှတ်တိုင် အနီးသို့ ရောက်ရှိပါတော့မည်။ ဆင်းရန် ပြင်ဆင်ပါ။');
    } catch (_) {}
  }

  Future<void> fireAdminNotification(Map<String, dynamic> notif) async {
    final id = (notif['id'] as num?)?.toInt() ?? 0;
    final message = notif['message']?.toString() ?? '';
    try {
      await plugin.show(
        id > 0 ? id : DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'YBS သတင်းဦးရရှိသည်',
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

  Timer? dynTimer;

  void schedulePoll() async {
    dynTimer?.cancel();
    final pollInterval = await _computePollInterval();

    dynTimer = Timer(Duration(milliseconds: pollInterval), () async {
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

      final alert = await LocalStore.instance.getBackgroundAlert();
      if (alert == null || alert['alerted'] == true) {
        schedulePoll();
        return;
      }

      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        try {
          pos = await Geolocator.getLastKnownPosition();
        } catch (_) {}
      }

      if (pos == null) {
        schedulePoll();
        return;
      }

      final d = _haversineKm(
        pos.latitude,
        pos.longitude,
        (alert['lat'] as num).toDouble(),
        (alert['lng'] as num).toDouble(),
      );

      if (service is AndroidServiceInstance && await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: 'YBS Guide သတိပေးချက် မောင်းနှင်နေသည်',
          content: 'ပန်းတိုင်မှတ်တိုင်သို့ ရောက်ရန် အကွာအဝေး - ${d.toStringAsFixed(2)} ကီလိုမီတာ',
        );
      }

      if (d <= _arrivalThresholdKm) {
        await fireAlert(
          alert['stopName'] as String,
          (alert['detail'] as String?) ?? '',
        );
        await LocalStore.instance.setBackgroundAlertFired(true);
      }

      schedulePoll();
    });
  }

  schedulePoll();
}

Future<void> initBackgroundAlertService() async {
  final service = FlutterBackgroundService();
  final flutterLocalNotifications = FlutterLocalNotificationsPlugin();

  await flutterLocalNotifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          'ybs_bg',
          'Background Service',
          description: 'Keeps arrival alerts and admin notifications running in the background',
          importance: Importance.high,
        ),
      );

  await flutterLocalNotifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          'ybs_arrival',
          'Arrival Alerts',
          description: 'Notifies when approaching a bus stop',
          importance: Importance.max,
        ),
      );

  await flutterLocalNotifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
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
      initialNotificationTitle: 'YBS Guide',
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
  onStart(service);
  return true;
}

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

Future<void> stopBackgroundAlert() async {
  await LocalStore.instance.clearBackgroundAlert();
}
