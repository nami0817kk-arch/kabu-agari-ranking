import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/quick_access_destinations.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';

/// どのメインタブ(ホーム/スカッド/戦術/順位表)からでも、ホーム画面の
/// 「クラブ運営」グリッドにある管理画面へ直接ジャンプできるドロワー。
/// タブを一度ホームへ戻さなくても主要機能へアクセスできるようにする。
class QuickAccessDrawer extends StatelessWidget {
  const QuickAccessDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final clubName = gameState.save?.clubName ?? 'サッカー経営マネージャー';
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(clubName,
                    style: Theme.of(context).textTheme.titleLarge),
              ),
            ),
            for (final dest in quickAccessDestinations)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: dest.color,
                  child: Icon(dest.icon, color: Colors.white, size: 20),
                ),
                title: Text(dest.label),
                onTap: () {
                  FeedbackService.tap();
                  Navigator.of(context).pop();
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: dest.builder));
                },
              ),
          ],
        ),
      ),
    );
  }
}
