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

class _LeaderboardPageState extends State<LeaderboardPage>
    with SingleTickerProviderStateMixin {
  final DeviceService _deviceService = DeviceService();
  late TabController _tabController;

  List<LeaderboardEntry> _entries = [];
  LeaderboardEntry? _myRank;
  bool _loading = true;
  bool _monthly = false;
  String? _deviceId;
  String? _userName;

  List<RewardItem> _rewards = [];
  bool _rewardsLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    await _loadRewards();
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
            const Text(
                'သတင်းတင်တိုင်း Point ရရှိ၍ Leaderboard မှာ ပြိုင်ဆိုင်မည့် သင့်အမည်ကို ဖြည့်ပါ။'),
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

  Future<void> _loadRewards() async {
    final rewards = await ApiService.instance.fetchRewards();
    if (mounted) {
      setState(() {
        _rewards = rewards;
        _rewardsLoading = false;
      });
    }
  }

  Future<void> _onRedeem(RewardItem reward) async {
    if (_deviceId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.card_giftcard, color: AppColors.rose, size: 40),
        title: Text('${reward.icon} ${reward.title}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reward.description.isNotEmpty ? reward.description : ''),
            const SizedBox(height: 12),
            Text(
              '${reward.cost} Points သုံးရပါမည်။',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (_myRank != null) ...[
              const SizedBox(height: 8),
              Text(
                'သင့်လက်ရှိ Point : ${_myRank!.points}',
                style: TextStyle(color: AppColors.slate600),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ပြန်လည်စဉ်းအကြံပြုချက်'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ဆုလဲမည်'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final contactController = TextEditingController();
    final contactResult = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.contact_mail, color: AppColors.blue, size: 40),
        title: const Text('ဆုလက်ဆောင် ပို့ရန် အချက်အလက်'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ဖုန်းနံပါတ် သို့မဟုတ် Telegram Username ဖြည့်ပါ။'),
            const SizedBox(height: 12),
            TextField(
              controller: contactController,
              decoration: const InputDecoration(
                hintText: 'ဥပမာ - 0912345678 / @username',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('ပယ်ဖျက်မည်'),
          ),
          FilledButton(
            onPressed: () {
              final val = contactController.text.trim();
              if (val.isEmpty) return;
              Navigator.pop(context, val);
            },
            child: const Text('တင်သွင်းမည်'),
          ),
        ],
      ),
    );
    if (contactResult == null || contactResult.isEmpty) return;

    final result = await ApiService.instance.redeemReward(
      deviceId: _deviceId!,
      rewardId: reward.id,
      claimContact: contactResult,
    );

    if (!mounted) return;
    if (result.ok) {
      setState(() {
        if (_myRank != null) {
          _myRank = LeaderboardEntry(
            rank: _myRank!.rank,
            userName: _myRank!.userName,
            points: result.newTotal,
          );
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              ' ${result.rewardTitle} ကို အောင်မြင်စွာ ဆုလဲလိုက်ပြီပြီ! (${result.pointsSpent} Points)'),
          backgroundColor: AppColors.emerald,
        ),
      );
      await _loadLeaderboard();
      await _loadRewards();
    } else {
      final err = result.ok
          ? 'Redeem failed'
          : (result.pointsSpent > 0
              ? 'Not enough points'
              : 'Redeem failed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.rose),
      );
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Leaderboard'),
            Tab(text: 'Rewards'),
          ],
        ),
        actions: [
          if (_tabController.index == 0)
            IconButton(
              onPressed: _loadLeaderboard,
              icon: const Icon(Icons.refresh, size: 18),
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLeaderboardTab(),
          _buildRewardsTab(),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTab() {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadLeaderboard,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_myRank != null) _MyRankCard(entry: _myRank!),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('အဆင့်',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate500)),
                    const Spacer(),
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
                  ],
                ),
                const SizedBox(height: 8),
                ...List.generate(_entries.length, (i) {
                  final entry = _entries[i];
                  return _RankTile(entry: entry, index: i);
                }),
              ],
            ),
          );
  }

  Widget _buildRewardsTab() {
    return _rewardsLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadRewards,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_myRank != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.amberLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.amber),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, color: AppColors.amber, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'သင့်လက်ရှိ Point : ',
                          style: TextStyle(color: AppColors.slate700),
                        ),
                        Text(
                          '${_myRank!.points}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                if (_rewards.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Column(
                      children: [
                        Icon(Icons.card_giftcard_outlined, size: 40, color: AppColors.slate300),
                        SizedBox(height: 12),
                        Text(
                          'ပြီးခဲ့ပြီ ဆုများ မရှိသေးပါ။',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.slate400, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ...List.generate(_rewards.length, (i) {
                  final reward = _rewards[i];
                  return _RewardCard(
                    reward: reward,
                    myPoints: _myRank?.points ?? 0,
                    onRedeem: () => _onRedeem(reward),
                  );
                }),
              ],
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

class _RewardCard extends StatelessWidget {
  final RewardItem reward;
  final int myPoints;
  final VoidCallback onRedeem;
  const _RewardCard({
    required this.reward,
    required this.myPoints,
    required this.onRedeem,
  });

  @override
  Widget build(BuildContext context) {
    final canAfford = myPoints >= reward.cost;
    final outOfStock = reward.stock == 0;
    final isDisabled = !canAfford || outOfStock || !reward.isActive;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: UI.card(
        color: isDisabled ? AppColors.slate100 : null,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDisabled ? AppColors.slate200 : AppColors.amberLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                reward.icon,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDisabled ? AppColors.slate400 : AppColors.text,
                  ),
                ),
                if (reward.description.isNotEmpty)
                  Text(
                    reward.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.slate500,
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.star, size: 14, color: AppColors.amber),
                    const SizedBox(width: 4),
                    Text(
                      '${reward.cost} Points',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDisabled ? AppColors.slate400 : AppColors.amber,
                      ),
                    ),
                    if (reward.stock > 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(${reward.stock} left)',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.slate400,
                        ),
                      ),
                    ] else if (reward.stock == 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Out of stock',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.rose,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: isDisabled ? null : onRedeem,
            style: FilledButton.styleFrom(
              backgroundColor: isDisabled ? AppColors.slate300 : AppColors.brand,
              foregroundColor: Colors.white,
            ),
            child: const Text('ဆုလဲမည်', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
