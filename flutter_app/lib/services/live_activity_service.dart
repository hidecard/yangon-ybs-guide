import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:live_activities/live_activities.dart';

class LiveActivityService {
  LiveActivityService._();
  static final LiveActivityService instance = LiveActivityService._();

  static const _appGroupId = 'group.net.arkaryan.ybs_guide';

  final _plugin = LiveActivities();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  String? _activityId;
  static int _fallbackId = 9000;

  bool get isActive => _activityId != null;

  Future<void> init() async {
    try {
      await _plugin.init(appGroupId: _appGroupId);
    } catch (e) {
      debugPrint('LiveActivity init failed: $e');
    }
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: android);
      await _notifications.initialize(settings);
    } catch (_) {}
  }

  Future<void> startTracking({
    required String routeName,
    required String stopName,
    required double distanceKm,
    required int etaMinutes,
  }) async {
    await stopTracking();

    try {
      final supported = await _plugin.areActivitiesSupported();
      if (supported) {
        final enabled = await _plugin.areActivitiesEnabled();
        if (enabled) {
          final id = 'ybs_tracking_${DateTime.now().millisecondsSinceEpoch}';
          final payload = <String, dynamic>{
            'routeName': routeName,
            'stopName': stopName,
            'distanceKm': distanceKm,
            'etaMinutes': etaMinutes,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          };
          final result = await _plugin.createActivity(id, payload);
          _activityId = result ?? id;
          debugPrint('LiveActivity started: $_activityId');
          return;
        }
      }
    } catch (e) {
      debugPrint('LiveActivity start failed, fallback to notification: $e');
    }

    await _showFallbackNotification(routeName, stopName, distanceKm, etaMinutes);
  }

  Future<void> updateTracking({
    required String stopName,
    required double distanceKm,
    required int etaMinutes,
  }) async {
    if (_activityId != null) {
      final payload = <String, dynamic>{
        'stopName': stopName,
        'distanceKm': distanceKm,
        'etaMinutes': etaMinutes,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };
      try {
        await _plugin.updateActivity(_activityId!, payload);
        return;
      } catch (e) {
        debugPrint('LiveActivity update failed: $e');
        await stopTracking();
      }
    }
    await _showFallbackNotification(
      'Route Plan',
      stopName,
      distanceKm,
      etaMinutes,
    );
  }

  Future<void> stopTracking() async {
    if (_activityId != null) {
      try {
        await _plugin.endActivity(_activityId!);
      } catch (_) {}
      _activityId = null;
    }
    await _notifications.cancel(_fallbackId);
  }

  Future<void> _showFallbackNotification(
    String routeName,
    String stopName,
    double distanceKm,
    int etaMinutes,
  ) async {
    final buffer = StringBuffer();
    buffer.write(routeName);
    buffer.write(' • ');
    buffer.write(stopName);
    buffer.write(' • ');
    buffer.write(distanceKm.toStringAsFixed(1));
    buffer.write(' km');
    if (etaMinutes > 0) {
      buffer.write(' • ~');
      buffer.write(etaMinutes);
      buffer.write(' min');
    }

    final android = AndroidNotificationDetails(
      'ybs_live_activity',
      'Live Tracking',
      channelDescription: 'Live bus tracking updates',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      styleInformation: const BigTextStyleInformation(''),
    );
    final platform = NotificationDetails(android: android);
    await _notifications.show(
      _fallbackId,
      routeName,
      stopName,
      platform,
      payload: 'live-activity',
    );
  }
}
