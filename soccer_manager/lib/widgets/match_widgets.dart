import 'package:flutter/material.dart';
import '../models/match_result.dart';
import '../models/team.dart';
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
        Text(team.name, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, maxLines: 1),
      ],
    );
  }
}

/// 実況イベント1件分の表示行(得点・警告・退場など)。
class CommentaryTile extends StatelessWidget {
  final MatchEvent event;
  final String teamName;

  const CommentaryTile({super.key, required this.event, required this.teamName});

  @override
  Widget build(BuildContext context) {
    final (icon, color, text) = switch (event.type) {
      MatchEventType.goal => (Icons.sports_soccer, Colors.green, '${event.scorerName ?? '???'} 得点！ ($teamName)'),
      MatchEventType.chance => (Icons.flash_on, Colors.orange, '${event.scorerName ?? '???'} 惜しいシュート ($teamName)'),
      MatchEventType.yellowCard => (Icons.warning_amber, Colors.amber, '${event.scorerName ?? '???'} に警告 ($teamName)'),
      MatchEventType.redCard => (Icons.dangerous, Colors.redAccent, '${event.scorerName ?? '???'} が退場！ ($teamName)'),
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
