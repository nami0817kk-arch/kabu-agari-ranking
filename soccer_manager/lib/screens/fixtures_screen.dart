import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/league.dart';
import '../state/game_state.dart';

class FixturesScreen extends StatelessWidget {
  const FixturesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final league = gameState.save!.league;
    final userTeamId = gameState.userTeam.id;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('日程・順位表'),
          bottom: const TabBar(tabs: [Tab(text: '順位表'), Tab(text: '日程')]),
        ),
        body: TabBarView(
          children: [
            _StandingsTab(league: league, userTeamId: userTeamId),
            _ScheduleTab(league: league, userTeamId: userTeamId),
          ],
        ),
      ),
    );
  }
}

class _StandingsTab extends StatelessWidget {
  final League league;
  final String userTeamId;

  const _StandingsTab({required this.league, required this.userTeamId});

  @override
  Widget build(BuildContext context) {
    final rows = league.sortedStandings;
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final r = rows[i];
        final team = league.teams.firstWhere((t) => t.id == r.teamId);
        final isUser = r.teamId == userTeamId;
        return Container(
          color: isUser
              ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4)
              : null,
          child: ListTile(
            leading: SizedBox(width: 24, child: Text('${i + 1}')),
            title: Text(team.name),
            subtitle: Text('${r.played}試合 勝${r.won} 分${r.draw} 敗${r.lost} 得失点差${r.goalDiff}'),
            trailing: Text('${r.points}pt', style: Theme.of(context).textTheme.titleMedium),
          ),
        );
      },
    );
  }
}

class _ScheduleTab extends StatelessWidget {
  final League league;
  final String userTeamId;

  const _ScheduleTab({required this.league, required this.userTeamId});

  @override
  Widget build(BuildContext context) {
    final userFixtures = league.fixtures
        .where((f) => f.homeTeamId == userTeamId || f.awayTeamId == userTeamId)
        .toList()
      ..sort((a, b) => a.matchday.compareTo(b.matchday));

    return ListView.builder(
      itemCount: userFixtures.length,
      itemBuilder: (context, i) {
        final f = userFixtures[i];
        final home = league.teams.firstWhere((t) => t.id == f.homeTeamId).name;
        final away = league.teams.firstWhere((t) => t.id == f.awayTeamId).name;
        final result = f.result;
        return ListTile(
          leading: SizedBox(width: 48, child: Text('第${f.matchday}節')),
          title: Text('$home vs $away'),
          trailing: result == null
              ? const Text('未消化')
              : Text(
                  '${result.homeGoals} - ${result.awayGoals}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
        );
      },
    );
  }
}
