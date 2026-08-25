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
  late final PitchGame _game;

  @override
  void initState() {
    super.initState();
    _game = PitchGame(
      result: widget.result,
      onEvent: (e) => setState(() => _revealed.add(e)),
      onFinished: () => setState(() => _finished = true),
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
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: Text(home.name, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '$homeGoalsSoFar - $awayGoalsSoFar',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                Expanded(
                  child: Text(away.name, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                ),
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
                  .map((e) => _CommentaryTile(event: e, teamName: teams.firstWhere((t) => t.id == e.teamId).name))
                  .toList(),
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
