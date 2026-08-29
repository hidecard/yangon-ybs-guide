import 'package:flutter/material.dart';
import '../models.dart';
import '../pages/route_detail_page.dart';
import '../pages/stop_detail_page.dart';
import '../pages/route_plan_detail_page.dart';

/// Central navigation helpers so any page can open detail screens.
class Nav {
  static void openRoute(BuildContext context, BusRoute route) {
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute(builder: (_) => RouteDetailPage(route: route)));
  }

  static void openStop(BuildContext context, BusStop stop) {
    Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute(builder: (_) => StopDetailPage(stop: stop)));
  }

  static void openRoutePlan(
    BuildContext context,
    List<PathStep> steps, {
    bool canSave = true,
  }) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => RoutePlanDetailPage(steps: steps, canSave: canSave),
      ),
    );
  }
}
