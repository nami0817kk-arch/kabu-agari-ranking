import 'dart:math';
import '../models/attributes.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../data/name_pool.dart';

class PlayerGenerator {
  static final Random _rng = Random();
  static int _idCounter = 0;

  static const _gkStrong = {
    AttributeKeys.handling,
    AttributeKeys.reflexes,
    AttributeKeys.commandOfArea,
    AttributeKeys.aerialReach,
    AttributeKeys.kicking,
    AttributeKeys.oneOnOnes,
  };
  static const _gkWeakOutfield = {
    AttributeKeys.finishing,
    AttributeKeys.longShots,
    AttributeKeys.dribbling,
    AttributeKeys.crossing,
    AttributeKeys.pace,
    AttributeKeys.acceleration,
  };
  static const _gkModestDefensive = {
    AttributeKeys.tackling,
    AttributeKeys.marking,
    AttributeKeys.positioning,
    AttributeKeys.anticipation,
    AttributeKeys.concentration,
  };

  static const Map<Position, Set<String>> _strongByPosition = {
    Position.dc: {
      AttributeKeys.tackling, AttributeKeys.marking, AttributeKeys.positioning,
      AttributeKeys.strength, AttributeKeys.heading, AttributeKeys.aggression,
      AttributeKeys.anticipation, AttributeKeys.bravery,
    },
    Position.dr: {
      AttributeKeys.tackling, AttributeKeys.marking, AttributeKeys.crossing,
      AttributeKeys.pace, AttributeKeys.acceleration, AttributeKeys.stamina,
      AttributeKeys.workRate, AttributeKeys.positioning,
    },
    Position.dl: {
      AttributeKeys.tackling, AttributeKeys.marking, AttributeKeys.crossing,
      AttributeKeys.pace, AttributeKeys.acceleration, AttributeKeys.stamina,
      AttributeKeys.workRate, AttributeKeys.positioning,
    },
    Position.wbr: {
      AttributeKeys.crossing, AttributeKeys.pace, AttributeKeys.acceleration,
      AttributeKeys.stamina, AttributeKeys.workRate, AttributeKeys.dribbling,
      AttributeKeys.tackling,
    },
    Position.wbl: {
      AttributeKeys.crossing, AttributeKeys.pace, AttributeKeys.acceleration,
      AttributeKeys.stamina, AttributeKeys.workRate, AttributeKeys.dribbling,
      AttributeKeys.tackling,
    },
    Position.dm: {
      AttributeKeys.tackling, AttributeKeys.marking, AttributeKeys.positioning,
      AttributeKeys.passing, AttributeKeys.anticipation, AttributeKeys.workRate,
      AttributeKeys.teamwork, AttributeKeys.decisions,
    },
    Position.mr: {
      AttributeKeys.passing, AttributeKeys.crossing, AttributeKeys.dribbling,
      AttributeKeys.pace, AttributeKeys.stamina, AttributeKeys.workRate,
      AttributeKeys.technique, AttributeKeys.firstTouch,
    },
    Position.ml: {
      AttributeKeys.passing, AttributeKeys.crossing, AttributeKeys.dribbling,
      AttributeKeys.pace, AttributeKeys.stamina, AttributeKeys.workRate,
      AttributeKeys.technique, AttributeKeys.firstTouch,
    },
    Position.mc: {
      AttributeKeys.passing, AttributeKeys.vision, AttributeKeys.firstTouch,
      AttributeKeys.technique, AttributeKeys.decisions, AttributeKeys.stamina,
      AttributeKeys.workRate, AttributeKeys.teamwork,
    },
    Position.amr: {
      AttributeKeys.dribbling, AttributeKeys.pace, AttributeKeys.crossing,
      AttributeKeys.finishing, AttributeKeys.flair, AttributeKeys.offTheBall,
      AttributeKeys.technique, AttributeKeys.acceleration,
    },
    Position.aml: {
      AttributeKeys.dribbling, AttributeKeys.pace, AttributeKeys.crossing,
      AttributeKeys.finishing, AttributeKeys.flair, AttributeKeys.offTheBall,
      AttributeKeys.technique, AttributeKeys.acceleration,
    },
    Position.amc: {
      AttributeKeys.passing, AttributeKeys.vision, AttributeKeys.technique,
      AttributeKeys.decisions, AttributeKeys.flair, AttributeKeys.finishing,
      AttributeKeys.offTheBall, AttributeKeys.composure,
    },
    Position.st: {
      AttributeKeys.finishing, AttributeKeys.longShots, AttributeKeys.offTheBall,
      AttributeKeys.composure, AttributeKeys.pace, AttributeKeys.acceleration,
      AttributeKeys.flair, AttributeKeys.heading,
    },
  };

  static const Map<Position, Set<String>> _weakByPosition = {
    Position.dc: {
      AttributeKeys.dribbling, AttributeKeys.finishing, AttributeKeys.longShots,
      AttributeKeys.crossing, AttributeKeys.flair,
    },
    Position.dr: {AttributeKeys.finishing, AttributeKeys.heading},
    Position.dl: {AttributeKeys.finishing, AttributeKeys.heading},
    Position.wbr: {AttributeKeys.marking, AttributeKeys.heading},
    Position.wbl: {AttributeKeys.marking, AttributeKeys.heading},
    Position.dm: {AttributeKeys.finishing, AttributeKeys.flair},
    Position.mr: {AttributeKeys.tackling, AttributeKeys.heading},
    Position.ml: {AttributeKeys.tackling, AttributeKeys.heading},
    Position.mc: {AttributeKeys.finishing, AttributeKeys.pace},
    Position.amr: {AttributeKeys.tackling, AttributeKeys.marking, AttributeKeys.strength},
    Position.aml: {AttributeKeys.tackling, AttributeKeys.marking, AttributeKeys.strength},
    Position.amc: {AttributeKeys.tackling, AttributeKeys.marking, AttributeKeys.strength},
    Position.st: {AttributeKeys.tackling, AttributeKeys.marking, AttributeKeys.passing},
  };

  static const Map<Position, List<Position>> _secondaryCandidates = {
    Position.gk: [],
    Position.dr: [Position.wbr, Position.dc],
    Position.dc: [Position.dm],
    Position.dl: [Position.wbl, Position.dc],
    Position.wbr: [Position.dr, Position.mr],
    Position.wbl: [Position.dl, Position.ml],
    Position.dm: [Position.dc, Position.mc],
    Position.mr: [Position.wbr, Position.amr],
    Position.mc: [Position.dm, Position.amc],
    Position.ml: [Position.wbl, Position.aml],
    Position.amr: [Position.mr, Position.st],
    Position.amc: [Position.mc, Position.amr, Position.aml],
    Position.aml: [Position.ml, Position.st],
    Position.st: [Position.amc],
  };

  static int _positionBonus(String key, Position position) {
    if (position == Position.gk) {
      if (_gkStrong.contains(key)) return 25;
      if (_gkModestDefensive.contains(key)) return 5;
      if (_gkWeakOutfield.contains(key)) return -20;
      return -5;
    }
    if (AttributeKeys.goalkeeping.contains(key)) return -40;
    final strong = _strongByPosition[position] ?? const {};
    if (strong.contains(key)) return 15;
    final weak = _weakByPosition[position] ?? const {};
    if (weak.contains(key)) return -9;
    return 0;
  }

  static List<Position> _generateSecondaryPositions(Position position) {
    final candidates = _secondaryCandidates[position] ?? const [];
    if (candidates.isEmpty) return [];
    final roll = _rng.nextDouble();
    if (roll < 0.35) return [];
    final shuffled = [...candidates]..shuffle(_rng);
    final count = roll < 0.85 ? 1 : min(2, shuffled.length);
    return shuffled.take(count).toList();
  }

  static Player generate({
    required Position position,
    required int strengthTier,
    int? ageOverride,
  }) {
    final id = 'pl${_idCounter++}';
    final age = ageOverride ?? (17 + _rng.nextInt(18));
    final potential = (strengthTier + _rng.nextInt(21) - 10).clamp(40, 99);

    double ageFactor;
    if (age < 24) {
      ageFactor = 0.55 + (age - 17) * 0.045;
    } else if (age <= 29) {
      ageFactor = 0.9 + _rng.nextDouble() * 0.1;
    } else {
      ageFactor = (0.95 - (age - 29) * 0.03);
    }
    final baseAbility = (potential * ageFactor).round().clamp(25, 99);

    final attributes = <String, int>{};
    for (final key in AttributeKeys.all) {
      final variance = _rng.nextInt(17) - 8; // -8 〜 +8
      final value = baseAbility + _positionBonus(key, position) + variance;
      attributes[key] = value.clamp(1, 99);
    }

    final player = Player(
      id: id,
      name: NamePool.randomPlayerName(),
      age: age,
      position: position,
      secondaryPositions: _generateSecondaryPositions(position),
      attributes: attributes,
      potential: potential,
      fatigue: _rng.nextInt(15),
      morale: 65 + _rng.nextInt(25),
      personality: PlayerPersonality.values[_rng.nextInt(PlayerPersonality.values.length)],
      happiness: 55 + _rng.nextInt(30),
    );
    player.wage = (player.marketValue / 40).round().clamp(5, 500);
    player.contractWeeksRemaining = 15 + _rng.nextInt(30);
    return player;
  }

  /// 1チーム分のスカッド構成（計23名）。
  static const Map<Position, int> _squadComposition = {
    Position.gk: 2,
    Position.dc: 3,
    Position.dr: 2,
    Position.dl: 2,
    Position.wbr: 1,
    Position.wbl: 1,
    Position.dm: 2,
    Position.mc: 2,
    Position.mr: 1,
    Position.ml: 1,
    Position.amc: 1,
    Position.amr: 1,
    Position.aml: 1,
    Position.st: 3,
  };

  static Team generateSquad({
    required String id,
    required String name,
    required int strengthTier,
    bool isUserTeam = false,
  }) {
    final players = <Player>[];
    _squadComposition.forEach((position, count) {
      for (int i = 0; i < count; i++) {
        players.add(generate(position: position, strengthTier: strengthTier));
      }
    });
    return Team(id: id, name: name, players: players, isUserTeam: isUserTeam);
  }
}
