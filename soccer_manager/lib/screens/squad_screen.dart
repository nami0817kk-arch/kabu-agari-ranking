import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/game_state.dart';
import '../widgets/player_face_avatar.dart';
import 'player_compare_screen.dart';
import 'player_detail_screen.dart';

class SquadScreen extends StatefulWidget {
  const SquadScreen({super.key});

  @override
  State<SquadScreen> createState() => _SquadScreenState();
}

class _SquadScreenState extends State<SquadScreen> {
  bool _compareMode = false;
  final List<String> _selected = [];

  void _toggleCompareMode() {
    setState(() {
      _compareMode = !_compareMode;
      _selected.clear();
    });
  }

  void _toggleSelected(String playerId) {
    setState(() {
      if (_selected.contains(playerId)) {
        _selected.remove(playerId);
      } else {
        if (_selected.length >= 2) _selected.removeAt(0);
        _selected.add(playerId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final players = [...gameState.userTeam.players]..sort((a, b) {
        final c = a.position.index.compareTo(b.position.index);
        if (c != 0) return c;
        return b.overall.compareTo(a.overall);
      });

    return Scaffold(
      appBar: AppBar(
        title: Text(_compareMode ? '選手を2人選択' : 'スカッド'),
        actions: [
          IconButton(
            icon: Icon(_compareMode ? Icons.close : Icons.compare_arrows),
            tooltip: _compareMode ? '比較モードを終了' : '選手を比較',
            onPressed: _toggleCompareMode,
          ),
        ],
      ),
      floatingActionButton: _compareMode && _selected.length == 2
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder: (_) => PlayerCompareScreen(
                            playerAId: _selected[0], playerBId: _selected[1]),
                      ),
                    )
                    .then((_) => _toggleCompareMode());
              },
              icon: const Icon(Icons.compare_arrows),
              label: const Text('比較する'),
            )
          : null,
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: players.length,
        itemBuilder: (context, i) {
          final p = players[i];
          final isStarting = gameState.userTeam.startingXI.contains(p.id);
          final isSelected = _selected.contains(p.id);
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              tileColor: isSelected
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : isStarting
                      ? Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.3)
                      : null,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              leading: _compareMode
                  ? Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleSelected(p.id))
                  : PlayerFaceAvatar(
                      playerId: p.id,
                      position: p.position,
                      size: 40,
                      highlighted: isStarting),
              title: Row(
                children: [
                  Flexible(
                      child: Text(p.name, overflow: TextOverflow.ellipsis)),
                  if (p.isLoan) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.swap_horiz,
                        size: 16, color: Colors.indigo),
                  ],
                  if (p.wantsTransfer) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.sentiment_dissatisfied,
                        size: 16, color: Colors.redAccent),
                  ],
                  if (p.isOnInternationalDuty) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.flag, size: 16, color: Colors.blueAccent),
                  ],
                  if (p.isLoanedOut) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.flight_takeoff,
                        size: 16, color: Colors.deepPurple),
                  ],
                  if (p.isTransferListed) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.sell_outlined,
                        size: 16, color: Colors.orange),
                  ],
                ],
              ),
              subtitle: Text(
                p.isInjured
                    ? '負傷中（あと${p.injuryWeeks}週）'
                    : p.isOnInternationalDuty
                        ? '代表召集中（あと${p.internationalDutyWeeksRemaining}週）'
                        : p.isLoanedOut
                            ? '${p.loanedOutToClubName}へローン放出中（あと${p.loanedOutWeeksRemaining}週）'
                            : '${p.age}歳 / 総合 ${p.overall}',
                style: (p.isInjured || p.isOnInternationalDuty || p.isLoanedOut)
                    ? const TextStyle(color: Colors.redAccent)
                    : null,
              ),
              trailing: _compareMode
                  ? Text('${p.overall}',
                      style: Theme.of(context).textTheme.titleMedium)
                  : p.fatigue > 70
                      ? const Icon(Icons.battery_alert, color: Colors.orange)
                      : Text('${p.overall}',
                          style: Theme.of(context).textTheme.titleMedium),
              onTap: _compareMode
                  ? () => _toggleSelected(p.id)
                  : () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => PlayerDetailScreen(playerId: p.id)),
                      ),
            ),
          );
        },
      ),
    );
  }
}
