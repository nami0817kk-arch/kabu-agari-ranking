import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../state/game_state.dart';
import '../widgets/position_colors.dart';
import '../widgets/position_filter_bar.dart';

class YouthScreen extends StatefulWidget {
  const YouthScreen({super.key});

  @override
  State<YouthScreen> createState() => _YouthScreenState();
}

class _YouthScreenState extends State<YouthScreen> {
  PositionGroup? _filter;

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final save = gameState.save!;
    final prospects = save.youthProspects;
    final squadFull = gameState.userTeam.players.length >= maxSquadSize;
    final scoutCost = gameState.scoutCost;
    final maxProspects = gameState.maxYouthProspects;
    final canScout = save.budget >= scoutCost && prospects.length < maxProspects;

    final candidates = gameState.scoutCandidates.where((p) => _filter == null || p.position.group == _filter).toList()
      ..sort((a, b) => b.overall.compareTo(a.overall));

    return Scaffold(
      appBar: AppBar(title: const Text('ユース・スカウト')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('資金: ${save.budget}万円', style: Theme.of(context).textTheme.titleMedium),
                Text('昇格枠: ${prospects.length}/$maxProspects'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'スカウト網（獲得費用: $scoutCost万円/人・${candidates.length}人閲覧可）',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: '候補を更新する',
                  onPressed: () => gameState.refreshScoutCandidates(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: PositionFilterBar(
              value: _filter,
              onChanged: (v) => setState(() => _filter = v),
            ),
          ),
          const SizedBox(height: 8),
          if (candidates.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('該当する候補選手はいません', style: TextStyle(color: Colors.grey)),
            )
          else
            for (final p in candidates)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Card(
                  child: ListTile(
                    leading: PositionAvatar(position: p.position),
                    title: Text(p.name),
                    subtitle: Text('${p.age}歳 / ${p.position.label} / 総合 ${p.overall} / 潜在 ${p.potential}'),
                    trailing: FilledButton(
                      onPressed: canScout ? () => _scout(context, p.id) : null,
                      child: const Text('獲得'),
                    ),
                  ),
                ),
              ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('昇格候補', style: Theme.of(context).textTheme.titleMedium),
          ),
          const SizedBox(height: 8),
          if (prospects.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('現在、昇格候補はいません'),
            )
          else
            for (final p in prospects)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Card(
                  child: ListTile(
                    leading: PositionAvatar(position: p.position),
                    title: Text(p.name),
                    subtitle: Text('${p.age}歳 / 総合 ${p.overall} / 潜在 ${p.potential}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: '解雇',
                          onPressed: () => context.read<GameState>().releaseYouthProspect(p.id),
                        ),
                        FilledButton(
                          onPressed: squadFull ? null : () => _promote(context, p.id, p.name),
                          child: const Text('昇格'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _scout(BuildContext context, String candidateId) async {
    final ok = await context.read<GameState>().scoutProspect(candidateId);
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
