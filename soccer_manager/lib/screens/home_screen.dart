import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/formation.dart';
import '../models/league.dart';
import '../state/game_state.dart';
import '../services/feedback_service.dart';
import '../theme/semantic_colors.dart';
import '../widgets/busy_overlay.dart';
import '../widgets/club_emblem.dart';
import 'awards_screen.dart';
import 'club_screen.dart';
import 'cup_screen.dart';
import 'finance_screen.dart';
import 'live_match_screen.dart';
import 'manager_career_screen.dart';
import 'settings_screen.dart';
import 'scout_report_screen.dart';
import 'season_history_screen.dart';
import 'start_screen.dart';
import 'training_screen.dart';
import 'transfer_screen.dart';
import 'young_talent_screen.dart';
import 'youth_intake_screen.dart';
import 'youth_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final save = gameState.save;
    if (save == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (gameState.isDismissed) {
      return _DismissalScreen(clubName: save.clubName);
    }

    final scheme = Theme.of(context).colorScheme;
    final league = save.league;
    final userTeam = gameState.userTeam;
    final standings = league.sortedStandings;
    final userRank = standings.indexWhere((r) => r.teamId == userTeam.id) + 1;
    final next = league.nextUnplayedFixture;
    final seasonComplete = league.isSeasonComplete;
    final net = _netWeekly(gameState);

    return BusyOverlay(
      visible: gameState.isBusy,
      label: 'シーズンを更新しています…',
      child: Scaffold(
        appBar: AppBar(title: Text(save.clubName)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            '${gameState.leagueDisplayName} シーズン${league.season}',
                            style: Theme.of(context).textTheme.titleMedium),
                        Chip(label: Text(userTeam.formation.label)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('目標: ${save.boardTargetRank}位以内',
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.1,
              children: [
                _StatTile(
                  icon: Icons.emoji_events,
                  label: '順位',
                  value: '$userRank / ${standings.length}',
                  color: Colors.amber.shade800,
                ),
                _StatTile(
                  icon: Icons.account_balance_wallet,
                  label: '資金',
                  value: '${save.budget}万円',
                  sub: '週収支 ${net >= 0 ? '+' : ''}$net万円',
                  color: net >= 0
                      ? SemanticColors.positive(context)
                      : SemanticColors.negative(context),
                ),
                _StatTile(
                  icon: Icons.bar_chart,
                  label: '平均総合力',
                  value: '${userTeam.overallRating}',
                  color: Colors.blue.shade700,
                ),
                _StatTile(
                  icon: Icons.shield,
                  label: '監督への信頼度',
                  value: '${save.confidence}',
                  progress: save.confidence / 100,
                  color: save.confidence <= 25
                      ? Colors.redAccent
                      : Colors.teal.shade700,
                ),
                _StatTile(
                  icon: Icons.star,
                  label: '監督としての評価',
                  value: '${gameState.managerReputation}',
                  progress: gameState.managerReputation / 100,
                  color: Colors.deepPurple,
                ),
                _StatTile(
                  icon: Icons.groups,
                  label: '観客動員',
                  value:
                      '${gameState.lastMatchAttendance ?? gameState.expectedAttendance}人',
                  sub: '収容人数 ${gameState.stadiumCapacity}人',
                  color: Colors.brown.shade600,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (gameState.pendingPressConference != null)
              _PressConferenceCard(gameState: gameState),
            if (gameState.pendingJobOfferTeam != null)
              _JobOfferCard(gameState: gameState),
            if (gameState.pendingYouthIntake.isNotEmpty)
              Card(
                color: scheme.secondaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.emoji_people),
                  title: const Text('ユースインテーク'),
                  subtitle: Text(
                      '${gameState.pendingYouthIntake.length}名の新人候補が加入を待っています'),
                  trailing: FilledButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const YouthIntakeScreen())),
                    child: const Text('選抜する'),
                  ),
                ),
              ),
            if (gameState.incomingOffers.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('移籍オファー',
                          style: Theme.of(context).textTheme.titleSmall),
                      for (final o in gameState.incomingOffers)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                  child: Text(
                                      '${o.buyerClubName}が${o.playerName}に${o.amount}万円')),
                              TextButton(
                                onPressed: () {
                                  FeedbackService.tap();
                                  gameState.declineIncomingOffer(o.id);
                                },
                                child: const Text('拒否'),
                              ),
                              FilledButton(
                                onPressed: () {
                                  FeedbackService.success();
                                  gameState.acceptIncomingOffer(o.id);
                                },
                                child: const Text('承諾'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            if (!seasonComplete && save.friendlies.any((f) => f.result == null))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('親善試合',
                          style: Theme.of(context).textTheme.titleSmall),
                      for (int i = 0; i < save.friendlies.length; i++)
                        if (save.friendlies[i].result == null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                    child: Text(_fixtureLabel(
                                        league, save.friendlies[i]))),
                                OutlinedButton(
                                  onPressed: () => _playFriendly(context, i),
                                  child: const Text('開催'),
                                ),
                              ],
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            if (seasonComplete)
              Card(
                color: scheme.primaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.flag),
                  title: const Text('シーズン終了！'),
                  subtitle: Text('最終順位: $userRank位'),
                  trailing: FilledButton(
                    onPressed: () => _startNextSeason(context),
                    child: const Text('次のシーズンへ'),
                  ),
                ),
              )
            else if (next != null)
              Card(
                child: ListTile(
                  leading: ClubEmblem(
                    teamId: next.homeTeamId == userTeam.id
                        ? next.awayTeamId
                        : next.homeTeamId,
                    teamName: league.teams
                        .firstWhere((t) =>
                            t.id ==
                            (next.homeTeamId == userTeam.id
                                ? next.awayTeamId
                                : next.homeTeamId))
                        .name,
                    size: 40,
                  ),
                  title: Row(
                    children: [
                      Text('第${next.matchday}節'),
                      if (gameState.isRivalFixture(next)) ...[
                        const SizedBox(width: 6),
                        const Chip(
                          label: Text('ダービー', style: TextStyle(fontSize: 11)),
                          backgroundColor: Colors.redAccent,
                          labelStyle: TextStyle(color: Colors.white),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(_fixtureLabel(league, next)),
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilledButton(
                        onPressed: () => _playMatch(context),
                        child: const Text('試合を行う'),
                      ),
                      TextButton(
                        onPressed: () => _showScoutReport(context, next),
                        child: const Text('偵察レポート',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text('クラブ運営', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _ActionTile(
                  icon: Icons.fitness_center,
                  label: 'トレーニング',
                  color: Colors.deepOrange.shade400,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const TrainingScreen())),
                ),
                _ActionTile(
                  icon: Icons.swap_horiz,
                  label: '移籍市場',
                  color: Colors.indigo.shade400,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const TransferScreen())),
                ),
                _ActionTile(
                  icon: Icons.emoji_people,
                  label: 'ユース・スカウト',
                  color: Colors.teal.shade400,
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const YouthScreen())),
                ),
                _ActionTile(
                  icon: Icons.account_balance,
                  label: 'クラブ経営',
                  color: Colors.brown.shade400,
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FinanceScreen())),
                ),
                _ActionTile(
                  icon: Icons.apartment,
                  label: '施設・スタッフ',
                  color: Colors.blueGrey.shade400,
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ClubScreen())),
                ),
                _ActionTile(
                  icon: Icons.emoji_events,
                  label: 'カップ戦',
                  color: Colors.purple.shade400,
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CupScreen())),
                ),
                _ActionTile(
                  icon: Icons.military_tech,
                  label: '個人タイトル',
                  color: Colors.amber.shade700,
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AwardsScreen())),
                ),
                _ActionTile(
                  icon: Icons.workspace_premium,
                  label: '監督キャリア',
                  color: Colors.indigo.shade700,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ManagerCareerScreen())),
                ),
                _ActionTile(
                  icon: Icons.settings,
                  label: '設定',
                  color: Colors.blueGrey.shade700,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const SettingsScreen())),
                ),
                _ActionTile(
                  icon: Icons.stars,
                  label: '若手ランキング',
                  color: Colors.deepPurple.shade400,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const YoungTalentScreen())),
                ),
                _ActionTile(
                  icon: Icons.history,
                  label: 'シーズン成績',
                  color: Colors.teal.shade700,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const SeasonHistoryScreen())),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _netWeekly(GameState gameState) {
    final loanRepayment =
        gameState.bankLoans.fold<int>(0, (s, l) => s + l.weeklyRepayment);
    final team = gameState.userTeam;
    final appearanceFees = team.players
        .where((p) => team.startingXI.contains(p.id))
        .fold<int>(0, (s, p) => s + p.appearanceFee);
    return gameState.weeklyIncomeFor(team.id) -
        gameState.weeklyWageBill -
        loanRepayment -
        appearanceFees;
  }

  String _fixtureLabel(League league, Fixture f) {
    final home = league.teams.firstWhere((t) => t.id == f.homeTeamId).name;
    final away = league.teams.firstWhere((t) => t.id == f.awayTeamId).name;
    return '$home vs $away';
  }

  void _showScoutReport(BuildContext context, Fixture fixture) {
    final gameState = context.read<GameState>();
    final userTeam = gameState.userTeam;
    final league = gameState.save!.league;
    final opponentId = fixture.homeTeamId == userTeam.id
        ? fixture.awayTeamId
        : fixture.homeTeamId;
    final opponent = league.teams.firstWhere((t) => t.id == opponentId);
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) =>
              ScoutReportScreen(opponent: opponent, userTeam: userTeam)),
    );
  }

  Future<void> _playMatch(BuildContext context) async {
    FeedbackService.tap();
    final gameState = context.read<GameState>();
    final firstHalf = await gameState.playNextMatchday();
    if (!context.mounted) return;

    final expired = gameState.lastContractExpirations;
    if (expired.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('契約満了で退団: ${expired.join('、')}')),
      );
      gameState.lastContractExpirations = [];
    }
    final autoSold = gameState.lastReleaseClauseSales;
    if (autoSold.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('リリース条項が発動し移籍が成立: ${autoSold.join('、')}')),
      );
      gameState.lastReleaseClauseSales = [];
    }
    final calledUp = gameState.lastInternationalCallUps;
    if (calledUp.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('代表召集: ${calledUp.join('、')}')),
      );
      gameState.lastInternationalCallUps = [];
    }
    final loanReturns = gameState.lastLoanReturns;
    if (loanReturns.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ローン放出から復帰: ${loanReturns.join('、')}')),
      );
      gameState.lastLoanReturns = [];
    }
    final aiTransferNews = gameState.lastAiTransferNews;
    if (aiTransferNews != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('移籍市場: $aiTransferNews')),
      );
      gameState.lastAiTransferNews = null;
    }

    if (firstHalf != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LiveMatchScreen()),
      );
    }
  }

  Future<void> _playFriendly(BuildContext context, int index) async {
    final gameState = context.read<GameState>();
    final result = await gameState.playFriendly(index);
    if (context.mounted && result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('親善試合結果: ${result.homeGoals} - ${result.awayGoals}')),
      );
    }
  }

  Future<void> _startNextSeason(BuildContext context) async {
    final gameState = context.read<GameState>();
    await gameState.startNextSeason();
    final message = gameState.lastDivisionChangeMessage;
    if (context.mounted && message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
      );
      gameState.lastDivisionChangeMessage = null;
    }
    final retirees = gameState.lastRetirements;
    if (context.mounted && retirees.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('引退: ${retirees.join('、')}'),
          duration: const Duration(seconds: 5),
        ),
      );
      gameState.lastRetirements = [];
    }
  }
}

class _PressConferenceCard extends StatelessWidget {
  final GameState gameState;

  const _PressConferenceCard({required this.gameState});

  @override
  Widget build(BuildContext context) {
    final question = gameState.pendingPressConference!;
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mic, size: 18),
                const SizedBox(width: 6),
                Text('記者会見', style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 6),
            Text(question.prompt),
            const SizedBox(height: 8),
            for (int i = 0; i < question.options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      FeedbackService.tap();
                      gameState.answerPressConference(i);
                    },
                    child: Text(question.options[i].label,
                        textAlign: TextAlign.center),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _JobOfferCard extends StatelessWidget {
  final GameState gameState;

  const _JobOfferCard({required this.gameState});

  @override
  Widget build(BuildContext context) {
    final team = gameState.pendingJobOfferTeam!;
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('他クラブからのオファー', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text('${team.name}の監督就任オファーが届いています(総合力 ${team.overallRating})'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () {
                      FeedbackService.tap();
                      gameState.declineJobOffer();
                    },
                    child: const Text('断る')),
                const SizedBox(width: 8),
                FilledButton(
                    onPressed: () {
                      FeedbackService.success();
                      gameState.acceptJobOffer();
                    },
                    child: const Text('就任する')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final Color color;
  final double? progress;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.sub,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (sub != null)
            Text(sub!, style: TextStyle(fontSize: 11, color: color)),
          if (progress != null) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                  value: progress, minHeight: 6, color: color),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                  backgroundColor: color,
                  child: Icon(icon, color: Colors.white, size: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DismissalScreen extends StatelessWidget {
  final String clubName;

  const _DismissalScreen({required this.clubName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.gavel, size: 64, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(
                  '$clubName の監督を解任されました',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text('理事会からの信頼を失いました。', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () async {
                    await context.read<GameState>().deleteSave();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const StartScreen()),
                        (route) => false,
                      );
                    }
                  },
                  child: const Text('新しいクラブで再出発する'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
