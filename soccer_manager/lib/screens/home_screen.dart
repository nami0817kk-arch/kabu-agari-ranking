import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/formation.dart';
import '../models/league.dart';
import '../state/game_state.dart';
import 'finance_screen.dart';
import 'match_screen.dart';
import 'start_screen.dart';
import 'training_screen.dart';
import 'transfer_screen.dart';
import 'youth_screen.dart';

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

    final scheme = Theme.of(context).colorScheme;
    final league = save.league;
    final userTeam = gameState.userTeam;
    final standings = league.sortedStandings;
    final userRank = standings.indexWhere((r) => r.teamId == userTeam.id) + 1;
    final next = league.nextUnplayedFixture;
    final seasonComplete = league.isSeasonComplete;
    final net = _netWeekly(gameState);

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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('シーズン ${league.season}', style: Theme.of(context).textTheme.titleMedium),
                      Chip(label: Text(userTeam.formation.label)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('目標: ${save.boardTargetRank}位以内', style: TextStyle(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.1,
            children: [
              _StatTile(
                icon: Icons.emoji_events,
                label: '順位',
                value: '$userRank / ${standings.length}',
                color: Colors.amber.shade800,
              ),
              _StatTile(
                icon: Icons.account_balance_wallet,
                label: '資金',
                value: '${save.budget}万円',
                sub: '週収支 ${net >= 0 ? '+' : ''}$net万円',
                color: net >= 0 ? Colors.green.shade700 : Colors.red.shade700,
              ),
              _StatTile(
                icon: Icons.bar_chart,
                label: '平均総合力',
                value: '${userTeam.overallRating}',
                color: Colors.blue.shade700,
              ),
              _StatTile(
                icon: Icons.shield,
                label: '監督への信頼度',
                value: '${save.confidence}',
                progress: save.confidence / 100,
                color: save.confidence <= 25 ? Colors.redAccent : Colors.teal.shade700,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (seasonComplete)
            Card(
              color: scheme.primaryContainer,
              child: ListTile(
                leading: const Icon(Icons.flag),
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
                leading: CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: const Icon(Icons.event),
                ),
                title: Text('第${next.matchday}節'),
                subtitle: Text(_fixtureLabel(league, next)),
                trailing: FilledButton(
                  onPressed: () => _playMatch(context),
                  child: const Text('試合を行う'),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text('クラブ運営', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _ActionTile(
                icon: Icons.fitness_center,
                label: 'トレーニング',
                color: Colors.deepOrange.shade400,
                onTap: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrainingScreen())),
              ),
              _ActionTile(
                icon: Icons.swap_horiz,
                label: '移籍市場',
                color: Colors.indigo.shade400,
                onTap: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TransferScreen())),
              ),
              _ActionTile(
                icon: Icons.emoji_people,
                label: 'ユース・スカウト',
                color: Colors.teal.shade400,
                onTap: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const YouthScreen())),
              ),
              _ActionTile(
                icon: Icons.account_balance,
                label: 'クラブ経営',
                color: Colors.brown.shade400,
                onTap: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FinanceScreen())),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _netWeekly(GameState gameState) {
    return gameState.weeklyIncomeFor(gameState.userTeam.id) - gameState.weeklyWageBill;
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
    if (!context.mounted) return;

    final expired = gameState.lastContractExpirations;
    if (expired.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('契約満了で退団: ${expired.join('、')}')),
      );
      gameState.lastContractExpirations = [];
    }

    if (result != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MatchScreen(result: result, league: league)),
      );
    }
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final Color color;
  final double? progress;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.sub,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (sub != null)
            Text(sub!, style: TextStyle(fontSize: 11, color: color)),
          if (progress != null) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: progress, minHeight: 6, color: color),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: color, child: Icon(icon, color: Colors.white, size: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
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
