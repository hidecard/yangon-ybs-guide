import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pointycastle/export.dart';

class TrainLivePosition {
  final String routeSlug;
  final String routeTitle;
  final String direction;
  final String trainModel;
  final double latitude;
  final double longitude;

  const TrainLivePosition({
    required this.routeSlug,
    required this.routeTitle,
    required this.direction,
    required this.trainModel,
    required this.latitude,
    required this.longitude,
  });

  factory TrainLivePosition.fromJson(Map<String, dynamic> json) {
    final latitude = _number(json['latitude'], max: 90);
    final longitude = _number(json['longitude'], max: 180);
    if (latitude == null || longitude == null) {
      throw const FormatException(
        'Live train position has invalid coordinates',
      );
    }
    return TrainLivePosition(
      routeSlug: _decode(json['route_slug'] ?? json['slug']),
      routeTitle: _decode(json['route_title'] ?? json['title']),
      direction: _mapText(json['way']),
      trainModel: _mapText(json['train_model']),
      latitude: latitude,
      longitude: longitude,
    );
  }

  static double? _number(dynamic value, {required double max}) {
    final parsed = double.tryParse(_decode(value));
    if (parsed == null || !parsed.isFinite) return null;
    if (parsed < -max || parsed > max) return null;
    return parsed;
  }

  static String _mapText(dynamic value) {
    if (value is Map) {
      return _decode(value['text'] ?? value['value']);
    }
    return _decode(value);
  }

  static String _decode(dynamic value) => decodePublicField(value);
}

class TrainLiveSnapshot {
  final DateTime fetchedAt;
  final List<TrainLivePosition> positions;

  const TrainLiveSnapshot({required this.fetchedAt, required this.positions});
}

class TrainLiveService {
  TrainLiveService._();
  static final instance = TrainLiveService._();

  static const _apiBase = 'https://yrsmm.com/api';
  // This key is intentionally the same public client key shipped by the
  // source website. It is not a private credential; the service exposes it in
  // its browser bundle for its own public client requests.
  static const _publicClientKey = 'uGr9F6DXaOZhq0shIErdGMTfgGyCB3eO';

  Future<TrainLiveSnapshot> fetch({String? routeSlug}) async {
    final client = http.Client();
    try {
      final signedResponse = await client
          .post(
            Uri.parse('$_apiBase/realtime-train-location-signed-url'),
            headers: _headers('application/json'),
            body: jsonEncode({'route_slug': routeSlug}),
          )
          .timeout(const Duration(seconds: 15));
      if (signedResponse.statusCode < 200 || signedResponse.statusCode >= 300) {
        throw StateError(
          'Live location request failed (${signedResponse.statusCode})',
        );
      }
      final payload = jsonDecode(signedResponse.body);
      final url = payload is Map ? payload['data']?.toString() : null;
      if (url == null || url.isEmpty) {
        throw StateError('No live stream URL');
      }

      final request = http.Request('GET', Uri.parse(url));
      request.headers.addAll(_headers('text/event-stream'));
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Live stream failed (${response.statusCode})');
      }
      final result = await _readFirstDataEvent(response);
      return TrainLiveSnapshot(fetchedAt: DateTime.now(), positions: result);
    } finally {
      client.close();
    }
  }

  Future<List<TrainLivePosition>> _readFirstDataEvent(
    http.StreamedResponse response,
  ) {
    final completer = Completer<List<TrainLivePosition>>();
    late StreamSubscription<String> subscription;
    final timeout = Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) completer.complete(const []);
      subscription.cancel();
    });

    subscription = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            if (!line.startsWith('data:')) return;
            final raw = line.substring(5).trim();
            if (raw.isEmpty) return;
            try {
              final decoded = jsonDecode(raw);
              final rows = decoded is List
                  ? decoded
                  : decoded is Map && decoded['data'] is List
                  ? decoded['data'] as List
                  : const [];
              final positions = <TrainLivePosition>[];
              for (final row in rows) {
                if (row is! Map) continue;
                try {
                  positions.add(
                    TrainLivePosition.fromJson(Map<String, dynamic>.from(row)),
                  );
                } catch (_) {}
              }
              if (!completer.isCompleted) completer.complete(positions);
              timeout.cancel();
              subscription.cancel();
            } catch (_) {
              // Ignore malformed keep-alive events and continue until timeout.
            }
          },
          onError: (Object error, StackTrace stack) {
            if (!completer.isCompleted) completer.completeError(error, stack);
            timeout.cancel();
          },
          onDone: () {
            if (!completer.isCompleted) completer.complete(const []);
            timeout.cancel();
          },
          cancelOnError: true,
        );
    return completer.future;
  }

  Map<String, String> _headers(String accept) => {
    'Accept': accept,
    'Content-Type': 'application/json',
    'X-Api-Key': _publicClientKey,
    'X-Requested-With': 'XMLHttpRequest',
    'User-Agent': 'YBS-AI/3.4.0 (train-live-read-only)',
  };
}

const _aesKey = 'hzUeAVMW0xthtWesyeXIqfXSX68dIpz0';

String decodePublicField(dynamic value) {
  if (value == null) return '';
  if (value is! String || value.length < 24 || value.length % 4 != 0) {
    return value.toString();
  }
  try {
    final encrypted = base64Decode(value);
    if (encrypted.isEmpty || encrypted.length % 16 != 0) return value;
    final cipher = CBCBlockCipher(AESEngine())
      ..init(
        false,
        ParametersWithIV(
          KeyParameter(Uint8List.fromList(utf8.encode(_aesKey))),
          Uint8List.fromList(utf8.encode(_aesKey.substring(0, 16))),
        ),
      );
    final output = Uint8List(encrypted.length);
    for (var offset = 0; offset < encrypted.length; offset += 16) {
      cipher.processBlock(encrypted, offset, output, offset);
    }
    final pad = output.last;
    if (pad < 1 || pad > 16 || output.length < pad) return value;
    for (var i = output.length - pad; i < output.length; i++) {
      if (output[i] != pad) return value;
    }
    return utf8.decode(output.sublist(0, output.length - pad));
  } catch (_) {
    return value;
  }
}
