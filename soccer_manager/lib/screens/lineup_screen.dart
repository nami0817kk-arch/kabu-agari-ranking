import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/formation.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../state/game_state.dart';

class LineupScreen extends StatelessWidget {
  const LineupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final team = gameState.userTeam;
    final formation = team.formation;

    const posOrder = [Position.gk, Position.df, Position.mf, Position.fw];

    return Scaffold(
      appBar: AppBar(title: const Text('スタメン編成')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('フォーメーション: '),
                const SizedBox(width: 8),
                DropdownButton<Formation>(
                  value: formation,
                  items: Formation.values
                      .map((f) => DropdownMenuItem(value: f, child: Text(f.label)))
                      .toList(),
                  onChanged: (f) {
                    if (f != null) context.read<GameState>().setFormation(f);
                  },
                ),
                const Spacer(),
                Text('${team.startingXI.length}/11'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: () => context.read<GameState>().autoFillStartingXI(),
                child: const Text('自動編成'),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final pos in posOrder) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Text(
                      '${pos.label}（${_countInPosition(team.startingXI, team, pos)}/${formation.quotaFor(pos)}）',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  ...team.players.where((p) => p.position == pos).map(
                        (p) => _PlayerTile(playerId: p.id),
                      ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _countInPosition(List<String> startingXI, Team team, Position pos) {
    return startingXI
        .map((id) => team.players.firstWhere((p) => p.id == id))
        .where((p) => p.position == pos)
        .length;
  }
}

class _PlayerTile extends StatelessWidget {
  final String playerId;

  const _PlayerTile({required this.playerId});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final team = gameState.userTeam;
    final p = team.players.firstWhere((pl) => pl.id == playerId);
    final isStarting = team.startingXI.contains(playerId);
    final quota = team.formation.quotaFor(p.position);
    final currentInPosition = team.startingXI
        .map((id) => team.players.firstWhere((pl) => pl.id == id))
        .where((pl) => pl.position == p.position)
        .length;
    final quotaFull = currentInPosition >= quota;
    final canToggle = !p.isInjured && (isStarting || !quotaFull);

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
      trailing: Checkbox(
        value: isStarting,
        onChanged: canToggle ? (_) => context.read<GameState>().toggleStartingPlayer(playerId) : null,
      ),
    );
  }
}
