import 'package:flutter/material.dart';
import '../config.dart';
import '../data/route_finder.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
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
  int _attempt = 0;
  final DeviceService _deviceService = DeviceService();
  final Map<int, int> _myVotes = {};
  final Map<int, bool> _voting = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final data = await ApiService.instance
          .fetchBusUpdates(routeId: widget.routeId, limit: widget.limit)
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      setState(() {
        _updates = data;
        _loading = false;
      });
      if (data.isNotEmpty) widget.onLoaded?.call(data);
      _loadVotes();
    } catch (e) {
      if (!mounted) return;
      if (_attempt == 0) {
        _attempt++;
        setState(() => _loading = false);
        Future.delayed(const Duration(seconds: 2), _load);
        return;
      }
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  Future<void> _loadVotes() async {
    final deviceId = await _deviceService.getDeviceId();
    if (!mounted) return;
    final newVotes = <int, int>{};
    for (final u in _updates) {
      if (u.id == null) continue;
      final status = await ApiService.instance.getVoteStatus(
        updateId: u.id!,
        deviceId: deviceId,
      );
      newVotes[u.id!] = (status['myVote'] as num?)?.toInt() ?? 0;
    }
    if (!mounted) return;
    setState(() => _myVotes.addAll(newVotes));
  }

  Future<void> _vote(int? updateId, int voteValue) async {
    if (updateId == null) return;
    if (_voting[updateId] == true) return;
    final deviceId = await _deviceService.getDeviceId();
    setState(() => _voting[updateId] = true);
    final res = await ApiService.instance.voteUpdate(
      updateId: updateId,
      deviceId: deviceId,
      vote: voteValue,
    );
    if (!mounted) return;
    if (res['ok'] == true) {
      setState(() {
        _myVotes[updateId] = voteValue;
        final idx = _updates.indexWhere((u) => u.id == updateId);
        if (idx != -1) {
          _updates[idx] = BusUpdate(
            id: _updates[idx].id,
            routeId: _updates[idx].routeId,
            stop: _updates[idx].stop,
            type: _updates[idx].type,
            note: _updates[idx].note,
            lat: _updates[idx].lat,
            lng: _updates[idx].lng,
            userId: _updates[idx].userId,
            upvotes: (res['upvotes'] as num?)?.toInt() ?? _updates[idx].upvotes,
            createdAt: _updates[idx].createdAt,
          );
        }
      });
    }
    setState(() => _voting[updateId] = false);
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
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_loading && _updates.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'ရယူနေပါသည်...',
              style: TextStyle(color: AppColors.textMuted),
            ),
          )
        else if (_error)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'အချက်အလက် ရယူ၍ မရပါ။',
                  style: TextStyle(color: AppColors.rose),
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
            child: Text(
              'လောလောဆယ် အချက်အလက် မရှိသေးပါ။',
              style: TextStyle(color: AppColors.textMuted),
            ),
          )
        else
          ..._updates.map(_updateCard),
      ],
    );
  }

  Widget _updateCard(BusUpdate u) {
    final meta = updateTypeMeta[u.type]!;
    final myVote = _myVotes[u.id ?? 0] ?? 0;
    final voting = _voting[u.id ?? 0] ?? false;
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
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.campaign,
              size: 14,
              color: AppColors.slate500,
            ),
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
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: meta.bg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        meta.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: meta.color,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      timeAgo(u.createdAt),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                if (u.stop != null && u.stop!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '📍 ${u.stop}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (u.note != null && u.note!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      u.note!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _VoteButton(
                      icon: Icons.thumb_up,
                      active: myVote == 1,
                      onTap: voting ? null : () => _vote(u.id, 1),
                    ),
                    const SizedBox(width: 6),
                    _VoteButton(
                      icon: Icons.thumb_down,
                      active: myVote == -1,
                      onTap: voting ? null : () => _vote(u.id, -1),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${u.upvotes}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: u.upvotes > 0
                            ? AppColors.emerald
                            : u.upvotes < 0
                            ? AppColors.rose
                            : AppColors.slate500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;
  const _VoteButton({required this.icon, required this.active, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? (icon == Icons.thumb_up
                    ? AppColors.emeraldLight
                    : AppColors.roseLight)
              : AppColors.slate100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? (icon == Icons.thumb_up ? AppColors.emerald : AppColors.rose)
                : AppColors.borderLight,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: active
                  ? (icon == Icons.thumb_up
                        ? AppColors.emerald
                        : AppColors.rose)
                  : AppColors.slate500,
            ),
          ],
        ),
      ),
    );
  }
}
