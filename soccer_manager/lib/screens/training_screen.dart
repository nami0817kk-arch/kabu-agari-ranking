import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../models/training_focus.dart';
import '../state/game_state.dart';

class TrainingScreen extends StatelessWidget {
  const TrainingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final team = gameState.userTeam;

    return Scaffold(
      appBar: AppBar(title: const Text('トレーニング')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('チーム既定方針', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('個別方針を設定していない選手にはこの方針が適用される。'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: TrainingFocus.values
                .map(
                  (focus) => ChoiceChip(
                    label: Text(focus.label),
                    selected: team.defaultTrainingFocus == focus,
                    onSelected: (_) => context.read<GameState>().setTeamTrainingFocus(focus),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _runTraining(context),
              child: const Text('今週のトレーニングを実施'),
            ),
          ),
          const Divider(height: 32),
          Text('個別方針', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final p in team.players)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(p.name),
                subtitle: Text('${p.position.label} / 総合 ${p.overall}'),
                trailing: DropdownButton<TrainingFocus?>(
                  value: p.individualFocus,
                  hint: const Text('既定に従う'),
                  items: [
                    const DropdownMenuItem<TrainingFocus?>(value: null, child: Text('既定に従う')),
                    ...TrainingFocus.values.map(
                      (f) => DropdownMenuItem<TrainingFocus?>(value: f, child: Text(f.label)),
                    ),
                  ],
                  onChanged: (focus) => context.read<GameState>().setPlayerTrainingFocus(p.id, focus),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _runTraining(BuildContext context) async {
    final gameState = context.read<GameState>();
    await gameState.runWeeklyTraining();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('トレーニングを実施しました')),
      );
    }
  }
}
