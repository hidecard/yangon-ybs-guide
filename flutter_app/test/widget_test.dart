import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ybs_guide/main.dart';
import 'package:ybs_guide/state/app_state.dart';

void main() {
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
