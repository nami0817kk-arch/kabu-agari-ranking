import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../game/pitch_game.dart';
import '../models/match_result.dart';
import '../models/team.dart';

class MatchScreen extends StatefulWidget {
  final MatchResult result;
  final List<Team> teams;

  /// 画面上部に表示する見出し(省略時は「第N節」)。カップ戦ではラウンド名を渡す。
  final String? title;

  const MatchScreen({super.key, required this.result, required this.teams, this.title});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  final List<MatchEvent> _revealed = [];
  bool _finished = false;
  int _currentMinute = 0;
  late final PitchGame _game;

  @override
  void initState() {
    super.initState();
    _game = PitchGame(
      events: widget.result.events,
      onEvent: (e) => setState(() => _revealed.add(e)),
      onFinished: () => setState(() => _finished = true),
      onMinuteTick: (m) => setState(() => _currentMinute = m),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teams = widget.teams;
    final home = teams.firstWhere((t) => t.id == widget.result.homeTeamId);
    final away = teams.firstWhere((t) => t.id == widget.result.awayTeamId);
    final homeGoalsSoFar = _revealed.where((e) => e.teamId == home.id && e.type == MatchEventType.goal).length;
    final awayGoalsSoFar = _revealed.where((e) => e.teamId == away.id && e.type == MatchEventType.goal).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? '第${widget.result.matchday}節'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
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
                      _finished ? '試合終了' : "$_currentMinute'",
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: _finished ? Colors.redAccent : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '$homeGoalsSoFar - $awayGoalsSoFar',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
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
              children: _buildCommentary(teams),
            ),
          ),
          if (_finished)
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
      ),
    );
  }

  List<Widget> _buildCommentary(List<Team> teams) {
    final items = <Widget>[];
    var halfTimeShown = false;
    for (final e in _revealed) {
      if (!halfTimeShown && e.minute > 45) {
        items.add(const _HalfTimeDivider());
        halfTimeShown = true;
      }
      items.add(_CommentaryTile(event: e, teamName: teams.firstWhere((t) => t.id == e.teamId).name));
    }
    if (!halfTimeShown && _currentMinute >= 45) {
      items.add(const _HalfTimeDivider());
    }
    return items;
  }
}

/// チームIDから決定論的に選んだ色。試合画面でチームを視覚的に区別するためだけに使う。
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

class _HalfTimeDivider extends StatelessWidget {
  const _HalfTimeDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('前半終了', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ),
          const Expanded(child: Divider()),
        ],
      ),
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
