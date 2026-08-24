import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../game/pitch_game.dart';
import '../models/league.dart';
import '../models/match_result.dart';

class MatchScreen extends StatefulWidget {
  final MatchResult result;
  final League league;

  const MatchScreen({super.key, required this.result, required this.league});

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
    final league = widget.league;
    final home = league.teams.firstWhere((t) => t.id == widget.result.homeTeamId);
    final away = league.teams.firstWhere((t) => t.id == widget.result.awayTeamId);
    final homeGoalsSoFar = _revealed.where((e) => e.teamId == home.id).length;
    final awayGoalsSoFar = _revealed.where((e) => e.teamId == away.id).length;

    return Scaffold(
      appBar: AppBar(title: Text('第${widget.result.matchday}節'), automaticallyImplyLeading: false),
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
                  .map(
                    (e) => ListTile(
                      dense: true,
                      leading: Text("${e.minute}'"),
                      title: Text(
                        '${e.scorerName ?? '???'} 得点 (${league.teams.firstWhere((t) => t.id == e.teamId).name})',
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          if (_finished)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text('ホームへ戻る'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
