import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/training_engine.dart';
import '../state/game_state.dart';

class TrainingScreen extends StatelessWidget {
  const TrainingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('トレーニング')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: TrainingFocus.values
            .map(
              (focus) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(focus.label, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(focus.description),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: () => _apply(context, focus),
                          child: const Text('実施'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _apply(BuildContext context, TrainingFocus focus) async {
    final gameState = context.read<GameState>();
    await gameState.applyTraining(focus);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${focus.label}を実施しました')),
      );
      Navigator.of(context).pop();
    }
  }
}
