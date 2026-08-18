import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../models.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';
import '../util/nav.dart';
import '../widgets/bus_updates_feed.dart';
import '../widgets/modals.dart';

class YbsNewPage extends StatefulWidget {
  const YbsNewPage({super.key});
  @override
  State<YbsNewPage> createState() => _YbsNewPageState();
}

class _YbsNewPageState extends State<YbsNewPage> {
  int _refreshKey = 0;

  void _reloadFeed() => setState(() => _refreshKey++);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YBS New',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'အသုံးပြုသူများမှ မျှဝေထားသော ကားလိုင်း အချက်အလက်များ',
                      style: TextStyle(fontSize: 12, color: AppColors.slate500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          BusUpdatesFeed(
            key: ValueKey(_refreshKey),
            limit: 50,
            title: 'စူပါမက် အချက်အလက်',
            onRouteTap: (routeId) {
              final r = state.repo.routeById(routeId);
              if (r != null) Nav.openRoute(context, r);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'ybs_new_post',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('အချက်အလက် မျှဝေမည်'),
        onPressed: () => _openPostSheet(context, state),
      ),
    );
  }

  void _openPostSheet(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _PostUpdateSheet(routes: state.routes, onPosted: _reloadFeed),
    );
  }
}

class _PostUpdateSheet extends StatefulWidget {
  final List<BusRoute> routes;
  final VoidCallback onPosted;
  const _PostUpdateSheet({required this.routes, required this.onPosted});

  @override
  State<_PostUpdateSheet> createState() => _PostUpdateSheetState();
}

class _PostUpdateSheetState extends State<_PostUpdateSheet> {
  BusRoute? _route;
  BusUpdateType _type = BusUpdateType.started;
  final _stop = TextEditingController();
  final _note = TextEditingController();
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: const [
                Icon(Icons.campaign, color: AppColors.amber),
                SizedBox(width: 8),
                Text(
                  'အချက်အလက် မျှဝေရန်',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('ကားလိုင်း ရွေးချယ်ပါ', style: uiLabel),
            const SizedBox(height: 8),
            DropdownButtonFormField<BusRoute>(
              initialValue: _route,
              decoration: const InputDecoration(hintText: 'ကားလိုင်း'),
              items: widget.routes.map((r) {
                return DropdownMenuItem(
                  value: r,
                  child: Text('YBS ${r.id} · ${r.displayName}'),
                );
              }).toList(),
              onChanged: (v) => setState(() => _route = v),
            ),
            const SizedBox(height: 14),
            const Text('အချက်အလက် အမျိုးအစား', style: uiLabel),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: BusUpdateType.values.map((t) {
                final meta = updateTypeMeta[t]!;
                final active = _type == t;
                return ChoiceChip(
                  avatar: CircleAvatar(radius: 4, backgroundColor: meta.dot),
                  label: Text(meta.label),
                  selected: active,
                  selectedColor: meta.bg,
                  labelStyle: TextStyle(
                    color: active ? meta.color : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  onSelected: (_) => setState(() => _type = t),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _stop,
              decoration: const InputDecoration(
                labelText: 'မှတ်တိုင် (ရှိလျှင်)',
                hintText: 'ဥပမာ - ဆူးလေမှတ်တိုင်',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'မှတ်ချက်',
                hintText: 'အသေးစိတ် အချက်အလက်...',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _submitting || _route == null ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send),
                label: Text(_submitting ? 'ပို့နေပါသည်...' : 'မျှဝေမည်'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final updateId = await ApiService.instance.postBusUpdate(
      BusUpdate(
        routeId: _route!.id,
        type: _type,
        stop: _stop.text.trim().isEmpty ? null : _stop.text.trim(),
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      ),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (updateId != null) {
      widget.onPosted();
      if (mounted) {
        const msg = 'အချက်အလက် မျှဝေပြီးပါပြီ။';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('အမှားရှိပါသည်။ နောက်မှ ထပ်ကြိုးစားပါ။'),
          ),
        );
      }
    }
  }
}
