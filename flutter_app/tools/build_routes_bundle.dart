/// Build-time tool: packs all bundled route JSON files into a single
/// gzip + XOR encrypted binary blob (`assets/routes.bin`) so the plain
/// JSON is never shipped inside the APK.
///
/// Run with:  dart run tools/build_routes_bundle.dart
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ybs_guide/data/routes_crypto.dart' show xorBytes;

final root = Directory.current;
final srcDir = Directory('${root.path}/tools/routes_src');
final manifestFile = File('${root.path}/tools/routes_src/routes_manifest.json');
final outFile = File('${root.path}/assets/routes.bin');

Future<void> main() async {
  if (!await srcDir.exists()) {
    stderr.writeln('tools/routes_src not found. Run from flutter_app root.');
    exit(1);
  }

  final files = srcDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('_data.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  // Preserve the manifest order if present, else alphabetical.
  List<String> order = files.map((f) => f.uri.pathSegments.last).toList();
  if (await manifestFile.exists()) {
    final manifest = (json.decode(await manifestFile.readAsString())
        as List).map((e) => e as String).toList();
    order = manifest
        .where((name) => files.any((f) => f.path.endsWith(name)))
        .toList();
  }

  final entries = <Map<String, String>>[];
  for (final name in order) {
    final file = files.firstWhere((f) => f.path.endsWith(name));
    entries.add({
      'name': name,
      'json': await file.readAsString(),
    });
  }

  // Pack -> JSON -> gzip -> XOR -> base64.
  final packed = utf8.encode(json.encode(entries));
  final gzipped = gzip.encode(packed) as Uint8List;
  final encrypted = xorBytes(gzipped);
  final b64 = base64.encode(encrypted);

  await outFile.writeAsString(b64);
  stdout.writeln(
      'Wrote ${outFile.path} (${(await outFile.readAsBytes()).length} bytes, '
      '${entries.length} route files).');
}
