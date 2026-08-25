import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../game/pitch_game.dart';
import '../models/match_result.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../state/game_state.dart';
import '../widgets/position_colors.dart';

enum _Phase { firstHalf, halfTime, secondHalf, finished }

/// 自クラブの試合をハーフタイム対応(前半→ハーフタイム指示・交代→後半)で
/// 進行する試合画面。カップ戦など非対話的な試合は引き続きMatchScreenを使う。
class LiveMatchScreen extends StatefulWidget {
  const LiveMatchScreen({super.key});

  @override
  State<LiveMatchScreen> createState() => _LiveMatchScreenState();
}

class _LiveMatchScreenState extends State<LiveMatchScreen> {
  _Phase _phase = _Phase.firstHalf;
  final List<MatchEvent> _revealed = [];
  int _currentMinute = 0;
  MatchResult? _finalResult;
  late PitchGame _game;

  @override
  void initState() {
    super.initState();
    final firstHalf = context.read<GameState>().liveFirstHalf!;
    _game = PitchGame(
      events: firstHalf.events,
      startMinute: 1,
      endMinute: 45,
      durationSeconds: 6,
      onEvent: (e) => setState(() => _revealed.add(e)),
      onFinished: () => setState(() => _phase = _Phase.halfTime),
      onMinuteTick: (m) => setState(() => _currentMinute = m),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final fixture = gameState.liveFixture;
    final matchday = fixture?.matchday ?? _finalResult?.matchday ?? 0;
    final homeId = fixture?.homeTeamId ?? _finalResult?.homeTeamId;
    final awayId = fixture?.awayTeamId ?? _finalResult?.awayTeamId;
    if (homeId == null || awayId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('試合'), automaticallyImplyLeading: false),
        body: const Center(child: Text('試合情報がありません')),
      );
    }
    final league = gameState.save!.league;
    final home = league.teams.firstWhere((t) => t.id == homeId);
    final away = league.teams.firstWhere((t) => t.id == awayId);
    final homeGoals = _revealed.where((e) => e.teamId == home.id && e.type == MatchEventType.goal).length;
    final awayGoals = _revealed.where((e) => e.teamId == away.id && e.type == MatchEventType.goal).length;

    return Scaffold(
      appBar: AppBar(title: Text('第$matchday節'), automaticallyImplyLeading: false),
      body: _phase == _Phase.halfTime
          ? _HalfTimePanel(
              home: home,
              away: away,
              homeGoals: homeGoals,
              awayGoals: awayGoals,
              onContinue: () => _startSecondHalf(),
            )
          : _buildMatchView(context, home, away, homeGoals, awayGoals),
    );
  }

  Widget _buildMatchView(BuildContext context, Team home, Team away, int homeGoals, int awayGoals) {
    final finished = _phase == _Phase.finished;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(child: _TeamHeader(team: home)),
              Column(
                children: [
                  Text(
                    finished ? '試合終了' : "$_currentMinute'",
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: finished ? Colors.redAccent : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('$homeGoals - $awayGoals', style: Theme.of(context).textTheme.headlineMedium),
                  ),
                ],
              ),
              Expanded(child: _TeamHeader(team: away)),
            ],
          ),
        ),
        AspectRatio(
          aspectRatio: 3 / 2,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: GameWidget(game: _game),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: _revealed
                .map((e) => _CommentaryTile(event: e, teamName: e.teamId == home.id ? home.name : away.name))
                .toList(),
          ),
        ),
        if (finished)
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('戻る'),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _startSecondHalf() async {
    final gameState = context.read<GameState>();
    final merged = await gameState.playSecondHalf();
    if (merged == null || !mounted) return;
    final secondHalfEvents = merged.events.where((e) => e.minute > 45).toList();
    setState(() {
      _finalResult = merged;
      _phase = _Phase.secondHalf;
      _game = PitchGame(
        events: secondHalfEvents,
        startMinute: 46,
        endMinute: 90,
        durationSeconds: 6,
        onEvent: (e) => setState(() => _revealed.add(e)),
        onFinished: () => setState(() => _phase = _Phase.finished),
        onMinuteTick: (m) => setState(() => _currentMinute = m),
      );
    });
  }
}

Color _teamColor(String teamId) => Colors.primaries[teamId.hashCode.abs() % Colors.primaries.length];

class _TeamHeader extends StatelessWidget {
  final Team team;

  const _TeamHeader({required this.team});

  @override
  Widget build(BuildContext context) {
    final color = _teamColor(team.id);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: color,
          child: Text(
            team.name.isEmpty ? '?' : team.name.substring(0, 1),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        Text(team.name, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, maxLines: 1),
      ],
    );
  }
}

class _CommentaryTile extends StatelessWidget {
  final MatchEvent event;
  final String teamName;

  const _CommentaryTile({required this.event, required this.teamName});

  @override
  Widget build(BuildContext context) {
    final (icon, color, text) = switch (event.type) {
      MatchEventType.goal => (Icons.sports_soccer, Colors.green, '${event.scorerName ?? '???'} 得点！ ($teamName)'),
      MatchEventType.chance => (Icons.flash_on, Colors.orange, '${event.scorerName ?? '???'} 惜しいシュート ($teamName)'),
      MatchEventType.yellowCard => (Icons.warning_amber, Colors.amber, '${event.scorerName ?? '???'} に警告 ($teamName)'),
      MatchEventType.redCard => (Icons.dangerous, Colors.redAccent, '${event.scorerName ?? '???'} が退場！ ($teamName)'),
    };
    return ListTile(
      dense: true,
      leading: SizedBox(
        width: 44,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("${event.minute}'"),
            const SizedBox(width: 4),
            Icon(icon, size: 16, color: color),
          ],
        ),
      ),
      title: Text(text),
    );
  }
}

class _HalfTimePanel extends StatelessWidget {
  final Team home;
  final Team away;
  final int homeGoals;
  final int awayGoals;
  final VoidCallback onContinue;

  const _HalfTimePanel({
    required this.home,
    required this.away,
    required this.homeGoals,
    required this.awayGoals,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final team = gameState.userTeam;
    final remaining = GameState.maxSubstitutionsPerMatch - gameState.substitutionsUsed;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                Text('ハーフタイム', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('$homeGoals - $awayGoals', style: Theme.of(context).textTheme.headlineMedium),
                Text('${home.name} vs ${away.name}', style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          const Divider(height: 32),
          Text('戦術指示', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: 90, child: Text('プレッシング')),
              Expanded(
                child: Slider(
                  value: team.pressing.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 10,
                  label: '${team.pressing}',
                  onChanged: (v) => gameState.setPressing(v.round()),
                ),
              ),
              SizedBox(width: 32, child: Text('${team.pressing}')),
            ],
          ),
          Row(
            children: [
              const SizedBox(width: 90, child: Text('ライン高さ')),
              Expanded(
                child: Slider(
                  value: team.lineHeight.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 10,
                  label: '${team.lineHeight}',
                  onChanged: (v) => gameState.setLineHeight(v.round()),
                ),
              ),
              SizedBox(width: 32, child: Text('${team.lineHeight}')),
            ],
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('交代', style: Theme.of(context).textTheme.titleMedium),
              Text('残り$remaining回'),
            ],
          ),
          const SizedBox(height: 8),
          for (final id in team.startingXI) _StartingPlayerTile(playerId: id, team: team),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: onContinue, child: const Text('後半開始')),
          ),
        ],
      ),
    );
  }
}

class _StartingPlayerTile extends StatelessWidget {
  final String playerId;
  final Team team;

  const _StartingPlayerTile({required this.playerId, required this.team});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final p = team.players.firstWhere((pl) => pl.id == playerId);
    final canSub = gameState.canMakeSubstitution;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        leading: PositionAvatar(position: p.position, highlighted: true),
        title: Text(p.name),
        subtitle: Text(
          '${p.position.label} / 総合 ${p.overall}${p.fatigue > 70 ? ' / 疲労大' : ''}',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.swap_horiz),
          tooltip: '交代',
          onPressed: canSub ? () => _showSubstituteSheet(context) : null,
        ),
      ),
    );
  }

  void _showSubstituteSheet(BuildContext context) {
    final gameState = context.read<GameState>();
    final out = team.players.firstWhere((pl) => pl.id == playerId);
    final candidates = team.players
        .where((p) => !p.isInjured && !team.startingXI.contains(p.id))
        .where((p) => p.position == out.position || p.position.group == out.position.group)
        .toList()
      ..sort((a, b) => b.overall.compareTo(a.overall));

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('${out.name} を交代', style: Theme.of(ctx).textTheme.titleMedium),
            ),
            for (final p in candidates)
              ListTile(
                leading: PositionAvatar(position: p.position),
                title: Text(p.name),
                subtitle: Text('${p.position.label} / 総合 ${p.overall}'),
                onTap: () {
                  Navigator.pop(ctx);
                  gameState.makeHalfTimeSubstitution(outPlayerId: out.id, inPlayerId: p.id);
                },
              ),
            if (candidates.isEmpty)
              const Padding(padding: EdgeInsets.all(16), child: Text('交代できる選手がいません')),
          ],
        ),
      ),
    );
  }
}
