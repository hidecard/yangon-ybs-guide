/// Shared obfuscation used to keep the bundled route data out of plain sight
/// inside the APK.
///
/// NOTE: anything shipped in an app can ultimately be reversed. This is
/// *obfuscation*, not real security — it stops someone from simply unzipping
/// the APK and reading the JSON. The key lives in the app binary, so a
/// determined attacker could recover it, but casual extraction is prevented.
library routes_crypto;

import 'dart:convert';
import 'dart:typed_data';

/// XOR key (not a password — just makes the blob non-trivially readable).
const String _key = 'YBSGuide-RouteData-ObFuScAtE-7f3a9c2e1b8d4a6f';

Uint8List xorBytes(Uint8List data) {
  final keyBytes = utf8.encode(_key);
  final out = Uint8List(data.length);
  for (int i = 0; i < data.length; i++) {
    out[i] = data[i] ^ keyBytes[i % keyBytes.length];
  }
  return out;
}
