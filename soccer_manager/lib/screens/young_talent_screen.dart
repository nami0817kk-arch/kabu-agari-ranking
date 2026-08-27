import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../models/save_game.dart';
import '../models/team.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/responsive_body.dart';
import 'player_detail_screen.dart';

/// リーグ全体(1部・2部)の若手選手をポテンシャル基準でランキング表示する画面。
/// スカウティングの参考として、自クラブ以外の有望株にも目を向けられるようにし、
/// 気になる選手をウォッチリストに追加して追跡できるようにする。
class YoungTalentScreen extends StatefulWidget {
  static const int maxAge = 21;
  static const int displayCount = 30;

  const YoungTalentScreen({super.key});

  /// リーグ全体(1部・2部)の若手選手を、ポテンシャルの高い順(同値なら現在能力順)で
  /// [limit]件まで抽出する。UIから切り離してテスト可能にしてある。
  static List<Prospect> topProspects(SaveGame save,
      {int limit = displayCount}) {
    final allTeams = [...save.league.teams, ...save.secondDivisionTeams];
    final prospects = <Prospect>[];
    for (final team in allTeams) {
      for (final p in team.players) {
        if (p.age <= maxAge) prospects.add(Prospect(player: p, team: team));
      }
    }
    prospects.sort((a, b) {
      final c = b.player.potential.compareTo(a.player.potential);
      if (c != 0) return c;
      return b.player.overall.compareTo(a.player.overall);
    });
    return prospects.take(limit).toList();
  }

  @override
  State<YoungTalentScreen> createState() => _YoungTalentScreenState();
}

class _YoungTalentScreenState extends State<YoungTalentScreen> {
  bool _watchedOnly = false;

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final save = gameState.save!;
    final top = YoungTalentScreen.topProspects(save);
    final visible = _watchedOnly
        ? top.where((e) => gameState.isWatched(e.player.id)).toList()
        : top;

    return Scaffold(
      appBar: AppBar(
        title: const Text('若手有望株ランキング'),
        leading: const BackButton(),
        actions: const [QuickAccessMenuButton()],
      ),
      drawer: const QuickAccessDrawer(),
      body: ResponsiveBody(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '気になる選手は★で追跡リストに追加できます。移籍市場や契約状況の'
                      '変化に気づく参考にしてください。',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('追跡中のみ'),
                    selected: _watchedOnly,
                    onSelected: (v) => setState(() => _watchedOnly = v),
                  ),
                ],
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? Center(
                      child: Text(
                        _watchedOnly ? '追跡中の選手はいません' : '該当する選手はいません',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: visible.length,
                      itemBuilder: (context, i) {
                        final entry = visible[i];
                        final p = entry.player;
                        final isUserTeam = entry.team.id == save.userTeamId;
                        final watched = gameState.isWatched(p.id);
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            onTap: !isUserTeam
                                ? null
                                : () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => PlayerDetailScreen(
                                            playerId: p.id))),
                            leading: CircleAvatar(
                                child: Text('${top.indexOf(entry) + 1}')),
                            title: Row(
                              children: [
                                Flexible(
                                    child: Text(p.name,
                                        overflow: TextOverflow.ellipsis)),
                                if (isUserTeam) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.shield,
                                      size: 16, color: Colors.blueAccent),
                                ],
                              ],
                            ),
                            subtitle: Text(
                                '${entry.team.name} / ${p.position.label} / ${p.age}歳'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('POT ${p.potential}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.deepPurple)),
                                    Text('現在 ${p.overall}',
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                                IconButton(
                                  tooltip: watched ? '追跡をやめる' : '追跡リストに追加',
                                  icon: Icon(
                                    watched ? Icons.star : Icons.star_border,
                                    color: watched ? Colors.amber : null,
                                  ),
                                  onPressed: () {
                                    FeedbackService.tap();
                                    gameState.toggleWatched(p.id);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class Prospect {
  final Player player;
  final Team team;

  const Prospect({required this.player, required this.team});
}
