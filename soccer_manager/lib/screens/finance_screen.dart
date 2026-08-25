import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../state/game_state.dart';

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final save = gameState.save!;
    final team = gameState.userTeam;
    final income = gameState.weeklyIncomeFor(team.id);
    final wageBill = gameState.weeklyWageBill;
    final net = income - wageBill;

    final sortedByExpiry = [...team.players]
      ..sort((a, b) => a.contractWeeksRemaining.compareTo(b.contractWeeksRemaining));

    return Scaffold(
      appBar: AppBar(title: const Text('クラブ経営')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('資金: ${save.budget}万円', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('週間収入: +$income万円'),
                  Text('週間人件費: -$wageBill万円'),
                  Text(
                    '週間収支: ${net >= 0 ? '+' : ''}$net万円',
                    style: TextStyle(
                      color: net >= 0 ? Colors.green : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('契約状況（残り週数が少ない順）', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final p in sortedByExpiry)
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                title: Text(p.name),
                subtitle: Text('${p.position.label} / 週俸 ${p.wage}万円'),
                trailing: Text(
                  '残り${p.contractWeeksRemaining}週',
                  style: TextStyle(
                    color: p.contractWeeksRemaining <= 4 ? Colors.redAccent : null,
                    fontWeight: p.contractWeeksRemaining <= 4 ? FontWeight.bold : null,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
