import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../models/save_game.dart';
import '../models/team.dart';
import '../state/game_state.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/responsive_body.dart';
import 'player_detail_screen.dart';

/// リーグ全体(1部・2部)の若手選手をポテンシャル基準でランキング表示する画面。
/// スカウティングの参考として、自クラブ以外の有望株にも目を向けられるようにする。
class YoungTalentScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final save = gameState.save!;
    final top = topProspects(save);

    return Scaffold(
      appBar: AppBar(
        title: const Text('若手有望株ランキング'),
        leading: const BackButton(),
        actions: const [QuickAccessMenuButton()],
      ),
      drawer: const QuickAccessDrawer(),
      body: ResponsiveBody(
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: top.length,
          itemBuilder: (context, i) {
            final entry = top[i];
            final p = entry.player;
            final isUserTeam = entry.team.id == save.userTeamId;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                onTap: !isUserTeam
                    ? null
                    : () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => PlayerDetailScreen(playerId: p.id))),
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Row(
                  children: [
                    Flexible(
                        child: Text(p.name, overflow: TextOverflow.ellipsis)),
                    if (isUserTeam) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.shield,
                          size: 16, color: Colors.blueAccent),
                    ],
                  ],
                ),
                subtitle: Text(
                    '${entry.team.name} / ${p.position.label} / ${p.age}歳'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('POT ${p.potential}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple)),
                    Text('現在 ${p.overall}',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            );
          },
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
