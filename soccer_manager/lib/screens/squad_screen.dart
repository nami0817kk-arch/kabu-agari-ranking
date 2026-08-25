import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/game_state.dart';
import '../widgets/player_face_avatar.dart';
import 'player_detail_screen.dart';

class SquadScreen extends StatelessWidget {
  const SquadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final players = [...gameState.userTeam.players]
      ..sort((a, b) {
        final c = a.position.index.compareTo(b.position.index);
        if (c != 0) return c;
        return b.overall.compareTo(a.overall);
      });

    return Scaffold(
      appBar: AppBar(title: const Text('スカッド')),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: players.length,
        itemBuilder: (context, i) {
          final p = players[i];
          final isStarting = gameState.userTeam.startingXI.contains(p.id);
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              tileColor: isStarting
                  ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                  : null,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: PlayerFaceAvatar(playerId: p.id, position: p.position, size: 40, highlighted: isStarting),
              title: Row(
                children: [
                  Flexible(child: Text(p.name, overflow: TextOverflow.ellipsis)),
                  if (p.isLoan) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.swap_horiz, size: 16, color: Colors.indigo),
                  ],
                  if (p.wantsTransfer) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.sentiment_dissatisfied, size: 16, color: Colors.redAccent),
                  ],
                  if (p.isOnInternationalDuty) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.flag, size: 16, color: Colors.blueAccent),
                  ],
                ],
              ),
              subtitle: Text(
                p.isInjured
                    ? '負傷中（あと${p.injuryWeeks}週）'
                    : p.isOnInternationalDuty
                        ? '代表召集中（あと${p.internationalDutyWeeksRemaining}週）'
                        : '${p.age}歳 / 総合 ${p.overall}',
                style: (p.isInjured || p.isOnInternationalDuty) ? const TextStyle(color: Colors.redAccent) : null,
              ),
              trailing: p.fatigue > 70
                  ? const Icon(Icons.battery_alert, color: Colors.orange)
                  : Text('${p.overall}', style: Theme.of(context).textTheme.titleMedium),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PlayerDetailScreen(playerId: p.id)),
              ),
            ),
          );
        },
      ),
    );
  }
}
