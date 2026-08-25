import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/scouting_engine.dart';
import '../models/player.dart';
import '../state/game_state.dart';

class YouthScreen extends StatelessWidget {
  const YouthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final save = gameState.save!;
    final prospects = save.youthProspects;
    final squadFull = gameState.userTeam.players.length >= maxSquadSize;
    final canScout =
        save.budget >= ScoutingEngine.scoutCost && prospects.length < ScoutingEngine.maxProspects;

    return Scaffold(
      appBar: AppBar(title: const Text('ユース・スカウト')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('資金: ${save.budget}万円'),
                FilledButton(
                  onPressed: canScout ? () => _scout(context) : null,
                  child: const Text('スカウトする（${ScoutingEngine.scoutCost}万円）'),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'シーズン終了時にはアカデミーから無償の昇格候補も加わる。',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ),
          const Divider(height: 24),
          Expanded(
            child: prospects.isEmpty
                ? const Center(child: Text('現在、昇格候補はいません'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: prospects.length,
                    itemBuilder: (context, i) {
                      final p = prospects[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(child: Text(p.position.label)),
                          title: Text(p.name),
                          subtitle: Text('${p.age}歳 / 総合 ${p.overall} / 潜在 ${p.potential}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close),
                                tooltip: '解雇',
                                onPressed: () =>
                                    context.read<GameState>().releaseYouthProspect(p.id),
                              ),
                              FilledButton(
                                onPressed: squadFull ? null : () => _promote(context, p.id, p.name),
                                child: const Text('昇格'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _scout(BuildContext context) async {
    final ok = await context.read<GameState>().scoutProspect();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? '新しい有望株を発見しました' : 'スカウトできませんでした')),
      );
    }
  }

  Future<void> _promote(BuildContext context, String playerId, String name) async {
    final ok = await context.read<GameState>().promoteYouthProspect(playerId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? '$nameをトップチームに昇格させました' : '昇格できませんでした')),
      );
    }
  }
}
