import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../config.dart';

/// A reusable OpenStreetMap map (matches web Leaflet tiles).
class OsmMap extends StatelessWidget {
  final MapController? controller;
  final LatLng center;
  final double zoom;
  final List<Marker> markers;
  final List<Polyline> polylines;
  final void Function(TapPosition, LatLng)? onTap;
  final void Function(MapCamera, bool)? onPositionChanged;
  final bool interactive;
  final String? tileUrl;

  const OsmMap({
    super.key,
    this.controller,
    required this.center,
    this.zoom = 13,
    this.markers = const [],
    this.polylines = const [],
    this.onTap,
    this.onPositionChanged,
    this.interactive = true,
    this.tileUrl,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        onTap: onTap,
        onPositionChanged: onPositionChanged,
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: tileUrl ?? AppConfig.osmTileUrl,
          userAgentPackageName: AppConfig.osmUserAgent,
          // Keep recently viewed tiles on disk so previously visited areas can
          // still render when the device temporarily loses connectivity.
          // This is a cache, not a guaranteed full offline map download.
          tileProvider: NetworkTileProvider(
            cachingProvider: BuiltInMapCachingProvider.getOrCreateInstance(
              maxCacheSize: 300 * 1024 * 1024,
              overrideFreshAge: const Duration(days: 30),
            ),
          ),
        ),
        if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
        if (markers.isNotEmpty) MarkerLayer(markers: markers),
      ],
    );
  }
}

Marker dotMarker(
  LatLng point, {
  required Color color,
  double size = 16,
  Color border = Colors.white,
  Widget? child,
  String? label,
  String? subtitle,
}) {
  final markerChild =
      child ??
      Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: border, width: 2),
        ),
      );

  if (label == null || label.isEmpty) {
    return Marker(point: point, width: size, height: size, child: markerChild);
  }

  return Marker(
    point: point,
    width: size + 120,
    height: size + 80,
    child: Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Positioned(
          bottom: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                constraints: const BoxConstraints(maxWidth: 120),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w400,
                          color: AppColors.slate400,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(width: size, height: size, child: markerChild),
            ],
          ),
        ),
      ],
    ),
  );
}
