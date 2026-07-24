import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../data/route_finder.dart';
import '../models.dart';
import '../services/local_store.dart';
import '../services/location_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/nav.dart';
import '../widgets/route_badge.dart';
import 'map_picker_page.dart';

class FindRoutePage extends StatefulWidget {
  final String? initialStart;
  final String? initialEnd;
  /// When pushed as a standalone route (e.g. from recent searches) this page
  /// needs to provide its own Scaffold + AppBar. As a bottom-nav tab it is
  /// already wrapped by RootShell's Scaffold, so set this to false there.
  final bool withScaffold;
  const FindRoutePage(
      {super.key,
      this.initialStart,
      this.initialEnd,
      this.withScaffold = false});
  @override
  State<FindRoutePage> createState() => _FindRoutePageState();
}

class _FindRoutePageState extends State<FindRoutePage> {
  String _start = '';
  String _end = '';
  StopOption? _startOpt;
  StopOption? _endOpt;
  BusStop? _startStop;
  BusStop? _endStop;
  List<SearchResult> _results = [];
  bool _searching = false;
  bool _hasSearched = false;
  bool _locating = false;
  List<BusStop>? _cachedStops;
  List<StopOption>? _cachedOptions;
  Map<String, BusStop>? _cachedStopByName;

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart ?? '';
    _end = widget.initialEnd ?? '';

    // If this page was opened with prefilled start/end from history,
    // immediately run search so the user doesn't see an empty page.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkPendingSearch();
      if (_start.trim().isNotEmpty && _end.trim().isNotEmpty) {
        _search();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Intentionally do NOT call _checkPendingSearch() here.
    // Consuming pending search triggers AppState.notifyListeners(),
    // which can cause setState/markNeedsBuild during build assertions.
  }


  void _checkPendingSearch() {
    // IMPORTANT: Avoid calling setState synchronously in reaction to
    // AppState.notifyListeners() (which can happen inside
    // getPendingSearchAndClear()).
    final (pendingStart, pendingEnd) =
        context.read<AppState>().getPendingSearchAndClear();

    if (pendingStart == null || pendingEnd == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _start = pendingStart;
        _end = pendingEnd;
      });

      if (_start.trim().isNotEmpty && _end.trim().isNotEmpty) {
        _search();
      }
    });
  }


  void setSearchValues(String start, String end) {
    setState(() {
      _start = start;
      _end = end;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_start.trim().isNotEmpty && _end.trim().isNotEmpty) {
        _search();
      }
    });
  }


  Future<void> _search() async {
    if (_start.trim().isEmpty || _end.trim().isEmpty) return;
    final state = context.read<AppState>();
    setState(() {
      _searching = true;
      _hasSearched = true;
    });

    // Resolve the precise stop the user actually picked. We prefer the exact
    // stop id chosen in the autocomplete (so a name that exists 3x in 3 areas
    // always resolves to the one the user tapped, never a same-named other).
    // For programmatic prefill (history) where no option was tapped we fall
    // back to coordinate disambiguation against the other end's location.
    _startStop = _resolveStop(state.stops, _startOpt, _start.trim(),
        hintStop: _endStop);
    _endStop = _resolveStop(state.stops, _endOpt, _end.trim(),
        hintStop: _startStop);

    // Phase 2: prefer the fast direct-route SQL query (correct forward
    // direction, no transfers). Fall back to the BFS planner (which computes
    // connecting/transfer routes from the same normalized data) when no
    // single-leg route exists.
    final direct = await state.repo.findDirectRoutes(
      _start.trim(),
      _end.trim(),
      startStop: _startStop,
      endStop: _endStop,
    );

    // Show each directly-serving bus line as its own result card (not all
    // mixed into a single card), so the user can pick one route at a time.
    final found = direct.isNotEmpty
        ? direct
            .map((r) => SearchResult(
                  steps: [
                    PathStep(
                        route: r,
                        fromStop: _start.trim(),
                        toStop: _end.trim())
                  ],
                  transferCount: 0,
                  totalDistance: 0,
                ))
            .toList()
        : performBFS(_start.trim(), _end.trim(), state.routes, state.stops);
    if (!mounted) return;
    setState(() {
      _results = found;
      _searching = false;
    });
    if (found.isNotEmpty) {
      await LocalStore.instance.addTripHistory(
          type: 'search', label: _start.trim(), subtitle: _end.trim());
    }
  }

  /// Resolve the precise [BusStop] for a query.
  /// [opt] is the exact option the user tapped in autocomplete — its id is
  /// authoritative, so a same-named stop in another area/direction is never
  /// picked. When [opt] is null (programmatic prefill) we fall back to
  /// [resolveStopByName] which disambiguates by the [hintStop]'s location.
  BusStop? _resolveStop(
    List<BusStop> stops,
    StopOption? opt,
    String name, {
    BusStop? hintStop,
  }) {
    if (opt != null) {
      final byId = stops.where((s) => s.id == opt.id).firstOrNull;
      if (byId != null) return byId;
    }
    return resolveStopByName(
      name,
      stops,
      hint: hintStop != null
          ? (lat: hintStop.lat, lng: hintStop.lng)
          : null,
    );
  }

  Future<void> _useCurrentLocation() async {
    final state = context.read<AppState>();
    if (state.stops.isEmpty) return;
    setState(() => _locating = true);
    final ok = await LocationService.instance.ensurePermission();
    if (!ok) {
      if (!mounted) return;
      setState(() => _locating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('တည်နေရာ ခွင့်ပြုချက် လိုအပ်ပါသည်')),
      );
      return;
    }
    final p = await LocationService.instance.currentPosition();
    if (!mounted) return;
    setState(() => _locating = false);
    if (p == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('တည်နေရာ မရနိုင်ပါ')),
      );
      return;
    }
    BusStop nearest = state.stops.first;
    double minD =
        getDistance(p.latitude, p.longitude, nearest.lat, nearest.lng);
    for (final s in state.stops) {
      final d = getDistance(p.latitude, p.longitude, s.lat, s.lng);
      if (d < minD) {
        minD = d;
        nearest = s;
      }
    }
    setState(() {
      _start = nearest.nameMm;
      _startStop = nearest;
      _startOpt = buildDisambiguatedStops(state.stops)
          .where((o) => o.id == nearest.id)
          .firstOrNull;
    });
    if (_end.trim().isNotEmpty) _search();
  }

  void _setStop(bool isStart, StopOption? opt) {
    final stop = opt == null
        ? null
        : context.read<AppState>().stops.where((s) => s.id == opt.id).firstOrNull;
    setState(() {
      if (isStart) {
        _startOpt = opt;
        _startStop = stop;
        _start = opt?.raw ?? '';
      } else {
        _endOpt = opt;
        _endStop = stop;
        _end = opt?.raw ?? '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (_cachedStops != state.stops) {
      _cachedStops = state.stops;
      _cachedOptions = buildDisambiguatedStops(state.stops);
      _cachedStopByName = {};
      for (final s in state.stops) {
        _cachedStopByName!.putIfAbsent(s.nameMm, () => s);
      }
    }
    final options = _cachedOptions!;
    final stopByName = _cachedStopByName!;

    final body = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: UI.card(),
          child: Column(
            children: [
              _StopField(
                label: 'စတင်မည့်မှတ်တိုင်',
                value: _startOpt,
                options: options,
                indicator: AppColors.emerald,
                onChanged: (o) => _setStop(true, o),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: _locating ? null : _useCurrentLocation,
                      icon: _locating
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.gps_fixed, size: 14),
                      label: const Text('Near Me',
                          style: TextStyle(fontSize: 12)),
                    ),
                    IconButton(
                      onPressed: () => _openPicker(true),
                      icon: const Icon(Icons.map_outlined, size: 18),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => setState(() {
                  final t = _start;
                  _start = _end;
                  _end = t;
                  final ts = _startStop;
                  _startStop = _endStop;
                  _endStop = ts;
                  final to = _startOpt;
                  _startOpt = _endOpt;
                  _endOpt = to;
                }),
                icon: const Icon(Icons.swap_vert),
              ),
              _StopField(
                label: 'ဆင်းမည့်မှတ်တိုင်',
                value: _endOpt,
                options: options,
                indicator: AppColors.rose,
                onChanged: (o) => _setStop(false, o),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: (_start.isEmpty || _end.isEmpty || _searching)
                      ? null
                      : _search,
                  icon: _searching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.search),
                  label: Text(
                      _searching ? 'ရှာဖွေနေပါသည်...' : 'လမ်းကြောင်းရှာပါ'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ..._results.map((r) => _resultCard(context, r, stopByName)),
        if (_results.isEmpty && _hasSearched && !_searching)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: const [
                Icon(Icons.search, size: 40, color: AppColors.slate300),
                SizedBox(height: 12),
                Text('လမ်းကြောင်း မတွေ့ပါ',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate500)),
                SizedBox(height: 4),
                Text('မှတ်တိုင်အမည် မှန်၊ မမှန် ပြန်စစ်ပေးပါ',
                    style:
                        TextStyle(fontSize: 13, color: AppColors.slate400)),
              ],
            ),
          ),
      ],
    );

    if (!widget.withScaffold) return body;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('လမ်းကြောင်း ရှာရန်'),
      ),
      body: body,
    );
  }

  Future<void> _openPicker(bool isStart) async {
    final state = context.read<AppState>();
    final selected = await Navigator.push<BusStop>(
      context,
      MaterialPageRoute(
          builder: (_) => MapPickerPage(
                stops: state.stops,
                title: isStart
                    ? 'စတင်မည့်မှတ်တိုင် ရွေးချယ်ပါ'
                    : 'ဆင်းမည့်မှတ်တိုင် ရွေးချယ်ပါ',
              )),
    );
    if (selected != null) {
      final opt = _cachedOptions!
          .where((o) => o.id == selected.id)
          .firstOrNull;
      _setStop(isStart, opt);
    }
  }

  Widget _resultCard(BuildContext context, SearchResult res,
      Map<String, BusStop> stopByName) {
    final first = res.steps.first;
    final last = res.steps.last;
    final fromStop = (_startStop != null && first.fromStop == _start)
        ? _startStop
        : stopByName[first.fromStop];
    final toStop = (_endStop != null && last.toStop == _end)
        ? _endStop
        : stopByName[last.toStop];
    return InkWell(
      onTap: () => Nav.openRoutePlan(context, res.steps),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: UI.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (int i = 0; i < res.steps.length; i++) ...[
                          RouteBadge(
                              routeId: res.steps[i].route.id,
                              color: res.steps[i].route.color,
                              small: true),
                          if (i < res.steps.length - 1)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(Icons.chevron_right,
                                  size: 14, color: AppColors.slate300),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Pill(
                  res.transferCount == 0
                      ? 'တိုက်ရိုက်'
                      : '${res.transferCount} ဆင့်ပြောင်း',
                  bg: res.transferCount == 0
                      ? AppColors.emeraldLight
                      : res.transferCount == 1
                          ? AppColors.amberLight
                          : AppColors.roseLight,
                  fg: res.transferCount == 0
                      ? AppColors.emeraldDark
                      : res.transferCount == 1
                          ? AppColors.brandHover
                          : AppColors.rose,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...res.steps.map((step) {
              final isFirstStep = step == first;
              final isLastStep = step == last;
              final from = isFirstStep && fromStop != null
                  ? fromStop
                  : stopByName[step.fromStop];
              final to = isLastStep && toStop != null
                  ? toStop
                  : stopByName[step.toStop];
              final fromLabel = _stopLabel(from, step.fromStop);
              final toLabel = _stopLabel(to, step.toStop);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        margin: const EdgeInsets.only(top: 6),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: step.route.color,
                            shape: BoxShape.circle)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Pill('စီးရန်'),
                              const SizedBox(width: 6),
                              Text('YBS ${step.route.id}',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500)),
                              if (step.route.qrPayment == '✅ Supported') ...[
                                const SizedBox(width: 6),
                                const Pill('QR',
                                    bg: AppColors.amberLight,
                                    fg: AppColors.brandHover,
                                    icon: Icons.credit_card),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('$fromLabel မှ $toLabel အထိ',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.slate500)),
                          if (from != null && to != null)
                            Text(
                                '${getDistance(from.lat, from.lng, to.lat, to.lng).toStringAsFixed(2)} km',
                                style: const TextStyle(
                                    fontSize: 10, color: AppColors.slate400)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

String _stopLabel(BusStop? stop, String fallback) {
  if (stop == null) return fallback;
  final parts = <String>[];
  if (stop.roadMm.isNotEmpty) parts.add(stop.roadMm);
  if (stop.townshipMm.isNotEmpty && stop.townshipMm != stop.roadMm) parts.add(stop.townshipMm);
  if (parts.isEmpty) return stop.nameMm;
  return '${stop.nameMm} (${parts.join(' · ')})';
}

class _StopField extends StatefulWidget {
  final String label;
  final StopOption? value;
  final List<StopOption> options;
  final Color indicator;
  final ValueChanged<StopOption?> onChanged;
  final Widget? trailing;
  const _StopField({
    required this.label,
    required this.value,
    required this.options,
    required this.indicator,
    required this.onChanged,
    this.trailing,
  });

  @override
  State<_StopField> createState() => _StopFieldState();
}

class _StopFieldState extends State<_StopField> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(widget.label.toUpperCase(),
                style: UI.label.copyWith(letterSpacing: 0.5)),
            const Spacer(),
            if (widget.trailing != null) widget.trailing!,
          ],
        ),
        const SizedBox(height: 6),
        // Key the Autocomplete by the selected option id so external changes
        // (map picker, swap, Near Me) rebuild it with the correct initial
        // text. Autocomplete fully owns its text controller — we never touch
        // it during build, which is what previously broke the dropdown.
        Autocomplete<StopOption>(
          key: ValueKey(widget.value?.id),
          initialValue:
              TextEditingValue(text: _displayFor(widget.value)),
          fieldViewBuilder:
              (context, controller, focusNode, onFieldSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: 'ရှာရန်...',
                prefixIcon: Container(
                  width: 4,
                  margin: const EdgeInsets.only(right: 8),
                  color: widget.indicator,
                ),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 12, maxWidth: 12),
              ),
              onChanged: (v) {
                if (v.isEmpty) widget.onChanged(null);
              },
            );
          },
          optionsBuilder: (t) {
            final term = t.text.toLowerCase();
            if (term.isEmpty) return const Iterable<StopOption>.empty();
            return widget.options
                .where((o) =>
                    o.display.toLowerCase().contains(term) ||
                    o.raw.toLowerCase().contains(term))
                .take(50);
          },
          onSelected: (o) => widget.onChanged(o),
          optionsViewBuilder: (context, onSelected, opts) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxHeight: 240, maxWidth: 400),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    children: opts
                        .map((o) => ListTile(
                              dense: true,
                              title: Text(o.display,
                                  style: const TextStyle(fontSize: 13)),
                              onTap: () => onSelected(o),
                            ))
                        .toList(),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  String _displayFor(StopOption? opt) => opt?.display ?? '';
}
