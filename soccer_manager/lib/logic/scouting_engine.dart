import 'dart:math';
import '../models/player.dart';
import 'player_generator.dart';

class ScoutingEngine {
  static final Random _rng = Random();

  static const int scoutCost = 300;
  static const int maxProspects = 6;

  static Player _generateProspect({required int tierMin, required int tierMax}) {
    final position = Position.values[_rng.nextInt(Position.values.length)];
    final tier = tierMin + _rng.nextInt(tierMax - tierMin + 1);
    final age = 16 + _rng.nextInt(4);
    return PlayerGenerator.generate(position: position, strengthTier: tier, ageOverride: age);
  }

  /// シーズン終了時にアカデミーから無償で昇格候補が生まれる。
  static Player generateAcademyGraduate() => _generateProspect(tierMin: 40, tierMax: 70);

  /// 資金を払ってスカウトした有望株。アカデミー生より粒ぞろい。
  static Player generateScoutedProspect() => _generateProspect(tierMin: 55, tierMax: 85);
}
