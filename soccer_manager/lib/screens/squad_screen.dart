import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../state/game_state.dart';
import 'player_detail_screen.dart';

class SquadScreen extends StatelessWidget {
  const SquadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final players = [...gameState.userTeam.players]
      ..sort((a, b) {
        final c = a.position.index.compareTo(b.position.index);
        if (c != 0) return c;
        return b.overall.compareTo(a.overall);
      });

    return Scaffold(
      appBar: AppBar(title: const Text('スカッド')),
      body: ListView.builder(
        itemCount: players.length,
        itemBuilder: (context, i) {
          final p = players[i];
          final isStarting = gameState.userTeam.startingXI.contains(p.id);
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: isStarting ? Theme.of(context).colorScheme.primaryContainer : null,
              child: Text(p.position.label),
            ),
            title: Text(p.name),
            subtitle: Text(
              p.isInjured ? '負傷中（あと${p.injuryWeeks}週）' : '${p.age}歳 / 総合 ${p.overall}',
              style: p.isInjured ? const TextStyle(color: Colors.redAccent) : null,
            ),
            trailing: p.fatigue > 70
                ? const Icon(Icons.battery_alert, color: Colors.orange)
                : Text('${p.overall}', style: Theme.of(context).textTheme.titleMedium),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PlayerDetailScreen(playerId: p.id)),
            ),
          );
        },
      ),
    );
  }
}
