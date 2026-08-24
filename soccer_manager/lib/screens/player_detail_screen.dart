import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../state/game_state.dart';
import '../widgets/stat_bar.dart';

class PlayerDetailScreen extends StatelessWidget {
  final String playerId;

  const PlayerDetailScreen({super.key, required this.playerId});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final p = gameState.userTeam.players.firstWhere((pl) => pl.id == playerId);

    return Scaffold(
      appBar: AppBar(title: Text(p.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${p.position.label} ・ ${p.age}歳', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Text('総合力: ${p.overall}', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          StatBar(label: '攻撃', value: p.attack),
          StatBar(label: '守備', value: p.defense),
          StatBar(label: '技術', value: p.technique),
          StatBar(label: 'スタミナ', value: p.stamina),
          const Divider(height: 32),
          StatBar(label: '潜在能力', value: p.potential, color: Colors.purple),
          StatBar(label: '疲労', value: p.fatigue, max: 100, color: Colors.redAccent),
          StatBar(label: '士気', value: p.morale, max: 100, color: Colors.blueAccent),
        ],
      ),
    );
  }
}
