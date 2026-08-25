import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/game_state.dart';

/// シーズンごとに確定した個人タイトル(得点王・年間MVP)の履歴を表示する画面。
class AwardsScreen extends StatelessWidget {
  const AwardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final awards = gameState.seasonAwards;

    return Scaffold(
      appBar: AppBar(title: const Text('個人タイトル')),
      body: awards.isEmpty
          ? const Center(child: Text('まだ表彰記録がありません(シーズン終了時に確定します)'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: awards.length,
              itemBuilder: (context, i) {
                final a = awards[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('シーズン${a.season}', style: Theme.of(context).textTheme.titleMedium),
                        const Divider(height: 20),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.sports_soccer, color: Colors.green),
                          title: const Text('得点王'),
                          subtitle: a.topScorerName == null
                              ? const Text('該当者なし')
                              : Text('${a.topScorerName}（${a.topScorerTeamName}） - ${a.topScorerGoals}得点'),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.emoji_events, color: Colors.amber),
                          title: const Text('年間MVP'),
                          subtitle: a.mvpName == null
                              ? const Text('該当者なし')
                              : Text('${a.mvpName}（${a.mvpTeamName}）'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
