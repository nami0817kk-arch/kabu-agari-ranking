import '../models/formation.dart';
import '../models/player.dart';
import '../models/team.dart';

class LineupUtils {
  /// フォーメーションの人数配分に沿って、負傷者を除く総合力上位の選手を
  /// 自動で先発に割り当てる。
  static void autoFill(Team team) {
    final formation = team.formation;
    final available = team.players.where((p) => !p.isInjured).toList();

    List<Player> pickBest(Position position, int count) {
      final candidates = available.where((p) => p.position == position).toList()
        ..sort((a, b) => b.overall.compareTo(a.overall));
      return candidates.take(count).toList();
    }

    final xi = <Player>[
      ...pickBest(Position.gk, formation.quotaFor(Position.gk)),
      ...pickBest(Position.df, formation.quotaFor(Position.df)),
      ...pickBest(Position.mf, formation.quotaFor(Position.mf)),
      ...pickBest(Position.fw, formation.quotaFor(Position.fw)),
    ];
    team.startingXI = xi.map((p) => p.id).toList();
  }
}
