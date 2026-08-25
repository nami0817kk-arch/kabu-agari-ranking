import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../state/game_state.dart';

class TransferScreen extends StatelessWidget {
  const TransferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final save = gameState.save!;
    final squadFull = gameState.userTeam.players.length >= maxSquadSize;

    return Scaffold(
      appBar: AppBar(title: const Text('移籍市場')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('資金: ${save.budget}万円', style: Theme.of(context).textTheme.titleMedium),
                Text('スカッド: ${gameState.userTeam.players.length}/$maxSquadSize'),
              ],
            ),
          ),
          if (squadFull)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('スカッドが上限のため、獲得するには誰かを放出してください。', style: TextStyle(color: Colors.orange)),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: gameState.transferMarket.length,
              itemBuilder: (context, i) {
                final p = gameState.transferMarket[i];
                final canAfford = save.budget >= p.marketValue;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(child: Text(p.position.label)),
                    title: Text(p.name),
                    subtitle: Text('${p.age}歳 / 総合 ${p.overall} / 潜在 ${p.potential}'),
                    trailing: FilledButton(
                      onPressed: (!canAfford || squadFull) ? null : () => _buy(context, p),
                      child: Text('${p.marketValue}万'),
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

  Future<void> _buy(BuildContext context, Player player) async {
    final gameState = context.read<GameState>();
    final ok = await gameState.buyPlayer(player.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? '${player.name}を獲得しました' : '獲得できませんでした')),
      );
    }
  }
}
