import '../models/player.dart';
import '../models/team.dart';

class ContractEngine {
  static int weeklyWageBill(Team team) => team.players.fold<int>(0, (s, p) => s + p.wage);

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

  /// 契約更新にかかる費用（万円）。ローン選手には適用されない。
  static int renewalCost(Player p) => (p.marketValue * 0.5).round();

  static const int renewalWeeks = 40;

  static void renewContract(Player p) {
    p.contractWeeksRemaining = renewalWeeks;
  }
}
