import 'dart:math';
import '../models/team.dart';

/// ユーザーが関与しないCPUクラブ同士の移籍市場を活性化させるための簡易エンジン。
/// 資金のやり取りは行わず、選手が移籍する「ニュース」のみを生成する。
class AiTransferEngine {
  static const double weeklyProbability = 0.35;

  /// 選手の実力(総合力)に対して、行き先クラブの平均総合力がこの値を下回って
  /// いなければ「実力に見合う移籍先」とみなす。
  static const int fitMargin = 5;

  /// [teams]の中からユーザークラブ([userTeamId])を除いたCPUクラブ同士で、
  /// 一定確率で1件の移籍を成立させる。成立した場合はニュース文言を返す。
  /// 移籍先は完全ランダムではなく、選手の実力に見合う(平均総合力が近い、
  /// または上回る)クラブを優先的に選ぶ。該当クラブがなければ全候補から選ぶ
  /// (格下クラブへの放出も一定割合で起こり得るようにする)。
  static String? maybeGenerate(
      List<Team> teams, String userTeamId, Random random) {
    if (random.nextDouble() > weeklyProbability) return null;

    final cpuTeams = teams.where((t) => t.id != userTeamId).toList()
      ..shuffle(random);
    if (cpuTeams.length < 2) return null;

    for (final fromTeam in cpuTeams) {
      // 選手層が薄いクラブからは引き抜かない。
      if (fromTeam.players.length <= 16) continue;
      final eligible = fromTeam.players
          .where((p) => !p.isLoanedOut && !p.isInjured)
          .toList();
      if (eligible.isEmpty) continue;

      eligible.shuffle(random);
      final player = eligible.first;

      final toCandidates = cpuTeams.where((t) => t.id != fromTeam.id).toList();
      if (toCandidates.isEmpty) continue;
      final fittingClubs = toCandidates
          .where((t) => t.overallRating >= player.overall - fitMargin)
          .toList();
      final pool = fittingClubs.isNotEmpty ? fittingClubs : toCandidates;
      final toTeam = pool[random.nextInt(pool.length)];

      fromTeam.players.remove(player);
      toTeam.players.add(player);
      player.contractWeeksRemaining = 40 + random.nextInt(40);
      player.happiness = 70;
      return '${player.name}が${fromTeam.name}から${toTeam.name}へ移籍しました。';
    }
    return null;
  }
}
