import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../data/route_finder.dart';
import '../models.dart';
import '../services/local_store.dart';
import '../services/location_service.dart';
import '../state/app_state.dart';
import '../util/nav.dart';

class AssistantPage extends StatefulWidget {
  const AssistantPage({super.key});
  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _loading = false;
  final List<ChatMessage> _messages = [
    const ChatMessage(
        role: 'assistant',
        content:
            'မင်္ဂလာပါ! YBS Assistant ပါ။ ဘယ်ကနေ ဘယ်ကို သွားချင်လဲ? ဥပမာ - "မြေနီကုန်းကနေ ဆူးလေကို ဘယ်လိုသွားရမလဲ" လို့ မေးလို့ရပါတယ်။'),
  ];

  // Quick suggestion chips shown under the input.
  final List<String> _suggestions = [
    'ဆူးလေကနေ လှည်းတန်းကို',
    'မြေနီကုန်းကနေ ရန်ကုန်တက္ကသိုလ်',
    'ကန်တော်ကနေ လှိုင်ဘူတာ',
    'အန်းလျှိုင်ကနေ သန်လျင်ကို',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _loading) return;
    final state = context.read<AppState>();
    if (preset == null) _controller.clear();
    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _loading = true;
    });
    _scrollDown();

    await Future.delayed(const Duration(milliseconds: 450));
    final reply = await _answer(text, state);

    if (mounted) {
      setState(() {
        _messages.add(reply);
        _loading = false;
      });
      _scrollDown();
    }
  }

  /// Builds an assistant reply: extracts start/end (with fuzzy name
  /// resolution), searches SQLite direct routes first, then falls back to the
  /// BFS transfer planner, and returns a rich Burmese response.
  Future<ChatMessage> _answer(String text, AppState state) async {
    final allStopNames = state.stops.map((s) => s.nameMm).toList();

    // Handle "from my location" style queries.
    String? nearMeStart;
    var query = text;
    if (RegExp(r'နောက်|ကျွန်တော်.*နေ|ကိုယ်.*နေ|မိမိနေ|လက်ရှိနေ|အနီးဆုံး')
        .hasMatch(text)) {
      nearMeStart = await _nearestStopName(state);
      if (nearMeStart != null) {
        query = text.replaceAll(
            RegExp(r'နောက်|ကျွန်တော်.*နေ|ကိုယ်.*နေ|မိမိနေ|လက်ရှိနေ|အနီးဆုံး'),
            nearMeStart);
      }
    }

    final extracted = extractStopsFromText(query, allStopNames);

    String? start = extracted?['start'];
    String? end = extracted?['end'];

    // Fuzzy-resolve partial / misspelled stop names (the "AI" touch).
    if (start != null) start = resolveStopName(start, allStopNames) ?? start;
    if (end != null) end = resolveStopName(end, allStopNames) ?? end;
    if (nearMeStart != null && start == null) start = nearMeStart;

    if (start == null && end == null) {
      return const ChatMessage(
          role: 'assistant',
          content:
              'တောင်းပန်ပါတယ်၊ သင်ပြောတဲ့ မှတ်တိုင်အမည်ကို ရှာမတွေ့ပါဘူး။ ဥပမာ - "မြေနီကုန်းကနေ ဆူးလေကို ဘယ်လိုသွားရမလဲ" လို့ ပြန်မေးပေးပါဦး။');
    }

    if (start != null && end == null) {
      return ChatMessage(
          role: 'assistant',
          content: '$start ကနေ ဘယ်ကို သွားချင်တာလဲခင်ဗျာ?');
    }

    if (start == null && end != null) {
      return ChatMessage(
          role: 'assistant',
          content: '$end ကို ဘယ်မှတ်တိုင်ကနေ လာမှာလဲခင်ဗျာ?');
    }

    // 1) Fast SQLite direct-route lookup (correct forward direction).
    final direct = await state.repo.findDirectRoutes(start!, end!);
    final List<SearchResult> found = direct.isNotEmpty
        ? direct
            .map((r) => SearchResult(
                  steps: [
                    PathStep(route: r, fromStop: start!, toStop: end!)
                  ],
                  transferCount: 0,
                  totalDistance: 0,
                ))
            .toList()
        // 2) Fall back to the BFS planner for transfer routes.
        : performBFS(start, end, state.routes, state.stops);

    if (found.isNotEmpty) {
      final directCount = found.where((r) => r.transferCount == 0).length;
      final transferCount = found.length - directCount;
      final summary = [
        '$start မှ $end သို့ စီးရမည့် လမ်းကြောင်း ${found.length} ခု တွေ့ပါတယ်။',
        if (directCount > 0) '• တိုက်ရိုက် လိုင်း $directCount ခု',
        if (transferCount > 0) '• ကားပြောင်းစီးရမည့် လမ်းကြောင်း $transferCount ခု',
        'အောက်က ရလဒ်ကို နှိပ်ပြီး အသေးစိတ် ကြည့်နိုင်ပါတယ်။',
      ].join('\n');
      await LocalStore.instance.addTripHistory(
          type: 'search', label: start, subtitle: end);
      return ChatMessage(
          role: 'assistant', content: summary, results: found.take(4).toList());
    }

    return ChatMessage(
        role: 'assistant',
        content:
            '$start မှ $end သို့ တိုက်ရိုက် သို့မဟုတ် တစ်ဆင့်ပြောင်း လမ်းကြောင်း ရှာမတွေ့ပါဘူး။ မှတ်တိုင်အမည်လေး အနည်းငယ် ပြောင်းကြည့်ပေးပါဦး။');
  }

  Future<String?> _nearestStopName(AppState state) async {
    if (state.stops.isEmpty) return null;
    final p = await LocationService.instance.currentPosition();
    if (p == null) return null;
    BusStop nearest = state.stops.first;
    double minD = getDistance(
        p.latitude, p.longitude, nearest.lat, nearest.lng);
    for (final s in state.stops) {
      final d = getDistance(p.latitude, p.longitude, s.lat, s.lng);
      if (d < minD) {
        minD = d;
        nearest = s;
      }
    }
    return nearest.nameMm;
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_loading ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i >= _messages.length) {
                    return const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                    );
                  }
                  return _bubble(_messages[i]);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ActionChip(
                    label: Text(_suggestions[i],
                        style: const TextStyle(fontSize: 12)),
                    backgroundColor: AppColors.brandLight,
                    labelStyle: const TextStyle(color: AppColors.brandHover),
                    onPressed: () => _send(_suggestions[i]),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppColors.bg,
                border: Border(top: BorderSide(color: AppColors.borderLight)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                          hintText: 'မေးမြန်းလိုသည်များကို ရိုက်ထည့်ပါ...'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.all(14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    onPressed: _send,
                    child: const Icon(Icons.send, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(ChatMessage m) {
    final isUser = m.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? AppColors.brand : AppColors.slate100,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 2),
            bottomRight: Radius.circular(isUser ? 2 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.content,
                style: TextStyle(
                    fontSize: 14,
                    color: isUser ? Colors.white : AppColors.text)),
            if (m.results != null)
              ...m.results!.map((res) => GestureDetector(
                    onTap: () => Nav.openRoutePlan(context, res.steps),
                    child: Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.slate200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              for (int i = 0; i < res.steps.length; i++) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius:
                                          BorderRadius.circular(4)),
                                  child: Text('YBS ${res.steps[i].route.id}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                ),
                                if (i < res.steps.length - 1)
                                  const Icon(Icons.chevron_right,
                                      size: 12, color: AppColors.slate400),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${res.transferCount == 0 ? 'တိုက်ရိုက်' : '${res.transferCount} ဆင့်ပြောင်း'} • ${res.totalDistance.toStringAsFixed(1)} km',
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.slate500),
                          ),
                        ],
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
