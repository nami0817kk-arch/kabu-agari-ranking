import '../models/league.dart';
import '../models/match_result.dart';
import '../models/season_award.dart';

class AwardsEngine {
  /// 完了した全試合の得点イベントから選手ごとの得点数を集計する。
  static Map<String, int> _goalsByPlayer(League league) {
    final goals = <String, int>{};
    for (final f in league.fixtures) {
      final result = f.result;
      if (result == null) continue;
      for (final e in result.events) {
        if (e.type == MatchEventType.goal && e.scorerId != null) {
          goals[e.scorerId!] = (goals[e.scorerId!] ?? 0) + 1;
        }
      }
    }
    return goals;
  }

  /// シーズン終了時に得点王・年間MVPを確定する。得点イベントが1件もない場合はnullを返す項目もある。
  static SeasonAward computeAwards(League league, int season) {
    final goals = _goalsByPlayer(league);

    String? topScorerId;
    int topScorerGoals = 0;
    for (final entry in goals.entries) {
      if (entry.value > topScorerGoals) {
        topScorerGoals = entry.value;
        topScorerId = entry.key;
      }
    }

    String? topScorerName;
    String? topScorerTeamName;
    if (topScorerId != null) {
      for (final t in league.teams) {
        for (final p in t.players) {
          if (p.id == topScorerId) {
            topScorerName = p.name;
            topScorerTeamName = t.name;
          }
        }
      }
    }

    // 年間MVP: レギュラー(スタメン)級の選手の中から、総合力に得点数を加味した
    // スコアが最も高い選手を選ぶ簡易的なヒューリスティック。
    String? mvpName;
    String? mvpTeamName;
    double bestScore = -1;
    for (final t in league.teams) {
      for (final p in t.players) {
        if (!t.startingXI.contains(p.id)) continue;
        final score = p.overall.toDouble() + (goals[p.id] ?? 0) * 2;
        if (score > bestScore) {
          bestScore = score;
          mvpName = p.name;
          mvpTeamName = t.name;
        }
      }
    }

    return SeasonAward(
      season: season,
      topScorerName: topScorerName,
      topScorerTeamName: topScorerTeamName,
      topScorerGoals: topScorerGoals,
      mvpName: mvpName,
      mvpTeamName: mvpTeamName,
    );
  }
}
