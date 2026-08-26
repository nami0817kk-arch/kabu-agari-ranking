import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soccer_manager/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('start screen shows save slot list', (WidgetTester tester) async {
    await tester.pumpWidget(const SoccerManagerApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('スキップ'));
    await tester.pumpAndSettle();

    expect(find.text('サッカー経営マネージャー'), findsOneWidget);
    expect(find.text('空きスロット'), findsWidgets);
    expect(find.text('新規クラブ作成'), findsWidgets);
  });

  testWidgets('creating a club navigates to the home dashboard',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SoccerManagerApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('スキップ'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('新規クラブ作成').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'テストFC');
    await tester.tap(find.text('創設する'));
    await tester.pumpAndSettle();

    expect(find.text('テストFC'), findsWidgets);
    expect(find.text('スカッド'), findsOneWidget);
  });

  testWidgets(
      'pressing back while on a non-home tab returns to the home tab '
      'instead of exiting to the title screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SoccerManagerApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('スキップ'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('新規クラブ作成').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'テストFC');
    await tester.tap(find.text('創設する'));
    await tester.pumpAndSettle();

    // ホームタブから「スカッド」タブへ切り替える(ルートは積まれない)。
    await tester.tap(find.text('スカッド'));
    await tester.pumpAndSettle();
    expect(find.text('テストFC'), findsNothing);

    // ブラウザ/端末の戻る操作を発火する。
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // タイトル画面まで戻るのではなく、ホームタブに戻るだけであるべき。
    expect(find.text('新規クラブ作成'), findsNothing);
    expect(find.text('テストFC'), findsWidgets);

    // ホームタブの状態でもう一度戻る操作をすると、今度はタイトル画面へ戻る。
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('新規クラブ作成'), findsWidgets);
  });
}
