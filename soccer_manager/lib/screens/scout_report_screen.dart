import 'package:flutter/material.dart';
import '../logic/scout_report_engine.dart';
import '../models/team.dart';
import '../widgets/club_emblem.dart';
import '../widgets/stat_bar.dart';

/// アシスタントコーチによる次節対戦相手のスカウティングレポート(試合プレビュー)画面。
class ScoutReportScreen extends StatelessWidget {
  final Team opponent;
  final Team userTeam;

  const ScoutReportScreen({super.key, required this.opponent, required this.userTeam});

  @override
  Widget build(BuildContext context) {
    final report = ScoutReportEngine.generateFor(opponent: opponent, userTeam: userTeam);

    return Scaffold(
      appBar: AppBar(title: const Text('スカウティングレポート')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ClubEmblem(teamId: opponent.id, teamName: opponent.name, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(report.opponentName, style: Theme.of(context).textTheme.titleLarge),
                        Text('平均総合力: ${report.opponentOverall}', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('スタメン想定の平均能力', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          StatBar(label: '攻撃力', value: report.opponentAttack),
          StatBar(label: '守備力', value: report.opponentDefense),
          StatBar(label: '技術', value: report.opponentTechnique),
          StatBar(label: 'スタミナ', value: report.opponentStamina),
          const Divider(height: 32),
          if (report.strengths.isNotEmpty) ...[
            Text('相手の強み', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final s in report.strengths)
                  Chip(
                    label: Text(s),
                    backgroundColor: Colors.redAccent,
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (report.weaknesses.isNotEmpty) ...[
            Text('相手の弱み', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final w in report.weaknesses)
                  Chip(
                    label: Text(w),
                    backgroundColor: Colors.green,
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (report.keyPlayerName != null) ...[
            Text('注意すべき選手', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.star, color: Colors.amber),
                title: Text(report.keyPlayerName!),
                subtitle: Text(report.keyPlayerDetail ?? ''),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text('アシスタントコーチからの提言', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline),
                  const SizedBox(width: 12),
                  Expanded(child: Text(report.recommendation)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
