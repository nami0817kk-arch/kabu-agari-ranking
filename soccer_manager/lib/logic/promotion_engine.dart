import '../models/league.dart';
import '../models/team.dart';
import 'fixture_generator.dart';
import 'match_engine.dart';

/// シーズン終了時の昇格・降格を解決した結果。
class PromotionResult {
  final List<Team> tier1;
  final List<Team> tier2;
  final List<String> promotedTeamNames;
  final List<String> relegatedTeamNames;

  const PromotionResult({
    required this.tier1,
    required this.tier2,
    required this.promotedTeamNames,
    required this.relegatedTeamNames,
  });
}

/// 1部・2部の入れ替え(昇格/降格)を解決する。
///
/// ユーザーが所属しない側のディビジョンは週次で試合を進行させないため、シーズン
/// 終了時にその場で1シーズン分をまとめてシミュレートし、最終順位を確定する。
class PromotionEngine {
  static const int swapCount = 3;

  /// [teams]で1シーズン分(ホーム&アウェイ総当たり)を即座にシミュレートし、
  /// 最終順位順に並べ替えて返す。
  static List<Team> _simulateSeason(List<Team> teams) {
    final fixtures = FixtureGenerator.generateDoubleRoundRobin(teams);
    for (final f in fixtures) {
      final home = teams.firstWhere((t) => t.id == f.homeTeamId);
      final away = teams.firstWhere((t) => t.id == f.awayTeamId);
      f.result = MatchEngine.simulate(home: home, away: away, matchday: f.matchday);
    }
    final standings = League(teams: teams, fixtures: fixtures).sortedStandings;
    return standings.map((row) => teams.firstWhere((t) => t.id == row.teamId)).toList();
  }

  /// [tier1Teams]/[tier2Teams]は今シーズンの各ディビジョンの全チーム。実際に
  /// プレイされた側は[tier1PlayedOrder]/[tier2PlayedOrder]に最終順位順のチーム
  /// リストを渡す(片方のみ非null)。渡されなかった側はその場でシミュレートする。
  static PromotionResult resolve({
    required List<Team> tier1Teams,
    required List<Team> tier2Teams,
    List<Team>? tier1PlayedOrder,
    List<Team>? tier2PlayedOrder,
  }) {
    final orderedTier1 = tier1PlayedOrder ?? _simulateSeason(tier1Teams);
    final orderedTier2 = tier2PlayedOrder ?? _simulateSeason(tier2Teams);

    final relegated = orderedTier1.sublist(orderedTier1.length - swapCount);
    final promoted = orderedTier2.sublist(0, swapCount);

    final newTier1 = [...orderedTier1.take(orderedTier1.length - swapCount), ...promoted];
    final newTier2 = [...orderedTier2.skip(swapCount), ...relegated];

    return PromotionResult(
      tier1: newTier1,
      tier2: newTier2,
      promotedTeamNames: promoted.map((t) => t.name).toList(),
      relegatedTeamNames: relegated.map((t) => t.name).toList(),
    );
  }
}
