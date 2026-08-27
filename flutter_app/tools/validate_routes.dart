import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final srcDir = Directory('${Directory.current.path}/tools/routes_src');
  if (!await srcDir.exists()) {
    stderr.writeln('tools/routes_src not found. Run from flutter_app root.');
    exitCode = 1;
    return;
  }

  final files =
      srcDir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('_data.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  if (files.isEmpty) {
    stderr.writeln('No route source files found.');
    exitCode = 1;
    return;
  }

  final errors = <String>[];
  final warnings = <String>[];
  var totalStops = 0;
  final routeIds = <String, String>{};

  for (final file in files) {
    final name = file.uri.pathSegments.last;
    dynamic decoded;
    try {
      decoded = json.decode(await file.readAsString());
    } catch (error) {
      errors.add('$name: invalid JSON ($error)');
      continue;
    }
    if (decoded is! Map) {
      errors.add('$name: root value must be an object');
      continue;
    }

    final data = Map<String, dynamic>.from(decoded);
    final routeId = data['bus_line']?.toString().trim() ?? '';
    if (routeId.isEmpty) {
      errors.add('$name: missing bus_line');
    } else if (routeIds.containsKey(routeId)) {
      warnings.add(
        '$name: duplicate bus_line $routeId (also in ${routeIds[routeId]})',
      );
    } else {
      routeIds[routeId] = name;
    }

    final rawStops = data['stops'];
    if (rawStops is! List || rawStops.isEmpty) {
      errors.add('$name: stops must be a non-empty list');
      continue;
    }

    final names = <String>{};
    var validStops = 0;
    for (var index = 0; index < rawStops.length; index++) {
      final rawStop = rawStops[index];
      if (rawStop is! Map) {
        errors.add('$name: stop ${index + 1} must be an object');
        continue;
      }
      final stop = Map<String, dynamic>.from(rawStop);
      final nameMm = stop['stop_name_mm']?.toString().trim() ?? '';
      final nameEn = stop['stop_name_en']?.toString().trim() ?? '';
      final lat = stop['latitude'];
      final lng = stop['longitude'];
      if (nameMm.isEmpty || nameEn.isEmpty) {
        errors.add('$name: stop ${index + 1} is missing Burmese/English name');
        continue;
      }
      if (lat is! num || lng is! num || !lat.isFinite || !lng.isFinite) {
        errors.add('$name: stop ${index + 1} has invalid coordinates');
        continue;
      }
      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
        errors.add('$name: stop ${index + 1} coordinates are out of range');
        continue;
      }
      if (!names.add('$nameMm|$lat|$lng')) {
        warnings.add('$name: duplicate stop ${index + 1} ($nameMm)');
      }
      validStops++;
    }
    if (validStops < 2) {
      errors.add('$name: fewer than two valid stops');
    }
    totalStops += validStops;
  }

  stdout.writeln(
    'Validated ${files.length} route files, ${routeIds.length} route IDs, '
    '$totalStops valid stops.',
  );
  for (final warning in warnings) {
    stdout.writeln('WARN: $warning');
  }
  if (errors.isNotEmpty) {
    for (final error in errors) {
      stderr.writeln('ERROR: $error');
    }
    stderr.writeln('Validation failed with ${errors.length} error(s).');
    exitCode = 1;
    return;
  }
  stdout.writeln('Route data quality validation passed.');
}
