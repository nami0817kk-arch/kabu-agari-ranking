import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/contract_engine.dart';
import '../models/attributes.dart';
import '../models/contract_negotiation.dart';
import '../models/player.dart';
import '../data/glossary_entries.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import 'glossary_screen.dart';
import '../widgets/player_face_avatar.dart';
import '../widgets/stat_bar.dart';

class PlayerDetailScreen extends StatelessWidget {
  final String playerId;

  const PlayerDetailScreen({super.key, required this.playerId});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final team = gameState.userTeam;
    final p = team.players.firstWhere((pl) => pl.id == playerId);
    final isStarting = team.startingXI.contains(p.id);
    final sellPrice = (p.marketValue * 0.7).round();
    final renewalCost = gameState.renewalCostFor(p.id);
    final signingBonus = gameState.signingBonusFor(p.id);
    final newAppearanceFee = gameState.appearanceFeeFor(p.id);
    final totalRenewalCost = renewalCost + signingBonus;
    final negotiation = gameState.pendingContractNegotiation;
    final isNegotiatingThisPlayer =
        negotiation != null && negotiation.playerId == p.id;

    final categories = [
      AttributeCategory.technical,
      AttributeCategory.mental,
      AttributeCategory.physical,
      if (p.position == Position.gk) AttributeCategory.goalkeeping,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(p.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: '能力値の意味を見る',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const GlossaryScreen(
                  initialCategory: GlossaryCategory.attribute),
            )),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              PlayerFaceAvatar(
                  playerId: p.id,
                  position: p.position,
                  size: 56,
                  highlighted: true),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${p.position.fullLabel} ・ ${p.age}歳',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          if (p.secondaryPositions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '対応可能ポジション: ${p.secondaryPositions.map((s) => s.label).join(', ')}',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          if (p.careerAppearances > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '通算成績: ${p.careerAppearances}試合 ${p.careerGoals}得点',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (isStarting)
                Chip(
                    label: const Text('スタメン'),
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer),
              if (team.captainId == p.id)
                const Chip(
                  label: Text('キャプテン'),
                  backgroundColor: Colors.amber,
                  labelStyle: TextStyle(color: Colors.white),
                ),
              if (team.viceCaptainId == p.id)
                const Chip(
                  label: Text('副キャプテン'),
                  backgroundColor: Colors.blueGrey,
                  labelStyle: TextStyle(color: Colors.white),
                ),
              if (p.isLoan)
                const Chip(
                    label: Text('ローン加入中'),
                    backgroundColor: Colors.indigo,
                    labelStyle: TextStyle(color: Colors.white)),
              if (p.wantsTransfer)
                const Chip(
                  label: Text('移籍を希望している'),
                  backgroundColor: Colors.redAccent,
                  labelStyle: TextStyle(color: Colors.white),
                ),
              Chip(label: Text(p.personality.label)),
              if (p.isOnInternationalDuty)
                const Chip(
                  label: Text('代表召集中'),
                  backgroundColor: Colors.blueAccent,
                  labelStyle: TextStyle(color: Colors.white),
                ),
              if (p.isLoanedOut)
                Chip(
                  label: Text('${p.loanedOutToClubName}へローン中'),
                  backgroundColor: Colors.deepPurple,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              if (p.isTransferListed)
                const Chip(
                  label: Text('移籍リスト登録中'),
                  backgroundColor: Colors.orange,
                  labelStyle: TextStyle(color: Colors.white),
                ),
            ],
          ),
          if (p.isInjured)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '負傷中（あと${p.injuryWeeks}週は出場不可）',
                style: const TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),
          if (p.isSuspended)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '出場停止中（あと${p.suspendedMatches}試合は出場不可）',
                style: const TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),
          if (p.isOnInternationalDuty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '代表召集中（あと${p.internationalDutyWeeksRemaining}週は出場不可）',
                style: const TextStyle(
                    color: Colors.blueAccent, fontWeight: FontWeight.bold),
              ),
            ),
          const SizedBox(height: 16),
          Text('総合力: ${p.overall}',
              style: Theme.of(context).textTheme.titleLarge),
          Text('市場価値: ${p.marketValue}万円'),
          Text(
            p.isLoan
                ? '週俸: ${p.wage}万円 / ローン残り${p.loanWeeksRemaining}週'
                : '週俸: ${p.wage}万円 / 契約残り${p.contractWeeksRemaining}週',
          ),
          if (p.releaseClause != null)
            Text('リリース条項: ${p.releaseClause}万円',
                style: const TextStyle(color: Colors.deepPurple)),
          const SizedBox(height: 4),
          Text(p.personality.description,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          if (p.role != PlayerRole.standard) ...[
            const SizedBox(height: 4),
            Text('ロール: ${p.role.label} — ${p.role.description}',
                style: const TextStyle(fontSize: 12, color: Colors.teal)),
          ],
          const SizedBox(height: 16),
          StatBar(label: '攻撃', value: p.attack),
          StatBar(label: '守備', value: p.defense),
          StatBar(label: '技術', value: p.technique),
          StatBar(label: 'スタミナ', value: p.stamina),
          const Divider(height: 32),
          StatBar(label: '潜在能力', value: p.potential, color: Colors.purple),
          StatBar(
              label: '疲労', value: p.fatigue, max: 100, color: Colors.redAccent),
          StatBar(
              label: '士気', value: p.morale, max: 100, color: Colors.blueAccent),
          StatBar(
              label: 'マッチシャープネス',
              value: p.matchSharpness,
              max: 100,
              color: Colors.teal),
          StatBar(
            label: '不満度(高いほど満足)',
            value: p.happiness,
            max: 100,
            color: p.happiness < 30
                ? SemanticColors.negative(context)
                : SemanticColors.positive(context),
          ),
          const Divider(height: 32),
          Text('詳細能力値', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          for (final category in categories)
            Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text('${category.label}（${category.keys.length}項目）'),
                initiallyExpanded: true,
                children: [
                  for (final key in category.keys)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: StatBar(
                          label: AttributeKeys.labelOf(key),
                          value: p.attributeValue(key)),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          if (p.isLoan)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ローン加入中の選手は契約更新・放出の対象外です。ローン期間終了時に自動的にチームを離れます。',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  if (p.loanBuyOptionFee != null) ...[
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: gameState.save!.budget < p.loanBuyOptionFee!
                          ? null
                          : () => _exerciseBuyOption(context),
                      child: Text('買取オプションを行使する（${p.loanBuyOptionFee}万円）'),
                    ),
                  ],
                ],
              ),
            )
          else if (p.isLoanedOut)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '他クラブへローン放出中は契約更新・放出の対象外です。期間終了時に自動的に復帰します。',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            )
          else ...[
            Text('現在の出場手当: ${p.appearanceFee}万円/試合',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: gameState.save!.budget < totalRenewalCost
                  ? null
                  : () => _renew(context),
              child: Text(
                '契約更新する（基本$renewalCost万円 + サインボーナス$signingBonus万円 / +40週 / '
                '新出場手当$newAppearanceFee万円）',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.handshake_outlined),
              onPressed: () => _negotiate(context, isNegotiatingThisPlayer),
              label: Text(isNegotiatingThisPlayer
                  ? '交渉を続ける（選手の対案: ${negotiation.counterWage}万円/週）'
                  : '週俸交渉で更新する'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: (team.players.length <= minSquadSize ||
                      !gameState.isTransferWindowOpen)
                  ? null
                  : () => _confirmSell(context, sellPrice),
              child: Text('放出する（$sellPrice万円）'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.sell_outlined),
              onPressed: () {
                FeedbackService.tap();
                gameState.setTransferListed(playerId, !p.isTransferListed);
              },
              label: Text(p.isTransferListed ? '移籍リストから外す' : '移籍リストに登録する'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.flight_takeoff),
              onPressed: (team.players.length <= minSquadSize ||
                      !gameState.isTransferWindowOpen)
                  ? null
                  : () => _showLoanOutDialog(context),
              label: const Text('他クラブへローン放出する'),
            ),
            if (!gameState.isTransferWindowOpen) ...[
              const SizedBox(height: 4),
              Text(gameState.transferWindowStatusLabel,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => _reassure(context),
            label: const Text('話し合う（不満度を和らげる）'),
          ),
          if (!p.isLoan && !p.isLoanedOut) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.gavel),
              onPressed: () =>
                  _editReleaseClause(context, p.releaseClause, p.marketValue),
              label:
                  Text(p.releaseClause == null ? 'リリース条項を設定する' : 'リリース条項を変更する'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.shield),
              onPressed: () {
                FeedbackService.tap();
                gameState.setCaptain(team.captainId == p.id ? null : p.id);
              },
              label: Text(team.captainId == p.id ? 'キャプテンを解任する' : 'キャプテンに任命する'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.shield_outlined),
              onPressed: () {
                FeedbackService.tap();
                gameState
                    .setViceCaptain(team.viceCaptainId == p.id ? null : p.id);
              },
              label: Text(
                  team.viceCaptainId == p.id ? '副キャプテンを解任する' : '副キャプテンに任命する'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _reassure(BuildContext context) async {
    final gameState = context.read<GameState>();
    final ok = await gameState.reassurePlayer(playerId);
    ok ? FeedbackService.success() : FeedbackService.tap();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? '選手を安心させた' : '既に満足しており、話し合う必要はなさそうだ')),
      );
    }
  }

  Future<void> _renew(BuildContext context) async {
    final gameState = context.read<GameState>();
    final ok = await gameState.renewContract(playerId);
    ok ? FeedbackService.success() : FeedbackService.error();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? '契約を更新しました' : '契約を更新できませんでした')),
      );
    }
  }

  Future<void> _negotiate(BuildContext context, bool isOngoing) async {
    final gameState = context.read<GameState>();
    if (!isOngoing) {
      gameState.startContractNegotiation(playerId);
    }
    if (!context.mounted) return;
    await _showNegotiationDialog(context);
  }

  Future<void> _showNegotiationDialog(BuildContext context) async {
    final gameState = context.read<GameState>();
    final negotiation = gameState.pendingContractNegotiation;
    if (negotiation == null) return;
    final controller =
        TextEditingController(text: negotiation.counterWage.toString());
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('週俸交渉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('現在の週俸: ${negotiation.initialWage}万円'),
            Text('選手の対案: ${negotiation.counterWage}万円/週',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
                '交渉回数: ${negotiation.roundsUsed}/${ContractEngine.maxNegotiationRounds}',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '提示する週俸（万円）'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              gameState.cancelContractNegotiation();
              Navigator.pop(dialogContext);
            },
            child: const Text('交渉をやめる'),
          ),
          FilledButton(
            onPressed: () async {
              final wage = int.tryParse(controller.text);
              if (wage == null || wage <= 0) return;
              final result = await gameState.offerContractWage(wage);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (context.mounted) {
                _showNegotiationResultSnackBar(context, result);
              }
            },
            child: const Text('提示する'),
          ),
        ],
      ),
    );
  }

  void _showNegotiationResultSnackBar(
      BuildContext context, ContractOfferResult result) {
    switch (result) {
      case ContractOfferResult.accepted:
        FeedbackService.success();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('週俸交渉が成立し、契約を更新しました')),
        );
        break;
      case ContractOfferResult.countered:
        FeedbackService.tap();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('選手から対案が届きました。もう一度交渉できます')),
        );
        break;
      case ContractOfferResult.insufficientFunds:
        FeedbackService.error();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('資金が不足しており契約を更新できませんでした')),
        );
        break;
      case ContractOfferResult.walkedAway:
        FeedbackService.error();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('選手は交渉に納得できず、交渉から離脱しました')),
        );
        break;
    }
  }

  Future<void> _exerciseBuyOption(BuildContext context) async {
    final gameState = context.read<GameState>();
    final ok = await gameState.exerciseLoanBuyOption(playerId);
    ok ? FeedbackService.success() : FeedbackService.error();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(ok ? '買取オプションを行使し、完全移籍が成立しました' : '買取オプションを行使できませんでした')),
      );
    }
  }

  void _editReleaseClause(BuildContext context, int? current, int marketValue) {
    final controller =
        TextEditingController(text: (current ?? marketValue).toString());
    final gameState = context.read<GameState>();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('リリース条項の設定'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('市場価値: $marketValue万円'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: '解放金額(万円)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          if (current != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                gameState.setReleaseClause(playerId, null);
              },
              child: const Text('解除する'),
            ),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () {
              final amount = int.tryParse(controller.text);
              Navigator.pop(ctx);
              if (amount != null && amount > 0) {
                gameState.setReleaseClause(playerId, amount);
              }
            },
            child: const Text('設定する'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  void _showLoanOutDialog(BuildContext context) {
    final gameState = context.read<GameState>();
    int weeks = 8;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('ローン放出期間'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$weeks週間、他クラブへ貸し出します。期間中の週俸は放出先が負担します。'),
              Slider(
                value: weeks.toDouble(),
                min: GameState.loanOutMinWeeks.toDouble(),
                max: GameState.loanOutMaxWeeks.toDouble(),
                divisions:
                    GameState.loanOutMaxWeeks - GameState.loanOutMinWeeks,
                label: '$weeks週',
                onChanged: (v) => setState(() => weeks = v.round()),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('キャンセル')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await gameState.loanOutPlayer(playerId, weeks);
                ok ? FeedbackService.success() : FeedbackService.error();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ok ? 'ローン放出しました' : 'ローン放出できませんでした')),
                  );
                }
              },
              child: const Text('放出する'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmSell(BuildContext context, int sellPrice) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('この選手を放出しますか？'),
        content: Text('$sellPrice万円を獲得しますが、元には戻せません。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final gameState = context.read<GameState>();
              final ok = await gameState.sellPlayer(playerId);
              ok ? FeedbackService.success() : FeedbackService.error();
              if (context.mounted && ok) {
                Navigator.pop(context);
              }
            },
            child: const Text('放出する'),
          ),
        ],
      ),
    );
  }
}
