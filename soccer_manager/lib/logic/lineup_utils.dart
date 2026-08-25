import '../models/formation.dart';
import '../models/player.dart';
import '../models/team.dart';

class LineupUtils {
  /// フォーメーションの各スロットに、負傷者を除く総合力上位の選手を自動で割り当てる。
  /// スロットと同じポジションの選手を優先し、いなければ副ポジションが一致する選手、
  /// それも足りなければ同じ大分類(GK/DEF/MID/ATT)の選手、それでも足りなければ
  /// 残りの中で総合力が最も高い選手で埋める。
  static void autoFill(Team team) {
    final formation = team.formation;
    final available = team.players.where((p) => !p.isInjured).toList();
    final used = <Player>{};

    List<Player> candidatesFor(Position slot) {
      final exact = available.where((p) => !used.contains(p) && p.position == slot).toList();
      if (exact.isNotEmpty) return exact;
      final secondary =
          available.where((p) => !used.contains(p) && p.secondaryPositions.contains(slot)).toList();
      if (secondary.isNotEmpty) return secondary;
      final sameGroup =
          available.where((p) => !used.contains(p) && p.position.group == slot.group).toList();
      if (sameGroup.isNotEmpty) return sameGroup;
      return available.where((p) => !used.contains(p)).toList();
    }

    final xi = <Player>[];
    for (final slot in formation.slots) {
      final candidates = candidatesFor(slot)..sort((a, b) => b.overall.compareTo(a.overall));
      if (candidates.isEmpty) continue;
      final chosen = candidates.first;
      used.add(chosen);
      xi.add(chosen);
    }
    team.startingXI = xi.map((p) => p.id).toList();
  }
}
