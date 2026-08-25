import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/cup_engine.dart';
import '../models/cup.dart';
import '../models/team.dart';
import '../state/game_state.dart';
import 'match_screen.dart';

class CupScreen extends StatelessWidget {
  const CupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('カップ戦'),
          bottom: const TabBar(tabs: [Tab(text: '国内カップ'), Tab(text: '大陸カップ')]),
        ),
        body: const TabBarView(
          children: [
            _CupTab(type: CupType.domestic),
            _CupTab(type: CupType.continental),
          ],
        ),
      ),
    );
  }
}

class _CupTab extends StatelessWidget {
  final CupType type;
  const _CupTab({required this.type});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final cup = type == CupType.domestic ? gameState.domesticCup : gameState.continentalCup;

    if (cup == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            type == CupType.continental
                ? '前シーズンをリーグ2位以内で終えると、翌シーズンは大陸カップに出場できます。'
                : 'カップ戦の情報がありません。',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final userId = gameState.userTeam.id;
    final teams = gameState.allTeamsForCups;
    String nameOf(String id) => teams.firstWhere((t) => t.id == id, orElse: () => teams.first).name;
    final totalRounds = cup.rounds.length;
    final nextMatch = cup.nextUnplayedMatch;
    final userEliminated = cup.isEliminated(userId);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (cup.isComplete)
          Card(
            color: cup.championId == userId ? Theme.of(context).colorScheme.primaryContainer : null,
            child: ListTile(
              leading: const Icon(Icons.emoji_events),
              title: Text('優勝: ${nameOf(cup.championId!)}'),
            ),
          )
        else if (userEliminated)
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('自クラブは敗退しました'),
              subtitle: Text('他クラブの結果は引き続き更新されます'),
            ),
          ),
        if (nextMatch != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _playNext(context, type),
                child: const Text('次の試合を消化'),
              ),
            ),
          ),
        for (final round in cup.rounds) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(
              CupEngine.roundLabel(round.first.round, totalRounds),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (final m in round)
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                tileColor: (m.homeTeamId == userId || m.awayTeamId == userId)
                    ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.25)
                    : null,
                title: Text('${nameOf(m.homeTeamId)} vs ${nameOf(m.awayTeamId)}'),
                subtitle: m.penaltyWinnerId != null ? Text('PK戦: ${nameOf(m.penaltyWinnerId!)}が勝利') : null,
                trailing: m.result == null
                    ? const Text('未消化')
                    : Text(
                        '${m.result!.homeGoals} - ${m.result!.awayGoals}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _playNext(BuildContext context, CupType type) async {
    final gameState = context.read<GameState>();
    final userId = gameState.userTeam.id;
    final List<Team> teams = gameState.allTeamsForCups;
    final cup = type == CupType.domestic ? gameState.domesticCup : gameState.continentalCup;
    final match = cup?.nextUnplayedMatch;
    final isUserMatch = match != null && (match.homeTeamId == userId || match.awayTeamId == userId);
    final result = await gameState.playNextCupMatch(type);
    if (!context.mounted) return;
    if (result != null && isUserMatch) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MatchScreen(result: result, teams: teams, title: type.label)),
      );
    }
  }
}
