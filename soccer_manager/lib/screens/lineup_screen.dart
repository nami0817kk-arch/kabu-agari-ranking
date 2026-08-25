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

    final posOrder = Position.values.where((pos) => team.players.any((p) => p.position == pos)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('スタメン・戦術')),
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
            child: Column(
              children: [
                Row(
                  children: [
                    const SizedBox(width: 90, child: Text('プレッシング')),
                    Expanded(
                      child: Slider(
                        value: team.pressing.toDouble(),
                        min: 0,
                        max: 100,
                        divisions: 10,
                        label: '${team.pressing}',
                        onChanged: (v) => context.read<GameState>().setPressing(v.round()),
                      ),
                    ),
                    SizedBox(width: 32, child: Text('${team.pressing}')),
                  ],
                ),
                Row(
                  children: [
                    const SizedBox(width: 90, child: Text('ライン高さ')),
                    Expanded(
                      child: Slider(
                        value: team.lineHeight.toDouble(),
                        min: 0,
                        max: 100,
                        divisions: 10,
                        label: '${team.lineHeight}',
                        onChanged: (v) => context.read<GameState>().setLineHeight(v.round()),
                      ),
                    ),
                    SizedBox(width: 32, child: Text('${team.lineHeight}')),
                  ],
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'プレッシングは守備を高めるが疲労が増えやすい。ラインを上げると攻撃的になるが裏を突かれやすい。',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
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
                      '${pos.label} ${pos.fullLabel}（${_countInPosition(team.startingXI, team, pos)}/${formation.quotaFor(pos)}）',
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
        p.isInjured
            ? '負傷中（あと${p.injuryWeeks}週）'
            : '${p.age}歳 / 総合 ${p.overall}'
                '${p.secondaryPositions.isEmpty ? '' : ' / 対応: ${p.secondaryPositions.map((s) => s.label).join(', ')}'}',
        style: p.isInjured ? const TextStyle(color: Colors.redAccent) : null,
      ),
      trailing: Checkbox(
        value: isStarting,
        onChanged: canToggle ? (_) => context.read<GameState>().toggleStartingPlayer(playerId) : null,
      ),
    );
  }
}
