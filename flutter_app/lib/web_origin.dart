import 'package:web/web.dart' show window;

/// Returns the current web page origin (e.g. "http://localhost:3000").
String? currentWebOrigin() {
  try {
    final o = window.location.origin;
    return o.isNotEmpty ? o : null;
  } catch (_) {
    return null;
  }
}
