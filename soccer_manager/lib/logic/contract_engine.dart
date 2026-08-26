import '../models/player.dart';
import '../models/team.dart';

class ContractEngine {
  /// 週俸総額。他クラブへローン放出中の選手は放出先が週俸を負担するため含めない。
  static int weeklyWageBill(Team team) => team.players
      .where((p) => !p.isLoanedOut)
      .fold<int>(0, (s, p) => s + p.wage);

  /// 契約(またはローン期間)を1週分消化させ、契約切れ・ローン満了となった
  /// 選手をチームから除外する。除外された選手のリストを返す（UI通知用）。
  static List<Player> advanceWeek(Team team) {
    final expired = <Player>[];
    for (final p in List<Player>.from(team.players)) {
      if (p.isLoan) {
        if (p.loanWeeksRemaining > 0) {
          p.loanWeeksRemaining -= 1;
        }
        if (p.loanWeeksRemaining <= 0) {
          expired.add(p);
        }
        continue;
      }
      if (p.contractWeeksRemaining > 0) {
        p.contractWeeksRemaining -= 1;
      }
      if (p.contractWeeksRemaining <= 0) {
        expired.add(p);
      }
    }
    for (final p in expired) {
      team.players.remove(p);
      team.startingXI.remove(p.id);
    }
    return expired;
  }

  /// 契約更新にかかる基本費用（万円）。ローン選手には適用されない。
  static int renewalCost(Player p) => (p.marketValue * 0.5).round();

  /// 契約更新時に一括で要求されるサインボーナス（万円）。野心家など要求水準が
  /// 高い性格ほど高額になる。
  static int signingBonusFor(Player p) =>
      (p.marketValue * 0.12 * p.personality.wageSensitivity).round();

  /// リーグ公式戦にスタメン出場するたびに支払われる出場手当（万円）。
  static int appearanceFeeFor(Player p) =>
      (p.overall * 0.5 * p.personality.wageSensitivity).round().clamp(1, 60);

  static const int renewalWeeks = 40;

  static void renewContract(Player p) {
    p.contractWeeksRemaining = renewalWeeks;
    p.appearanceFee = appearanceFeeFor(p);
  }

  /// 契約交渉で選手が受け入れる最低週俸(万円)。要求水準が高い性格ほど、
  /// より大きな昇給を求める。
  static int minimumAcceptableWage(Player p) =>
      (p.wage * (1.05 + p.personality.wageSensitivity * 0.15)).round();

  /// この回数を超えて折り合わない場合、選手は交渉から離脱する。
  static const int maxNegotiationRounds = 3;

  /// クラブの提示額を拒否した際に選手側が出す対案(万円)。
  /// 最低希望額よりやや高めに構え、徐々に譲歩していく。
  static int counterOffer(Player p, int rejectedOffer) {
    final minAcceptable = minimumAcceptableWage(p);
    final demand = ((rejectedOffer + minAcceptable * 1.15) / 2).round();
    return demand < minAcceptable ? minAcceptable : demand;
  }
}
