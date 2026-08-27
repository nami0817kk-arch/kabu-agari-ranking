import 'package:flutter/material.dart';
import '../models/match_result.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../models/weather.dart';
import '../screens/player_detail_screen.dart';
import '../theme/semantic_colors.dart';
import 'club_emblem.dart';

/// 試合当日の天候を表示するバッジ。晴天以外は攻守・チャンス数への
/// 影響があることを示すため色を変えて目立たせる。
class WeatherBadge extends StatelessWidget {
  final Weather weather;

  const WeatherBadge({super.key, required this.weather});

  @override
  Widget build(BuildContext context) {
    final isClear = weather == Weather.clear;
    final color = isClear ? Colors.grey.shade600 : Colors.blueGrey.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(weather.emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(weather.label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

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
/// [userTeam]を渡すと、選手が現在も自クラブに在籍している場合に限り
/// タップして選手詳細画面へ遷移できる。
class CommentaryTile extends StatelessWidget {
  final MatchEvent event;
  final String teamName;
  final Team? userTeam;

  const CommentaryTile(
      {super.key, required this.event, required this.teamName, this.userTeam});

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
    String? playerId;
    if (userTeam != null && event.teamId == userTeam!.id) {
      for (final p in userTeam!.players) {
        if (p.id == event.scorerId) {
          playerId = p.id;
          break;
        }
      }
    }
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
      onTap: playerId == null
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PlayerDetailScreen(playerId: playerId!))),
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

/// 試合終了時に、その試合で最も採点の高かった選手をマン・オブ・ザ・マッチ
/// として表示するバナー。選手が自クラブ所属の場合はタップで選手詳細へ遷移できる。
class ManOfTheMatchBanner extends StatelessWidget {
  final MatchResult? result;
  final List<Team> teams;
  final String? userTeamId;

  const ManOfTheMatchBanner(
      {super.key, required this.result, required this.teams, this.userTeamId});

  @override
  Widget build(BuildContext context) {
    final r = result;
    if (r == null) return const SizedBox.shrink();
    final motmId = r.manOfTheMatchId;
    if (motmId == null) return const SizedBox.shrink();
    Player? motm;
    bool isOwnClub = false;
    for (final t in teams) {
      for (final p in t.players) {
        if (p.id == motmId) {
          motm = p;
          isOwnClub = t.id == userTeamId;
          break;
        }
      }
      if (motm != null) break;
    }
    if (motm == null) return const SizedBox.shrink();
    final rating = r.playerRatings[motmId];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: !isOwnClub
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PlayerDetailScreen(playerId: motmId))),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.military_tech, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('マン・オブ・ザ・マッチ: ${motm.name}',
                      overflow: TextOverflow.ellipsis),
                ),
                if (rating != null)
                  Text(rating.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
