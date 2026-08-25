import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/formation.dart';
import '../models/league.dart';
import '../state/game_state.dart';
import 'fixtures_screen.dart';
import 'lineup_screen.dart';
import 'match_screen.dart';
import 'squad_screen.dart';
import 'start_screen.dart';
import 'training_screen.dart';
import 'transfer_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final save = gameState.save;
    if (save == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (gameState.isDismissed) {
      return _DismissalScreen(clubName: save.clubName);
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
                  Text('順位: $userRank / ${standings.length}位（目標: ${save.boardTargetRank}位以内）'),
                  Text('資金: ${save.budget}万円'),
                  Text('平均総合力: ${userTeam.overallRating}　フォーメーション: ${userTeam.formation.label}'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('監督への信頼度'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: save.confidence / 100,
                            minHeight: 8,
                            color: save.confidence <= 25 ? Colors.redAccent : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${save.confidence}'),
                    ],
                  ),
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
            icon: Icons.checklist,
            label: 'スタメン編成',
            onTap: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LineupScreen())),
          ),
          _MenuTile(
            icon: Icons.swap_horiz,
            label: '移籍市場',
            onTap: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TransferScreen())),
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

class _DismissalScreen extends StatelessWidget {
  final String clubName;

  const _DismissalScreen({required this.clubName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.gavel, size: 64, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(
                  '$clubName の監督を解任されました',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text('理事会からの信頼を失いました。', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () async {
                    await context.read<GameState>().deleteSave();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const StartScreen()),
                        (route) => false,
                      );
                    }
                  },
                  child: const Text('新しいクラブで再出発する'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
