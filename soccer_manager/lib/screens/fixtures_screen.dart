import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/league.dart';
import '../state/game_state.dart';
import '../widgets/club_emblem.dart';

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
            leading: SizedBox(
              width: 48,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 20, child: Text('${i + 1}')),
                  const SizedBox(width: 6),
                  ClubEmblem(teamId: team.id, teamName: team.name, size: 24),
                ],
              ),
            ),
            title: Text(team.name),
            subtitle: Text('${r.played}試合 勝${r.won} 分${r.draw} 敗${r.lost} 得失点差${r.goalDiff}'),
            trailing: Text('${r.points}pt', style: Theme.of(context).textTheme.titleMedium),
          ),
        );
      },
    );
  }
}

class _ScheduleTab extends StatefulWidget {
  final League league;
  final String userTeamId;

  const _ScheduleTab({required this.league, required this.userTeamId});

  @override
  State<_ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<_ScheduleTab> {
  bool _showFullSchedule = false;
  late int _selectedMatchday;
  final _chipScrollController = ScrollController();

  int get _totalMatchdays =>
      widget.league.fixtures.map((f) => f.matchday).reduce((a, b) => a > b ? a : b);

  int? get _nextMatchday => widget.league.nextUnplayedFixture?.matchday;

  @override
  void initState() {
    super.initState();
    _selectedMatchday = _nextMatchday ?? _totalMatchdays;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chipScrollController.hasClients) return;
      final offset = ((_selectedMatchday - 1) * 76.0).clamp(0.0, _chipScrollController.position.maxScrollExtent);
      _chipScrollController.jumpTo(offset);
    });
  }

  @override
  void dispose() {
    _chipScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final league = widget.league;
    final userTeamId = widget.userTeamId;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('自分の日程')),
              ButtonSegment(value: true, label: Text('全日程')),
            ],
            selected: {_showFullSchedule},
            onSelectionChanged: (s) => setState(() => _showFullSchedule = s.first),
          ),
        ),
        if (_showFullSchedule) ...[
          SizedBox(
            height: 44,
            child: ListView.builder(
              controller: _chipScrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _totalMatchdays,
              itemBuilder: (context, i) {
                final md = i + 1;
                final isNext = md == _nextMatchday;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(isNext ? '第$md節 •' : '第$md節'),
                    selected: _selectedMatchday == md,
                    onSelected: (_) => setState(() => _selectedMatchday = md),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _MatchdayList(league: league, matchday: _selectedMatchday, userTeamId: userTeamId),
          ),
        ] else
          Expanded(child: _UserFixtureList(league: league, userTeamId: userTeamId)),
      ],
    );
  }
}

class _MatchdayList extends StatelessWidget {
  final League league;
  final int matchday;
  final String userTeamId;

  const _MatchdayList({required this.league, required this.matchday, required this.userTeamId});

  @override
  Widget build(BuildContext context) {
    final fixtures = league.fixtures.where((f) => f.matchday == matchday).toList();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: fixtures.length,
      itemBuilder: (context, i) {
        final f = fixtures[i];
        final home = league.teams.firstWhere((t) => t.id == f.homeTeamId);
        final away = league.teams.firstWhere((t) => t.id == f.awayTeamId);
        final isUserMatch = f.homeTeamId == userTeamId || f.awayTeamId == userTeamId;
        final isDerby = context.read<GameState>().isRivalFixture(f);
        final result = f.result;
        return Container(
          color: isUserMatch ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3) : null,
          child: ListTile(
            leading: isDerby ? const Icon(Icons.local_fire_department, color: Colors.redAccent) : null,
            title: Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(child: Text(home.name, textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 6),
                      ClubEmblem(teamId: home.id, teamName: home.name, size: 22),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    result == null ? 'vs' : '${result.homeGoals} - ${result.awayGoals}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      ClubEmblem(teamId: away.id, teamName: away.name, size: 22),
                      const SizedBox(width: 6),
                      Flexible(child: Text(away.name, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _UserFixtureList extends StatelessWidget {
  final League league;
  final String userTeamId;

  const _UserFixtureList({required this.league, required this.userTeamId});

  @override
  Widget build(BuildContext context) {
    final userFixtures = league.fixtures
        .where((f) => f.homeTeamId == userTeamId || f.awayTeamId == userTeamId)
        .toList()
      ..sort((a, b) => a.matchday.compareTo(b.matchday));
    final nextMatchday = league.nextUnplayedFixture?.matchday;

    return ListView.builder(
      itemCount: userFixtures.length,
      itemBuilder: (context, i) {
        final f = userFixtures[i];
        final home = league.teams.firstWhere((t) => t.id == f.homeTeamId).name;
        final away = league.teams.firstWhere((t) => t.id == f.awayTeamId).name;
        final opponentId = f.homeTeamId == userTeamId ? f.awayTeamId : f.homeTeamId;
        final opponent = league.teams.firstWhere((t) => t.id == opponentId);
        final result = f.result;
        final isNext = f.matchday == nextMatchday;
        final isDerby = context.read<GameState>().isRivalFixture(f);
        return Container(
          color: isNext ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3) : null,
          child: ListTile(
            leading: SizedBox(
              width: 76,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 44, child: Text('第${f.matchday}節')),
                  ClubEmblem(teamId: opponent.id, teamName: opponent.name, size: 24),
                ],
              ),
            ),
            title: Row(
              children: [
                Flexible(child: Text('$home vs $away', overflow: TextOverflow.ellipsis)),
                if (isDerby) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.local_fire_department, size: 16, color: Colors.redAccent),
                ],
              ],
            ),
            trailing: result == null
                ? Text(isNext ? '次節' : '未消化', style: isNext ? const TextStyle(fontWeight: FontWeight.bold) : null)
                : Text(
                    '${result.homeGoals} - ${result.awayGoals}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
          ),
        );
      },
    );
  }
}
