import 'dart:math';
import '../models/player.dart';
import '../models/team.dart';

/// シーズン終了時の高齢選手の引退判定。
class RetirementEngine {
  static final Random _rng = Random();

  /// 31歳未満は引退しない。以降は年齢とともに引退確率が上がるが、
  /// 総合力が高い選手ほど現役を長く続けやすい。
  static double retirementChance(Player p) {
    if (p.age < 32) return 0.0;
    final ageFactor = (p.age - 31) * 0.12;
    final skillRelief = (p.overall - 50).clamp(0, 40) * 0.005;
    return (ageFactor - skillRelief).clamp(0.0, 0.9);
  }

  /// チームの引退対象者を判定し、スカッドから除外して返す(呼び出し側で
  /// 殿堂入りの記録などに使う)。
  static List<Player> resolveRetirements(Team team) {
    final retirees = <Player>[];
    for (final p in List<Player>.from(team.players)) {
      if (_rng.nextDouble() < retirementChance(p)) {
        retirees.add(p);
      }
    }
    for (final p in retirees) {
      team.players.remove(p);
      team.startingXI.remove(p.id);
    }
    return retirees;
  }
}
