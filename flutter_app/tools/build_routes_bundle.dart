/// Build-time tool: packs all bundled route JSON files into a single
/// gzip + XOR encrypted binary blob (`assets/routes.bin`) so the plain
/// JSON is never shipped inside the APK. It also emits a small
/// `routes_manifest.json` (with per-file version + hashes) so the backend
/// can serve delta updates via `/api/routes/delta?since=<version>`.
///
/// Run with:  dart run tools/build_routes_bundle.dart
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:ybs_guide/data/routes_crypto.dart' show xorBytes;

final root = Directory.current;
final srcDir = Directory('${root.path}/tools/routes_src');
final manifestFile = File('${root.path}/tools/routes_src/routes_manifest.json');
final outFile = File('${root.path}/assets/routes.bin');
final routesManifestOut = File('${root.path}/../public/routes_manifest.json');

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

  // ---- Build routes.bin ----
  final entries = <Map<String, String>>[];
  for (final name in order) {
    final file = files.firstWhere((f) => f.path.endsWith(name));
    entries.add({
      'name': name,
      'json': await file.readAsString(),
    });
  }

  final packed = utf8.encode(json.encode(entries));
  final gzipped = gzip.encode(packed) as Uint8List;
  final encrypted = xorBytes(gzipped);
  final b64 = base64.encode(encrypted);

  await outFile.writeAsString(b64);
  stdout.writeln(
      'Wrote ${outFile.path} (${(await outFile.readAsBytes()).length} bytes, '
      '${entries.length} route files).');

  // ---- Build routes_manifest.json ----
  await _writeManifest(files, order);
}

Future<void> _writeManifest(List<File> files, List<String> order) async {
  final oldManifest =
      await routesManifestOut.exists()
          ? json.decode(await routesManifestOut.readAsString()) as Map<String, dynamic>?
          : null;
  final oldGlobalVersion = (oldManifest?['global_version'] as num?)?.toInt() ?? 0;
  final oldFiles = oldManifest?['files'] as Map<String, dynamic>? ?? {};

  final fileMap = <String, File>{for (final f in files) f.uri.pathSegments.last: f};

  final newFiles = <String, dynamic>{};
  int globalVersion = oldGlobalVersion;

  for (final name in order) {
    final file = fileMap[name]!;
    final bytes = await file.readAsBytes();
    final hash = sha256.convert(bytes).toString();
    final oldEntry = oldFiles[name] as Map<String, dynamic>?;

    if (oldEntry == null || (oldEntry['hash'] as String?) != hash) {
      globalVersion++;
      final raw = json.decode(utf8.decode(bytes)) as Map<String, dynamic>;
      final routeIdRaw = raw['bus_line']?.toString() ??
          name.replaceFirst('ybs_', '').replaceFirst('_data.json', '');
      String routeId = routeIdRaw.trim();
      final routeInfo = (raw['route_info'] as Map<String, dynamic>?) ?? const {};
      final operator = (routeInfo['Agency']?.toString().isNotEmpty ?? false)
          ? routeInfo['Agency'].toString()
          : '';
      final lineName = routeInfo['Line Name']?.toString();
      final qrPayment = routeInfo['QR Payment']?.toString();

      var c = 0;
      for (int i = 0; i < routeId.length; i++) {
        c = routeId.codeUnitAt(i) + ((c << 5) - c);
        c = c & 0xFFFFFFFF;
      }
      final color = 0xFF000000 | (c & 0x00FFFFFF);

      final stopNames = <String>[];
      final detailedStops = <dynamic>[];
      final rawStops = raw['stops'];
      if (rawStops is List) {
        for (int i = 0; i < rawStops.length; i++) {
          final stop = rawStops[i] as Map<String, dynamic>;
          final nameMm = stop['stop_name_mm']?.toString();
          final nameEn = stop['stop_name_en']?.toString();
          final lat = stop['latitude'];
          final lng = stop['longitude'];
          if (nameMm != null && nameMm.isNotEmpty) {
            stopNames.add(nameMm);
          }
          if (nameMm != null && nameEn != null && lat != null && lng != null) {
            final roadStr = stop['road']?.toString() ?? '';
            final roadParts = roadStr.isEmpty ? ['', ''] : roadStr.split(',');
            final road = roadParts.isNotEmpty ? roadParts[0].trim() : '';
            final township = roadParts.length > 1
                ? roadParts[1].trim()
                : (roadParts.isNotEmpty ? roadParts[0].trim() : '');
            detailedStops.add({
              'id': i + 1,
              'lat': (lat as num).toDouble(),
              'lng': (lng as num).toDouble(),
              'name_en': nameEn,
              'name_mm': nameMm,
              'road_en': road,
              'road_mm': road,
              'township_en': township,
              'township_mm': township,
            });
          }
        }
      }

      newFiles[name] = {
        'hash': hash,
        'version': globalVersion,
        'route_id': routeId,
        'data': {
          'id': routeId,
          'color': color,
          'operator': operator,
          'line_name': lineName,
          'qr_payment': qrPayment,
          'stops': stopNames,
          'stops_detailed': detailedStops,
        },
      };
    } else {
      newFiles[name] = {
        'hash': oldEntry['hash'] as String,
        'version': oldEntry['version'] as int,
        'route_id': oldEntry['route_id'] as String,
        'data': oldEntry['data'],
      };
    }
  }

  final manifest = {
    'global_version': globalVersion,
    'generated_at': DateTime.now().millisecondsSinceEpoch,
    'total_routes': order.length,
    'files': newFiles,
  };

  await routesManifestOut.writeAsString(json.encode(manifest));
  stdout.writeln(
      'Wrote ${routesManifestOut.path} (version $globalVersion, ${(await routesManifestOut.readAsBytes()).length} bytes).');
}
