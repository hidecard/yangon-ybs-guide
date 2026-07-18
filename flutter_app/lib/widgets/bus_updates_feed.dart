import 'package:flutter/material.dart';
import '../config.dart';
import '../data/route_finder.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'route_badge.dart';

class BusUpdatesFeed extends StatefulWidget {
  final String? routeId;
  final int limit;
  final String? title;
  final void Function(String routeId)? onRouteTap;
  final void Function(List<BusUpdate> updates)? onLoaded;
  const BusUpdatesFeed({
    super.key,
    this.routeId,
    this.limit = 20,
    this.title,
    this.onRouteTap,
    this.onLoaded,
  });

  @override
  State<BusUpdatesFeed> createState() => _BusUpdatesFeedState();
}

class _BusUpdatesFeedState extends State<BusUpdatesFeed> {
  List<BusUpdate> _updates = [];
  bool _loading = true;
  bool _error = false;
  String _errorMsg = '';
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
      _errorMsg = '';
    });
    try {
      // Avoid infinite loading when backend/network hangs.
      final data = await ApiService.instance
          .fetchBusUpdates(routeId: widget.routeId, limit: widget.limit)
          .timeout(const Duration(seconds: 10));


      if (!mounted) return;
      setState(() {
        _updates = data;
        _loading = false;
      });
      if (data.isNotEmpty) widget.onLoaded?.call(data);
    } catch (e) {
      if (!mounted) return;
      // Auto-retry once shortly after (covers startup network races).
      if (_attempt == 0) {
        _attempt++;
        setState(() => _loading = false);
        Future.delayed(const Duration(seconds: 2), _load);
        return;
      }
      setState(() {
        _error = true;
        _errorMsg = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.title ?? 'ယာဉ်လိုင်း အချက်အလက် (အသုံးပြုသူများ)',
                style: UI.sectionTitle,
              ),
            ),
            IconButton(
              onPressed: _loading ? null : _load,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_loading && _updates.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('ရယူနေပါသည်...',
                style: TextStyle(color: AppColors.textMuted)),
          )
        else if (_error)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('အချက်အလက် ရယူ၍ မရပါ။',
                    style: TextStyle(color: AppColors.rose)),
                if (_errorMsg.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(_errorMsg,
                        style: const TextStyle(
                            color: AppColors.slate400, fontSize: 11)),
                  ),
                TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('ထပ်ကြိုးစားမည်'),
                ),
              ],
            ),
          )
        else if (_updates.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('လောလောဆယ် အချက်အလက် မရှိသေးပါ။',
                style: TextStyle(color: AppColors.textMuted)),
          )
        else
          ..._updates.map(_updateCard),
      ],
    );
  }

  Widget _updateCard(BusUpdate u) {
    final meta = updateTypeMeta[u.type]!;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: UI.card(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.campaign,
                size: 14, color: AppColors.slate500),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    RouteBadge(
                      routeId: u.routeId,
                      color: AppColors.emerald,
                      small: true,
                      onTap: () => widget.onRouteTap?.call(u.routeId),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: meta.bg,
                          borderRadius: BorderRadius.circular(999)),
                      child: Text(meta.label,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: meta.color)),
                    ),
                    const Spacer(),
                    Text(timeAgo(u.createdAt),
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textMuted)),
                  ],
                ),
                if (u.stop != null && u.stop!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('📍 ${u.stop}',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                if (u.note != null && u.note!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(u.note!,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
