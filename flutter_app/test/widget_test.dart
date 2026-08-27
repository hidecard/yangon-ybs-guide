import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ybs_guide/config.dart';
import 'package:ybs_guide/main.dart';
import 'package:ybs_guide/state/app_state.dart';

void main() {
  test('YBS New is hidden without breaking tab indices', () {
    expect(AppConfig.showYbsNew, isFalse);
    expect(AppConfig.routesTab, 2);
    expect(AppConfig.findRouteTab, 3);
    expect(AppConfig.favoritesTab, 4);
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
