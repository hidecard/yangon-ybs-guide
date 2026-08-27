import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/nav.dart';
import '../widgets/route_badge.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final favRoutes = state.routes
        .where((r) => state.isFavRoute(r.id))
        .toList();
    final favStops = state.stops.where((s) => state.isFavStop(s.id)).toList();
    final trips = state.savedTrips;
    final hasAny =
        trips.isNotEmpty || favStops.isNotEmpty || favRoutes.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'အကြိုက်များ',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (!hasAny)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Column(
              children: [
                Icon(Icons.star_border, size: 40, color: AppColors.slate300),
                SizedBox(height: 12),
                Text(
                  'မှတ်တိုင်၊ လိုင်း သို့မဟုတ် ခရီးစဉ်များကို သိမ်းဆည်းပြီး ဤနေရာမှ အမြန်ဖွင့်နိုင်ပါသည်။',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.slate400, fontSize: 13),
                ),
              ],
            ),
          ),
        if (trips.isNotEmpty) ...[
          const Text('သိမ်းဆည်းထားသော ခရီးစဉ်များ', style: UI.sectionTitle),
          const SizedBox(height: 8),
          ...trips.map((t) => _tripCard(context, state, t)),
          const SizedBox(height: 16),
        ],
        if (favStops.isNotEmpty) ...[
          const Text('အကြိုက်မှတ်တိုင်များ', style: UI.sectionTitle),
          const SizedBox(height: 8),
          ...favStops.map((s) => _stopCard(context, state, s)),
          const SizedBox(height: 16),
        ],
        if (favRoutes.isNotEmpty) ...[
          const Text('အကြိုက်လိုင်းများ', style: UI.sectionTitle),
          const SizedBox(height: 8),
          ...favRoutes.map((r) => _routeCard(context, state, r)),
        ],
      ],
    );
  }

  Widget _tripCard(BuildContext context, AppState state, FavoriteTrip trip) {
    final first = trip.steps.isNotEmpty ? trip.steps.first : null;
    final last = trip.steps.isNotEmpty ? trip.steps.last : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: UI.card(),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Nav.openRoutePlan(context, trip.steps, canSave: false),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (int i = 0; i < trip.steps.length; i++) ...[
                            RouteBadge(
                              routeId: trip.steps[i].route.id,
                              color: trip.steps[i].route.color,
                              small: true,
                            ),
                            if (i < trip.steps.length - 1)
                              const Icon(
                                Icons.chevron_right,
                                size: 14,
                                color: AppColors.slate300,
                              ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${first?.fromStop ?? ''} → ${last?.toStop ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => state.deleteTrip(trip.id),
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.slate400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stopCard(BuildContext context, AppState state, BusStop stop) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: UI.card(),
      child: ListTile(
        onTap: () => Nav.openStop(context, stop),
        leading: const Icon(Icons.location_on_outlined, color: AppColors.brand),
        title: Text(stop.nameMm, style: const TextStyle(fontSize: 14)),
        subtitle: Text(stop.townshipMm, style: const TextStyle(fontSize: 12)),
        trailing: IconButton(
          onPressed: () => state.toggleFavStop(stop.id),
          icon: const Icon(Icons.star, color: AppColors.amber),
        ),
      ),
    );
  }

  Widget _routeCard(BuildContext context, AppState state, BusRoute r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: UI.card(),
      child: ListTile(
        onTap: () => Nav.openRoute(context, r),
        leading: RouteBadge(routeId: r.id, color: r.color),
        title: Text(
          r.operator?.isNotEmpty == true ? r.operator! : r.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          r.displayName,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: IconButton(
          onPressed: () => state.toggleFavRoute(r.id),
          icon: const Icon(Icons.star, color: AppColors.amber),
        ),
      ),
    );
  }
}
