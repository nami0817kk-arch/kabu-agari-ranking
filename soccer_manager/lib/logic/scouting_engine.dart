import 'dart:math';
import '../models/player.dart';
import 'player_generator.dart';

class ScoutingEngine {
  static final Random _rng = Random();

  static const int scoutCost = 300;
  static const int maxProspects = 6;

  /// スカウトのレベルが高いほど費用は下がる。
  static int scoutCostFor(int scoutLevel) => (scoutCost - (scoutLevel - 1) * 20).clamp(150, scoutCost);

  /// ユース施設のレベルが高いほど昇格候補の受け入れ枠が増える。
  static int maxProspectsFor(int youthFacilityLevel) => maxProspects + (youthFacilityLevel - 1);

  static Player _generateProspect({required int tierMin, required int tierMax}) {
    final position = Position.values[_rng.nextInt(Position.values.length)];
    final tier = tierMin + _rng.nextInt(tierMax - tierMin + 1);
    final age = 16 + _rng.nextInt(4);
    return PlayerGenerator.generate(position: position, strengthTier: tier, ageOverride: age);
  }

  /// シーズン終了時にアカデミーから無償で昇格候補が生まれる。ユースコーチのレベルが質を高める。
  static Player generateAcademyGraduate({int youthCoachLevel = 1}) {
    final bonus = (youthCoachLevel - 1) * 3;
    return _generateProspect(tierMin: 40 + bonus, tierMax: 70 + bonus);
  }

  /// 資金を払ってスカウトした有望株。アカデミー生より粒ぞろいで、スカウトのレベルが質を高める。
  static Player generateScoutedProspect({int scoutLevel = 1}) {
    final bonus = (scoutLevel - 1) * 3;
    return _generateProspect(tierMin: 55 + bonus, tierMax: 85 + bonus);
  }
}
