import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ybs_guide/config.dart';
import 'package:ybs_guide/main.dart';
import 'package:ybs_guide/pages/assistant_page.dart';
import 'package:ybs_guide/models.dart';
import 'package:ybs_guide/state/app_state.dart';
import 'package:ybs_guide/data/route_finder.dart';

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
