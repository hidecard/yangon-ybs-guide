import 'dart:io';
import 'dart:math';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceService {
  static const _key = 'ybs_device_id';
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_key);
    if (id != null && id.isNotEmpty) return id;

    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        id = info.id;
        if (id.isEmpty || _isKnownBadId(id)) {
          id = null;
        }
      } else if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        id = info.identifierForVendor;
      }
    } catch (_) {
      id = null;
    }

    if (id == null || id.isEmpty) {
      id = _generateFallbackId();
    }

    await prefs.setString(_key, id);
    return id;
  }

  bool _isKnownBadId(String id) {
    const knownBadIds = {'9774d56d682e549c', '0000000000000000'};
    return knownBadIds.contains(id);
  }

  String _generateFallbackId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
