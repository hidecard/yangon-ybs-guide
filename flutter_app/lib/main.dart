import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:vibration/vibration.dart';

import 'models/route_models.dart';
import 'services/route_repository.dart';

void main() => runApp(const YbsPassengerArApp());

class YbsPassengerArApp extends StatelessWidget {
  const YbsPassengerArApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'YBS Passenger AR',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff0e7490)),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xfff5f8fa),
        ),
        home: const RouteSelectionScreen(),
      );
}

class RouteSelectionScreen extends StatefulWidget {
  const RouteSelectionScreen({super.key});
  @override
  State<RouteSelectionScreen> createState() => _RouteSelectionScreenState();
}

class _RouteSelectionScreenState extends State<RouteSelectionScreen> {
  final repository = RouteRepository();
  late Future<List<BusRoute>> futureRoutes;
  BusRoute? selectedRoute;
  BusStop? boardingStop;
  BusStop? destinationStop;

  @override
  void initState() {
    super.initState();
    futureRoutes = repository.loadRoutes();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('YBS Passenger AR'),
          centerTitle: false,
          backgroundColor: Colors.transparent,
        ),
        body: FutureBuilder<List<BusRoute>>(
          future: futureRoutes,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('YBS route data မဖတ်နိုင်ပါ'));
            }
            final routes = snapshot.data!;
            final route = selectedRoute ?? routes.first;
            final boarding = boardingStop ?? route.stops.first;
            final destination = destinationStop ?? route.stops.last;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                _HeroCard(routeCount: routes.length),
                const SizedBox(height: 18),
                const Text('ခရီးစဉ်ရွေးချယ်ပါ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                _label('YBS Route'),
                DropdownButtonFormField<BusRoute>(
                  value: route,
                  isExpanded: true,
                  decoration: _decoration('YBS နံပါတ်ရွေးပါ'),
                  items: routes.map((item) => DropdownMenuItem(
                    value: item,
                    child: Text('YBS ${item.id}  •  ${item.name}', overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (value) => setState(() {
                    selectedRoute = value;
                    boardingStop = value?.stops.first;
                    destinationStop = value?.stops.last;
                  }),
                ),
                const SizedBox(height: 14),
                _label('တက်မည့်မှတ်တိုင်'),
                DropdownButtonFormField<BusStop>(
                  value: boarding,
                  isExpanded: true,
                  decoration: _decoration('Boarding stop'),
                  items: route.stops.map(_stopItem).toList(),
                  onChanged: (value) => setState(() {
                    boardingStop = value;
                    if (value != null &&
                        (destinationStop == null || destinationStop!.sequence <= value.sequence)) {
                      destinationStop = route.stops.last;
                    }
                  }),
                ),
                const SizedBox(height: 14),
                _label('ဆင်းမည့်မှတ်တိုင်'),
                DropdownButtonFormField<BusStop>(
                  value: destination,
                  isExpanded: true,
                  decoration: _decoration('Destination stop'),
                  items: route.stops
                      .where((stop) => stop.sequence > boarding.sequence)
                      .map(_stopItem)
                      .toList(),
                  onChanged: (value) => setState(() => destinationStop = value),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: destination.sequence <= boarding.sequence
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => TripMapScreen(
                              route: route,
                              boardingStop: boarding,
                              destinationStop: destination,
                            ),
                          )),
                  icon: const Icon(Icons.navigation_rounded),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Normal Map ဖြင့် ခရီးစဉ်စတင်မည်', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 18),
                const _InfoBox(),
              ],
            );
          },
        ),
      );

  DropdownMenuItem<BusStop> _stopItem(BusStop stop) => DropdownMenuItem(
        value: stop,
        child: Text('${stop.nameMm}  •  ${stop.nameEn}', overflow: TextOverflow.ellipsis),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      );

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      );
}

class TripMapScreen extends StatefulWidget {
  const TripMapScreen({super.key, required this.route, required this.boardingStop, required this.destinationStop});
  final BusRoute route;
  final BusStop boardingStop;
  final BusStop destinationStop;
  @override
  State<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends State<TripMapScreen> {
  StreamSubscription<Position>? locationSubscription;
  Position? position;
  GoogleMapController? mapController;
  int currentIndex = 0;
  double distanceToNext = 0;
  final tts = FlutterTts();
  final announced = <String>{};

  @override
  void initState() {
    super.initState();
    currentIndex = widget.boardingStop.sequence;
    _startLocationTracking();
  }

  Future<void> _startLocationTracking() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
    final current = await Geolocator.getCurrentPosition();
    _updatePosition(current);
    locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 10),
    ).listen(_updatePosition);
  }

  void _updatePosition(Position value) {
    final start = widget.boardingStop.sequence;
    final end = widget.destinationStop.sequence;
    var nearest = currentIndex;
    var nearestDistance = double.infinity;
    for (var i = math.max(start, currentIndex); i <= end && i < widget.route.stops.length; i++) {
      final distance = widget.route.stops[i].distanceTo(value.latitude, value.longitude);
      if (distance < nearestDistance) {
        nearest = i;
        nearestDistance = distance;
      }
    }
    setState(() {
      position = value;
      currentIndex = nearest;
      distanceToNext = currentIndex < end ? widget.route.stops[currentIndex + 1].distanceTo(value.latitude, value.longitude) : 0;
    });
    _announceIfNeeded();
    mapController?.animateCamera(CameraUpdate.newLatLng(LatLng(value.latitude, value.longitude)));
  }

  Future<void> _announceIfNeeded() async {
    final remaining = widget.destinationStop.sequence - currentIndex;
    final key = '$remaining';
    if ((remaining == 3 || remaining == 1 || remaining == 0) && announced.add(key)) {
      final message = remaining == 0
          ? '${widget.destinationStop.nameMm} မှတ်တိုင် ရောက်ပါပြီ'
          : remaining == 1
              ? 'ပြင်ဆင်ထားပါ။ နောက်မှတ်တိုင်မှာ ဆင်းရပါမယ်'
              : '${widget.destinationStop.nameMm} သို့ $remaining မှတ်တိုင်လိုပါသည်';
      if (await Vibration.hasVibrator()) await Vibration.vibrate(duration: 500);
      await tts.speak(message);
    }
  }

  @override
  void dispose() {
    locationSubscription?.cancel();
    tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.route.stops[currentIndex.clamp(0, widget.route.stops.length - 1)];
    final next = currentIndex + 1 < widget.route.stops.length ? widget.route.stops[currentIndex + 1] : null;
    final points = widget.route.stops
        .sublist(widget.boardingStop.sequence, widget.destinationStop.sequence + 1)
        .map((stop) => LatLng(stop.latitude, stop.longitude))
        .toList();
    final markers = <Marker>{
      Marker(markerId: const MarkerId('boarding'), position: LatLng(widget.boardingStop.latitude, widget.boardingStop.longitude), infoWindow: const InfoWindow(title: 'တက်မည့်မှတ်တိုင်')),
      Marker(markerId: const MarkerId('destination'), position: LatLng(widget.destinationStop.latitude, widget.destinationStop.longitude), infoWindow: InfoWindow(title: 'ဆင်းမည့်မှတ်တိုင်', snippet: widget.destinationStop.nameMm)),
      if (position != null) Marker(markerId: const MarkerId('user'), position: LatLng(position!.latitude, position!.longitude), icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure), infoWindow: const InfoWindow(title: 'လက်ရှိနေရာ')),
    };
    return Scaffold(
      appBar: AppBar(title: Text('YBS ${widget.route.id} → ${widget.destinationStop.nameMm}')),
      body: Stack(children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: LatLng(widget.boardingStop.latitude, widget.boardingStop.longitude), zoom: 14.5),
          myLocationEnabled: position != null,
          myLocationButtonEnabled: true,
          markers: markers,
          polylines: {Polyline(polylineId: const PolylineId('ybs-route'), points: points, color: const Color(0xff0e7490), width: 6)},
          onMapCreated: (controller) => mapController = controller,
        ),
        Positioned(top: 16, left: 16, right: 16, child: _TripSummary(route: widget.route, current: current, next: next, destination: widget.destinationStop, remaining: widget.destinationStop.sequence - currentIndex, distance: distanceToNext)),
        Positioned(bottom: 22, left: 18, right: 18, child: FilledButton.icon(
          onPressed: next == null ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PassengerArScreen(trip: TripState(route: widget.route, boardingStop: widget.boardingStop, destinationStop: widget.destinationStop, latitude: position?.latitude, longitude: position?.longitude, currentIndex: currentIndex, distanceToNextStop: distanceToNext)))),
          icon: const Icon(Icons.view_in_ar_rounded), label: const Padding(padding: EdgeInsets.symmetric(vertical: 13), child: Text('ကားပေါ်ရောက်လျှင် Passenger AR ဖွင့်မည်', style: TextStyle(fontWeight: FontWeight.bold))),
        )),
      ]),
    );
  }
}

class PassengerArScreen extends StatefulWidget {
  const PassengerArScreen({super.key, required this.trip});
  final TripState trip;
  @override
  State<PassengerArScreen> createState() => _PassengerArScreenState();
}

class _PassengerArScreenState extends State<PassengerArScreen> {
  CameraController? camera;
  StreamSubscription<CompassEvent>? compassSubscription;
  double heading = 0;
  bool cameraReady = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
    compassSubscription = Compass.events?.listen((event) => setState(() => heading = event.heading ?? 0));
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      camera = CameraController(cameras.first, ResolutionPreset.medium, enableAudio: false);
      await camera!.initialize();
      if (mounted) setState(() => cameraReady = true);
    } catch (_) {}
  }

  @override
  void dispose() {
    compassSubscription?.cancel();
    camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final next = widget.trip.nextStop;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        if (cameraReady) Positioned.fill(child: CameraPreview(camera!)) else const Positioned.fill(child: ColoredBox(color: Color(0xff102a33))),
        Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(.65), Colors.transparent, Colors.black.withOpacity(.8)])))),
        SafeArea(child: Column(children: [
          Padding(padding: const EdgeInsets.all(16), child: Row(children: [
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white)),
            Expanded(child: Text('YBS ${widget.trip.route.id} → ${widget.trip.destinationStop.nameMm}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17))),
            const Icon(Icons.explore, color: Colors.white),
          ])),
          _ArStatusCard(trip: widget.trip, next: next),
          const Spacer(),
          Transform.rotate(angle: heading * math.pi / 180, child: const Icon(Icons.navigation_rounded, color: Color(0xff62e6d8), size: 96)),
          const Spacer(),
          if (next != null) _ArLabel(title: next.nameMm, subtitle: '${widget.trip.distanceToNextStop.round()} m • နောက်မှတ်တိုင်'),
          _ArBottomBar(destination: widget.trip.destinationStop.nameMm, remaining: widget.trip.remainingStops),
        ])),
      ]),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.routeCount});
  final int routeCount;
  @override
  Widget build(BuildContext context) => Card(color: const Color(0xff083344), child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Icon(Icons.directions_bus_filled_rounded, color: Color(0xff67e8f9), size: 34),
    const SizedBox(height: 10),
    const Text('YBS Passenger AR', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
    const SizedBox(height: 6),
    Text('$routeCount routes offline • Next stop alert', style: const TextStyle(color: Color(0xffbae6fd))),
  ])));
}

class _InfoBox extends StatelessWidget {
  const _InfoBox();
  @override
  Widget build(BuildContext context) => const Card(child: Padding(padding: EdgeInsets.all(16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.info_outline, color: Color(0xff0e7490)), SizedBox(width: 10), Expanded(child: Text('ကားပေါ်ရောက်ပြီးနောက် Passenger AR ကို ဖွင့်ပါ။ နောက်မှတ်တိုင်၊ ဆင်းရမည့်မှတ်တိုင်နဲ့ Voice/Vibration alert ကို ပြပေးပါမယ်။'))])));
}

class _TripSummary extends StatelessWidget {
  const _TripSummary({required this.route, required this.current, required this.next, required this.destination, required this.remaining, required this.distance});
  final BusRoute route;
  final BusStop current;
  final BusStop? next;
  final BusStop destination;
  final int remaining;
  final double distance;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('YBS ${route.id}  •  ${route.name}', style: const TextStyle(fontWeight: FontWeight.w800)),
    const SizedBox(height: 8),
    Text('လက်ရှိ: ${current.nameMm}'),
    Text('နောက်မှတ်တိုင်: ${next?.nameMm ?? 'ရောက်ပါပြီ'}  •  ${distance.round()} m'),
    Text('ဆင်းရန်: ${destination.nameMm}  •  $remaining မှတ်တိုင်လိုပါသည်'),
  ])));
}

class _ArStatusCard extends StatelessWidget {
  const _ArStatusCard({required this.trip, required this.next});
  final TripState trip;
  final BusStop? next;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Card(color: Colors.black.withOpacity(.58), child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
    const Icon(Icons.directions_bus, color: Color(0xff67e8f9)), const SizedBox(width: 10),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(next?.nameMm ?? 'Destination', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)), Text('${trip.distanceToNextStop.round()} m • ${trip.remainingStops} stops remaining', style: const TextStyle(color: Colors.white70))])),
  ])));
}

class _ArLabel extends StatelessWidget {
  const _ArLabel({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.symmetric(horizontal: 28), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13), decoration: BoxDecoration(color: const Color(0xff0e7490).withOpacity(.92), borderRadius: BorderRadius.circular(18)), child: Row(children: [const Icon(Icons.place, color: Colors.white), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)), Text(subtitle, style: const TextStyle(color: Colors.white70))]))]));
}

class _ArBottomBar extends StatelessWidget {
  const _ArBottomBar({required this.destination, required this.remaining});
  final String destination;
  final int remaining;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 18), child: Row(children: [Expanded(child: Text('ဆင်းရန်: $destination\n$remaining မှတ်တိုင်လိုပါသည်', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))), IconButton(onPressed: () {}, icon: const Icon(Icons.volume_up, color: Colors.white)), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.map, color: Colors.white))]));
}
