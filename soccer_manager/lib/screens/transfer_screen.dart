import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../state/game_state.dart';
import '../widgets/player_face_avatar.dart';
import '../widgets/position_filter_bar.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  PositionGroup? _filter;

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final save = gameState.save!;
    final squadFull = gameState.userTeam.players.length >= maxSquadSize;
    final players = gameState.transferMarket.where((p) => _filter == null || p.position.group == _filter).toList()
      ..sort((a, b) => b.overall.compareTo(a.overall));

    return Scaffold(
      appBar: AppBar(title: const Text('移籍市場')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('資金: ${save.budget}万円', style: Theme.of(context).textTheme.titleMedium),
                Text('スカッド: ${gameState.userTeam.players.length}/$maxSquadSize'),
              ],
            ),
          ),
          if (squadFull)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('スカッドが上限のため、獲得するには誰かを放出してください。', style: TextStyle(color: Colors.orange)),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: PositionFilterBar(
              value: _filter,
              onChanged: (v) => setState(() => _filter = v),
            ),
          ),
          Expanded(
            child: players.isEmpty
                ? const Center(child: Text('該当する選手はいません'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: players.length,
                    itemBuilder: (context, i) {
                      final p = players[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: PlayerFaceAvatar(playerId: p.id, position: p.position),
                          title: Text(p.name),
                          subtitle:
                              Text('${p.age}歳 / ${p.position.label} / 総合 ${p.overall} / 潜在 ${p.potential} / 移籍金 ${p.marketValue}万'),
                          trailing: FilledButton(
                            onPressed: squadFull ? null : () => _showAcquireSheet(context, p),
                            child: const Text('獲得する'),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showAcquireSheet(BuildContext context, Player player) {
    final gameState = context.read<GameState>();
    final save = gameState.save!;
    final total = player.marketValue;
    final downPayment = (total * 0.3).round();
    final loanFee = (total * GameState.loanFeeRatioPercent / 100).round();

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${player.name}を獲得', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.payments),
                title: const Text('一括で獲得'),
                subtitle: Text('$total万円を即座に支払う'),
                enabled: save.budget >= total,
                onTap: () {
                  Navigator.pop(ctx);
                  _acquire(context, () => gameState.buyPlayer(player.id), player.name);
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_view_week),
                title: const Text('分割払いで獲得'),
                subtitle: Text('頭金$downPayment万円 + 残額を4週で均等払い'),
                enabled: save.budget >= downPayment,
                onTap: () {
                  Navigator.pop(ctx);
                  _acquire(context, () => gameState.buyPlayerOnInstallments(player.id), player.name);
                },
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('ローンで獲得'),
                subtitle: Text('契約金$loanFee万円・週俸6割・${GameState.loanDurationWeeks}週で契約終了'),
                enabled: save.budget >= loanFee,
                onTap: () {
                  Navigator.pop(ctx);
                  _acquire(context, () => gameState.signLoanPlayer(player.id), player.name);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _acquire(BuildContext context, Future<bool> Function() action, String name) async {
    final ok = await action();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? '$nameを獲得しました' : '獲得できませんでした')),
      );
    }
  }
}
