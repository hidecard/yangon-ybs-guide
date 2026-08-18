import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/nav.dart';
import '../widgets/route_badge.dart';

class RoutesPage extends StatefulWidget {
  const RoutesPage({super.key});
  @override
  State<RoutesPage> createState() => _RoutesPageState();
}

class _RoutesPageState extends State<RoutesPage> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final term = _search.toLowerCase().trim();

    final stopInfo = <String, BusStop>{};
    for (final s in state.stops) {
      stopInfo.putIfAbsent(s.nameMm, () => s);
    }

    var filtered = state.routes.where((r) {
      if (term.isEmpty) return true;
      final start = r.stops.isNotEmpty ? r.stops.first : '';
      final end = r.stops.isNotEmpty ? r.stops.last : '';
      final startInfo = stopInfo[start];
      final endInfo = stopInfo[end];
      bool has(String? v) => (v ?? '').toLowerCase().contains(term);
      return has(r.id) ||
          has(r.operator) ||
          has(start) ||
          has(end) ||
          has(startInfo?.townshipMm) ||
          has(endInfo?.townshipMm) ||
          has(startInfo?.nameEn) ||
          has(endInfo?.nameEn);
    }).toList();

    filtered.sort((a, b) {
      final af = state.isFavRoute(a.id);
      final bf = state.isFavRoute(b.id);
      if (af && !bf) return -1;
      if (!af && bf) return 1;
      final an = int.tryParse(a.id.replaceAll(RegExp(r'\D'), '')) ?? 999;
      final bn = int.tryParse(b.id.replaceAll(RegExp(r'\D'), '')) ?? 999;
      return an.compareTo(bn);
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: const InputDecoration(
              hintText: 'ကားလိုင်းနံပါတ် သို့မဟုတ် မြို့နယ်ဖြင့်ရှာရန်...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: filtered.length,
            itemBuilder: (_, i) => _routeCard(context, state, filtered[i]),
          ),
        ),
      ],
    );
  }

  Widget _routeCard(BuildContext context, AppState state, BusRoute r) {
    final isFav = state.isFavRoute(r.id);
    final start = r.stops.isNotEmpty ? r.stops.first : '—';
    final end = r.stops.isNotEmpty ? r.stops.last : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: UI.card(),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Nav.openRoute(context, r),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  RouteBadge(routeId: r.id, color: r.color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'YBS Route',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.slate400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if ((r.operator ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Pill(r.operator!, icon: Icons.credit_card),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => state.toggleFavRoute(r.id),
                    icon: Icon(
                      isFav ? Icons.star : Icons.star_border,
                      color: isFav ? AppColors.amber : AppColors.slate300,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _stopLine(AppColors.slate300, start),
              const SizedBox(height: 8),
              _stopLine(AppColors.brand, end),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${r.stops.length} Stops',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.slate400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'View Detail',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.brand,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: AppColors.brand,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stopLine(Color dot, String text) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
