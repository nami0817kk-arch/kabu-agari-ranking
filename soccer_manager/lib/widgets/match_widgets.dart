import 'package:flutter/material.dart';
import '../models/match_result.dart';
import '../models/team.dart';
import '../theme/semantic_colors.dart';
import 'club_emblem.dart';

/// 試合画面上部に表示するチームの見出し(エンブレム付きの名称)。
class TeamHeader extends StatelessWidget {
  final Team team;

  const TeamHeader({super.key, required this.team});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClubEmblem(teamId: team.id, teamName: team.name, size: 36),
        const SizedBox(height: 4),
        Text(team.name,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1),
      ],
    );
  }
}

/// 実況イベント1件分の表示行(得点・警告・退場など)。
class CommentaryTile extends StatelessWidget {
  final MatchEvent event;
  final String teamName;

  const CommentaryTile(
      {super.key, required this.event, required this.teamName});

  @override
  Widget build(BuildContext context) {
    final (icon, color, text) = switch (event.type) {
      MatchEventType.goal => (
          Icons.sports_soccer,
          SemanticColors.positive(context),
          '${event.scorerName ?? '???'} 得点！ ($teamName)'
        ),
      MatchEventType.chance => (
          Icons.flash_on,
          Colors.orange,
          '${event.scorerName ?? '???'} 惜しいシュート ($teamName)'
        ),
      MatchEventType.yellowCard => (
          Icons.warning_amber,
          Colors.amber,
          '${event.scorerName ?? '???'} に警告 ($teamName)'
        ),
      MatchEventType.redCard => (
          Icons.dangerous,
          Colors.redAccent,
          '${event.scorerName ?? '???'} が退場！ ($teamName)'
        ),
    };
    return ListTile(
      dense: true,
      leading: SizedBox(
        width: 44,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("${event.minute}'"),
            const SizedBox(width: 4),
            Icon(icon, size: 16, color: color),
          ],
        ),
      ),
      title: Text(text),
    );
  }
}

/// 試合終了時の勝敗を色分けして示すバナー(ユース目線での勝敗)。
class FullTimeBanner extends StatelessWidget {
  final String userTeamId;
  final MatchResult? result;

  const FullTimeBanner(
      {super.key, required this.userTeamId, required this.result});

  @override
  Widget build(BuildContext context) {
    final r = result;
    if (r == null) return const SizedBox.shrink();
    final userIsHome = r.homeTeamId == userTeamId;
    final userGoals = userIsHome ? r.homeGoals : r.awayGoals;
    final oppGoals = userIsHome ? r.awayGoals : r.homeGoals;

    final String label;
    final Color color;
    final IconData icon;
    if (userGoals > oppGoals) {
      label = '勝利';
      color = SemanticColors.positive(context);
      icon = Icons.emoji_events;
    } else if (userGoals < oppGoals) {
      label = '敗北';
      color = SemanticColors.negative(context);
      icon = Icons.sentiment_dissatisfied;
    } else {
      label = '引き分け';
      color = SemanticColors.neutral(context);
      icon = Icons.handshake;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
