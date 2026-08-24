import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/league.dart';
import '../state/game_state.dart';
import 'fixtures_screen.dart';
import 'match_screen.dart';
import 'squad_screen.dart';
import 'training_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final save = gameState.save;
    if (save == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final league = save.league;
    final userTeam = gameState.userTeam;
    final standings = league.sortedStandings;
    final userRank = standings.indexWhere((r) => r.teamId == userTeam.id) + 1;
    final next = league.nextUnplayedFixture;
    final seasonComplete = league.isSeasonComplete;

    return Scaffold(
      appBar: AppBar(title: Text(save.clubName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('シーズン ${league.season}', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('順位: $userRank / ${standings.length}位'),
                  Text('平均総合力: ${userTeam.overallRating}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (seasonComplete)
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: ListTile(
                title: const Text('シーズン終了！'),
                subtitle: Text('最終順位: $userRank位'),
                trailing: FilledButton(
                  onPressed: () => context.read<GameState>().startNextSeason(),
                  child: const Text('次のシーズンへ'),
                ),
              ),
            )
          else if (next != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.event),
                title: Text('第${next.matchday}節'),
                subtitle: Text(_fixtureLabel(league, next)),
                trailing: FilledButton(
                  onPressed: () => _playMatch(context),
                  child: const Text('試合を行う'),
                ),
              ),
            ),
          const SizedBox(height: 16),
          _MenuTile(
            icon: Icons.groups,
            label: 'スカッド',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SquadScreen())),
          ),
          _MenuTile(
            icon: Icons.fitness_center,
            label: 'トレーニング',
            onTap: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrainingScreen())),
          ),
          _MenuTile(
            icon: Icons.leaderboard,
            label: '日程・順位表',
            onTap: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FixturesScreen())),
          ),
        ],
      ),
    );
  }

  String _fixtureLabel(League league, Fixture f) {
    final home = league.teams.firstWhere((t) => t.id == f.homeTeamId).name;
    final away = league.teams.firstWhere((t) => t.id == f.awayTeamId).name;
    return '$home vs $away';
  }

  Future<void> _playMatch(BuildContext context) async {
    final gameState = context.read<GameState>();
    final league = gameState.save!.league;
    final result = await gameState.playNextMatchday();
    if (context.mounted && result != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MatchScreen(result: result, league: league)),
      );
    }
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
