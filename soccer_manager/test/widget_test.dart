import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('start screen shows club creation form', (WidgetTester tester) async {
    await tester.pumpWidget(const SoccerManagerApp());
    await tester.pumpAndSettle();

    expect(find.text('サッカー経営マネージャー'), findsOneWidget);
    expect(find.text('クラブ創設'), findsOneWidget);
  });

  testWidgets('creating a club navigates to the home dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const SoccerManagerApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'テストFC');
    await tester.tap(find.text('クラブ創設'));
    await tester.pumpAndSettle();

    expect(find.text('テストFC'), findsWidgets);
    expect(find.text('スカッド'), findsOneWidget);
  });
}
