import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../models.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../state/app_state.dart';
import '../theme.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  final DeviceService _deviceService = DeviceService();
  List<LeaderboardEntry> _entries = [];
  LeaderboardEntry? _myRank;
  bool _loading = true;
  bool _monthly = false;
  String? _deviceId;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final state = context.read<AppState>();
    final deviceId = await _deviceService.getDeviceId();
    final name = await state.store.leaderboardUserName();
    setState(() {
      _deviceId = deviceId;
      _userName = name;
    });
    await _loadLeaderboard();
    if (name == null && mounted) {
      await _showNameDialog(deviceId);
    }
  }

  Future<void> _showNameDialog(String deviceId) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.emoji_events, color: AppColors.amber, size: 40),
        title: const Text('Leaderboard သို့ ကြိုဆိုပါတယ်'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('သတင်းတင်တိုင်း Point ရရှိ၍ Leaderboard မှာ ပြိုင်ဆိုင်မည့် သင့်အမည်ကို ဖြည့်ပါ။'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLength: 20,
              decoration: const InputDecoration(
                hintText: 'ဥပမာ - ကားမိုက်တိုက်',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.length < 2) return;
              final data = await ApiService.instance.registerLeaderboardUser(
                deviceId: deviceId,
                userName: name,
              );
              if (data['error'] != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(data['error'].toString())),
                );
                return;
              }
              if (mounted) {
                context.read<AppState>().store.setLeaderboardUserName(name);
                setState(() => _userName = name);
                Navigator.pop(context, name);
              }
            },
            child: const Text('သိမ်းမည်'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      await _loadLeaderboard();
    }
  }

  Future<void> _loadLeaderboard() async {
    if (_deviceId == null) return;
    final data = await ApiService.instance.fetchLeaderboard(
      scope: _monthly ? 'monthly' : 'all',
      deviceId: _deviceId,
      limit: 100,
    );
    if (mounted) {
      setState(() {
        _entries = data.leaderboard;
        _myRank = data.myRank;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Leaderboard',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            if (_userName != null)
              Text('$_userName',
                  style: const TextStyle(fontSize: 10, color: AppColors.slate400)),
          ],
        ),
        actions: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('All Time')),
              ButtonSegment(value: true, label: Text('Monthly')),
            ],
            selected: {_monthly},
            onSelectionChanged: (set) {
              setState(() {
                _monthly = set.first;
                _loading = true;
              });
              _loadLeaderboard();
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _loadLeaderboard,
            icon: const Icon(Icons.refresh, size: 18),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadLeaderboard,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_myRank != null) _MyRankCard(entry: _myRank!),
                  const SizedBox(height: 16),
                  ...List.generate(_entries.length, (i) {
                    final entry = _entries[i];
                    return _RankTile(entry: entry, index: i);
                  }),
                ],
              ),
            ),
    );
  }
}

class _MyRankCard extends StatelessWidget {
  final LeaderboardEntry entry;
  const _MyRankCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.amber, AppColors.brand]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x20000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('#${entry.rank}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  )),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    )),
                const Text('သင့်အဆင့်',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.star, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text('${entry.points}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RankTile extends StatelessWidget {
  final LeaderboardEntry entry;
  final int index;
  const _RankTile({required this.entry, required this.index});

  @override
  Widget build(BuildContext context) {
    final isTop3 = entry.rank <= 3;
    final rankColor = entry.rank == 1
        ? AppColors.amber
        : entry.rank == 2
            ? AppColors.slate400
            : entry.rank == 3
                ? AppColors.amber
                : AppColors.slate500;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: UI.card(
        color: isTop3 ? AppColors.amberLight : null,
        border: isTop3 ? AppColors.amber : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text('#${entry.rank}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: rankColor,
                )),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.userName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isTop3 ? AppColors.amber : AppColors.slate100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.star,
                    size: 14,
                    color: isTop3 ? Colors.white : AppColors.slate500),
                const SizedBox(width: 4),
                Text('${entry.points}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isTop3 ? Colors.white : AppColors.slate700,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
