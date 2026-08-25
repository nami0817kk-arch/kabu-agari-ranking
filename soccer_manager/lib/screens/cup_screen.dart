import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/cup_engine.dart';
import '../models/cup.dart';
import '../models/team.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
import 'match_screen.dart';

class CupScreen extends StatelessWidget {
  const CupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('カップ戦'),
          bottom: const TabBar(tabs: [Tab(text: '国内カップ'), Tab(text: '大陸カップ')]),
        ),
        body: const TabBarView(
          children: [
            _CupTab(type: CupType.domestic),
            _CupTab(type: CupType.continental),
          ],
        ),
      ),
    );
  }
}

class _CupTab extends StatelessWidget {
  final CupType type;
  const _CupTab({required this.type});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final cup = type == CupType.domestic
        ? gameState.domesticCup
        : gameState.continentalCup;

    if (cup == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            type == CupType.continental
                ? '前シーズンをリーグ2位以内で終えると、翌シーズンは大陸カップに出場できます。'
                : 'カップ戦の情報がありません。',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final userId = gameState.userTeam.id;
    final teams = gameState.allTeamsForCups;
    String nameOf(String id) =>
        teams.firstWhere((t) => t.id == id, orElse: () => teams.first).name;
    final totalRounds = cup.rounds.length;
    final nextMatch = cup.nextUnplayedMatch;
    final userEliminated = cup.isEliminated(userId);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (cup.isComplete)
          Card(
            color: cup.championId == userId
                ? SemanticColors.positive(context).withValues(alpha: 0.15)
                : null,
            child: ListTile(
              leading: Icon(
                Icons.emoji_events,
                color: cup.championId == userId
                    ? SemanticColors.positive(context)
                    : null,
              ),
              title: Text('優勝: ${nameOf(cup.championId!)}'),
            ),
          )
        else if (userEliminated)
          Card(
            child: ListTile(
              leading: Icon(Icons.info_outline,
                  color: SemanticColors.negative(context)),
              title: const Text('自クラブは敗退しました'),
              subtitle: const Text('他クラブの結果は引き続き更新されます'),
            ),
          ),
        if (nextMatch != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _playNext(context, type),
                child: const Text('次の試合を消化'),
              ),
            ),
          ),
        for (final round in cup.rounds) ...[
          _RoundSection(
            title: CupEngine.roundLabel(round.first.round, totalRounds),
            initiallyExpanded:
                round.any((m) => m.result == null) || round == cup.rounds.last,
            children: [
              for (final m in round)
                Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    tileColor:
                        (m.homeTeamId == userId || m.awayTeamId == userId)
                            ? Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.25)
                            : null,
                    title: Text(
                        '${nameOf(m.homeTeamId)} vs ${nameOf(m.awayTeamId)}'),
                    subtitle: m.penaltyWinnerId != null
                        ? Text('PK戦: ${nameOf(m.penaltyWinnerId!)}が勝利')
                        : null,
                    trailing: m.result == null
                        ? const Text('未消化')
                        : Text(
                            '${m.result!.homeGoals} - ${m.result!.awayGoals}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _playNext(BuildContext context, CupType type) async {
    final gameState = context.read<GameState>();
    final userId = gameState.userTeam.id;
    final List<Team> teams = gameState.allTeamsForCups;
    final cup = type == CupType.domestic
        ? gameState.domesticCup
        : gameState.continentalCup;
    final match = cup?.nextUnplayedMatch;
    final isUserMatch = match != null &&
        (match.homeTeamId == userId || match.awayTeamId == userId);
    final result = await gameState.playNextCupMatch(type);
    if (!context.mounted) return;
    if (result != null && isUserMatch) {
      Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) =>
                MatchScreen(result: result, teams: teams, title: type.label)),
      );
    }
  }
}

/// カップ戦の1ラウンド分をまとめる折りたたみ可能なセクション。
/// 消化済みの過去ラウンドはデフォルトで畳んでおき、画面のスクロール量を抑える。
class _RoundSection extends StatelessWidget {
  final String title;
  final bool initiallyExpanded;
  final List<Widget> children;

  const _RoundSection({
    required this.title,
    required this.initiallyExpanded,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 4),
        title: Text(title, style: Theme.of(context).textTheme.titleSmall),
        children: children,
      ),
    );
  }
}
