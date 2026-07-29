import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceService {
  DeviceService._();
  static final DeviceService instance = DeviceService._();

  static const _key = 'ybs_device_id';

  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_key);
    if (id != null && id.isNotEmpty) return id;

    id = _generateId();
    await prefs.setString(_key, id);
    return id;
  }

  String _generateId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}