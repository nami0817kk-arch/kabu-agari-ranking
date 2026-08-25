import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/attributes.dart';
import '../models/player.dart';
import '../state/game_state.dart';
import '../widgets/stat_bar.dart';

class PlayerDetailScreen extends StatelessWidget {
  final String playerId;

  const PlayerDetailScreen({super.key, required this.playerId});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final team = gameState.userTeam;
    final p = team.players.firstWhere((pl) => pl.id == playerId);
    final isStarting = team.startingXI.contains(p.id);
    final sellPrice = (p.marketValue * 0.7).round();
    final renewalCost = gameState.renewalCostFor(p.id);

    final categories = [
      AttributeCategory.technical,
      AttributeCategory.mental,
      AttributeCategory.physical,
      if (p.position == Position.gk) AttributeCategory.goalkeeping,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(p.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${p.position.label} ・ ${p.age}歳', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (isStarting)
            Chip(label: const Text('スタメン'), backgroundColor: Theme.of(context).colorScheme.primaryContainer),
          if (p.isInjured)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '負傷中（あと${p.injuryWeeks}週は出場不可）',
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),
          const SizedBox(height: 16),
          Text('総合力: ${p.overall}', style: Theme.of(context).textTheme.titleLarge),
          Text('市場価値: ${p.marketValue}万円'),
          Text('週俸: ${p.wage}万円 / 契約残り${p.contractWeeksRemaining}週'),
          const SizedBox(height: 16),
          StatBar(label: '攻撃', value: p.attack),
          StatBar(label: '守備', value: p.defense),
          StatBar(label: '技術', value: p.technique),
          StatBar(label: 'スタミナ', value: p.stamina),
          const Divider(height: 32),
          StatBar(label: '潜在能力', value: p.potential, color: Colors.purple),
          StatBar(label: '疲労', value: p.fatigue, max: 100, color: Colors.redAccent),
          StatBar(label: '士気', value: p.morale, max: 100, color: Colors.blueAccent),
          const Divider(height: 32),
          Text('詳細能力値', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          for (final category in categories)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text(category.label),
                initiallyExpanded: false,
                children: [
                  for (final key in category.keys)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: StatBar(label: AttributeKeys.labelOf(key), value: p.attributeValue(key)),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: gameState.save!.budget < renewalCost ? null : () => _renew(context),
            child: Text('契約更新する（$renewalCost万円 / +40週）'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: team.players.length <= minSquadSize ? null : () => _confirmSell(context, sellPrice),
            child: Text('放出する（$sellPrice万円）'),
          ),
        ],
      ),
    );
  }

  Future<void> _renew(BuildContext context) async {
    final gameState = context.read<GameState>();
    final ok = await gameState.renewContract(playerId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? '契約を更新しました' : '契約を更新できませんでした')),
      );
    }
  }

  void _confirmSell(BuildContext context, int sellPrice) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('この選手を放出しますか？'),
        content: Text('$sellPrice万円を獲得しますが、元には戻せません。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final gameState = context.read<GameState>();
              final ok = await gameState.sellPlayer(playerId);
              if (context.mounted && ok) {
                Navigator.pop(context);
              }
            },
            child: const Text('放出する'),
          ),
        ],
      ),
    );
  }
}
