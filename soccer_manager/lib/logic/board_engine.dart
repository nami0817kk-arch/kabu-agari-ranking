import '../models/league.dart';
import '../models/match_result.dart';

class BoardEngine {
  /// 現在のスカッド総合力から見て妥当な目標順位（1が最高位）を見積もる。
  static int estimateTargetRank(League league, String userTeamId) {
    final sorted = [...league.teams]
      ..sort((a, b) => b.overallRating.compareTo(a.overallRating));
    final idx = sorted.indexWhere((t) => t.id == userTeamId);
    return idx < 0 ? (league.teams.length / 2).ceil() : idx + 1;
  }

  /// 試合結果を受けて信頼度の増減量を返す。
  static int confidenceDeltaForMatch(MatchResult result, String userTeamId) {
    final isHome = result.homeTeamId == userTeamId;
    final userGoals = isHome ? result.homeGoals : result.awayGoals;
    final oppGoals = isHome ? result.awayGoals : result.homeGoals;
    if (userGoals > oppGoals) return 4;
    if (userGoals == oppGoals) return -1;
    return -6;
  }

  /// シーズン終了時の順位評価による信頼度の増減量を返す。
  static int confidenceDeltaForSeasonEnd({required int finalRank, required int targetRank}) {
    if (finalRank <= targetRank) return 15;
    if (finalRank > targetRank + 2) return -20;
    return 0;
  }

  /// 最終順位に応じた賞金（万円）。
  static int seasonPrizeMoney({required int finalRank, required int teamCount}) {
    final worst = teamCount;
    final ratio = worst <= 1 ? 1.0 : 1 - (finalRank - 1) / (worst - 1);
    return (300 + ratio * 2700).round();
  }
}
