import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../state/game_state.dart';

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final save = gameState.save!;
    final team = gameState.userTeam;
    final income = gameState.weeklyIncomeFor(team.id);
    final wageBill = gameState.weeklyWageBill;
    final net = income - wageBill;

    final sortedByExpiry = team.players.where((p) => !p.isLoan).toList()
      ..sort((a, b) => a.contractWeeksRemaining.compareTo(b.contractWeeksRemaining));
    final loanPlayers = team.players.where((p) => p.isLoan).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('クラブ経営')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('資金: ${save.budget}万円', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('週間収入: +$income万円（観客動員・スポンサー収入込み）'),
                  Text('週間人件費: -$wageBill万円（スタッフ週俸込み）'),
                  Text(
                    '週間収支: ${net >= 0 ? '+' : ''}$net万円',
                    style: TextStyle(
                      color: net >= 0 ? Colors.green : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('スポンサー契約', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _SponsorSection(gameState: gameState),
          if (save.pendingInstallments.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('分割払い残金', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final inst in save.pendingInstallments)
              Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  title: Text(inst.description),
                  subtitle: Text('残り${inst.weeksRemaining}週'),
                  trailing: Text('-${inst.weeklyAmount}万円/週'),
                ),
              ),
          ],
          if (loanPlayers.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('ローン加入中の選手', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final p in loanPlayers)
              Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  title: Text(p.name),
                  subtitle: Text('${p.position.label} / 週俸 ${p.wage}万円'),
                  trailing: Text('残り${p.loanWeeksRemaining}週'),
                ),
              ),
          ],
          const SizedBox(height: 16),
          Text('契約状況（残り週数が少ない順）', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final p in sortedByExpiry)
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                title: Text(p.name),
                subtitle: Text('${p.position.label} / 週俸 ${p.wage}万円'),
                trailing: Text(
                  '残り${p.contractWeeksRemaining}週',
                  style: TextStyle(
                    color: p.contractWeeksRemaining <= 4 ? Colors.redAccent : null,
                    fontWeight: p.contractWeeksRemaining <= 4 ? FontWeight.bold : null,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SponsorSection extends StatelessWidget {
  final GameState gameState;

  const _SponsorSection({required this.gameState});

  @override
  Widget build(BuildContext context) {
    final deal = gameState.save!.sponsorDeal;
    final offers = gameState.pendingSponsorOffers;

    if (deal != null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.handshake),
          title: Text(deal.name),
          subtitle: Text('残り${deal.weeksRemaining}週'),
          trailing: Text('+${deal.weeklyIncome}万円/週', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      );
    }

    if (offers.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.hourglass_empty),
          title: Text('現在スポンサーはついていません'),
        ),
      );
    }

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '週間収入が高いほど契約期間は短くなる。契約する候補を選んでください。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ),
        for (int i = 0; i < offers.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              leading: const Icon(Icons.handshake_outlined),
              title: Text(offers[i].name),
              subtitle: Text('契約期間: ${offers[i].weeksRemaining}週'),
              trailing: FilledButton(
                onPressed: () => _choose(context, i),
                child: Text('+${offers[i].weeklyIncome}万円/週'),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _choose(BuildContext context, int index) async {
    await gameState.chooseSponsor(index);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('スポンサー契約を結んだ')),
      );
    }
  }
}
