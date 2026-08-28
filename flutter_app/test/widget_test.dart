import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ybs_guide/config.dart';
import 'package:ybs_guide/main.dart';
import 'package:ybs_guide/pages/assistant_page.dart';
import 'package:ybs_guide/models.dart';
import 'package:ybs_guide/state/app_state.dart';
import 'package:ybs_guide/data/route_finder.dart';
import 'package:ybs_guide/pages/home_page.dart';
import 'package:ybs_guide/pages/routes_page.dart';
import 'package:ybs_guide/pages/find_route_page.dart';
import 'package:ybs_guide/data/train_repository.dart';
import 'package:ybs_guide/pages/train_pages.dart';
import 'package:ybs_guide/services/train_live_service.dart';

void main() {
  test('YBS New is hidden without breaking tab indices', () {
    expect(AppConfig.showYbsNew, isFalse);
    expect(AppConfig.routesTab, 2);
    expect(AppConfig.findRouteTab, 3);
    expect(AppConfig.favoritesTab, 4);
  });

  test('Stop search ignores spacing and supports fuzzy matching', () {
    expect(resolveStopName('  မြေနီ ကုန်း ', ['မြေနီကုန်း']), 'မြေနီကုန်း');
    expect(resolveStopName('မြေနီကုံး', ['မြေနီကုန်း']), 'မြေနီကုန်း');
    expect(resolveStopName('မသိသောနေရာ', ['မြေနီကုန်း']), isNull);
  });

  test('Empty route line names receive a stable fallback label', () {
    const route = BusRoute(
      id: '42',
      color: Colors.blue,
      lineName: ' ',
      stops: ['A', 'B'],
      stopsDetailed: [],
    );
    expect(route.displayName, 'YBS 42');
  });

  testWidgets('Assistant composer remains visible', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const MaterialApp(home: Scaffold(body: AssistantPage())),
      ),
    );
    expect(find.byKey(const ValueKey('assistant-composer')), findsOneWidget);
    expect(find.byKey(const ValueKey('assistant-send')), findsOneWidget);
    expect(find.text('မေးမြန်းလိုသည်များကို ရိုက်ထည့်ပါ...'), findsOneWidget);
  });

  testWidgets('App uses the original light theme only', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(create: (_) => AppState(), child: const YbsApp()),
    );
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);
    expect(app.darkTheme, isNull);
  });

  testWidgets('Home quick actions open pages without leaving the app', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const MaterialApp(home: Scaffold(body: HomePage())),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Assistant'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('assistant-composer')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('ကားလိုင်းများ'));
    await tester.pumpAndSettle();
    expect(find.byType(RoutesPage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('လမ်းကြောင်း ရှာရန်'));
    await tester.pumpAndSettle();
    expect(find.byType(FindRoutePage), findsOneWidget);
  });

  test('Train JSON loads routes, stations, and timetables', () async {
    await TrainDataRepository.instance.load();
    expect(TrainDataRepository.instance.routes, isNotEmpty);
    expect(TrainDataRepository.instance.stations, isNotEmpty);
    expect(
      TrainDataRepository.instance.routes.first.stationSchedules,
      isNotEmpty,
    );
    expect(
      TrainDataRepository.instance.stations.first.latitude,
      inInclusiveRange(-90, 90),
    );
  });

  testWidgets('Transport chooser presents Bus and Train modes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: TransportModeChooser(busPage: const RootShell())),
    );
    expect(find.text('Bus'), findsOneWidget);
    expect(find.text('Train'), findsOneWidget);
  });

  test('Live train decoder preserves source coordinates', () {
    final position = TrainLivePosition.fromJson({
      'route_slug': '141-up',
      'route_title': '၁၄၁ (အဆန်)',
      'latitude': '16.781076',
      'longitude': '96.161943',
      'way': {'text': 'အဆန်'},
      'train_model': {'text': 'AAR'},
    });
    expect(position.routeSlug, '141-up');
    expect(position.latitude, 16.781076);
    expect(position.longitude, 96.161943);
  });

  testWidgets('App boots to splash', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState()..init(),
        child: const YbsApp(),
      ),
    );
    await tester.pump();
    expect(find.text('YBS AI'), findsWidgets);
  });
}
