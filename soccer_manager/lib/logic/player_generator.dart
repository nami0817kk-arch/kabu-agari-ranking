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

  static const _dfStrong = {
    AttributeKeys.tackling,
    AttributeKeys.marking,
    AttributeKeys.positioning,
    AttributeKeys.strength,
    AttributeKeys.heading,
    AttributeKeys.aggression,
    AttributeKeys.anticipation,
  };
  static const _dfWeak = {
    AttributeKeys.finishing,
    AttributeKeys.dribbling,
    AttributeKeys.longShots,
    AttributeKeys.flair,
  };

  static const _mfStrong = {
    AttributeKeys.passing,
    AttributeKeys.vision,
    AttributeKeys.firstTouch,
    AttributeKeys.technique,
    AttributeKeys.workRate,
    AttributeKeys.stamina,
    AttributeKeys.decisions,
    AttributeKeys.teamwork,
  };

  static const _fwStrong = {
    AttributeKeys.finishing,
    AttributeKeys.longShots,
    AttributeKeys.dribbling,
    AttributeKeys.offTheBall,
    AttributeKeys.pace,
    AttributeKeys.acceleration,
    AttributeKeys.composure,
    AttributeKeys.flair,
  };
  static const _fwWeak = {
    AttributeKeys.tackling,
    AttributeKeys.marking,
  };

  static int _positionBonus(String key, Position position) {
    switch (position) {
      case Position.gk:
        if (_gkStrong.contains(key)) return 25;
        if (_gkModestDefensive.contains(key)) return 5;
        if (_gkWeakOutfield.contains(key)) return -20;
        return -5;
      case Position.df:
        if (AttributeKeys.goalkeeping.contains(key)) return -40;
        if (_dfStrong.contains(key)) return 15;
        if (_dfWeak.contains(key)) return -10;
        return 0;
      case Position.mf:
        if (AttributeKeys.goalkeeping.contains(key)) return -40;
        if (_mfStrong.contains(key)) return 12;
        return 0;
      case Position.fw:
        if (AttributeKeys.goalkeeping.contains(key)) return -40;
        if (_fwStrong.contains(key)) return 15;
        if (_fwWeak.contains(key)) return -10;
        return 0;
    }
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
      attributes: attributes,
      potential: potential,
      fatigue: _rng.nextInt(15),
      morale: 65 + _rng.nextInt(25),
    );
    player.wage = (player.marketValue / 40).round().clamp(5, 500);
    player.contractWeeksRemaining = 15 + _rng.nextInt(30);
    return player;
  }

  static Team generateSquad({
    required String id,
    required String name,
    required int strengthTier,
    bool isUserTeam = false,
  }) {
    final players = <Player>[];
    for (int i = 0; i < 2; i++) {
      players.add(generate(position: Position.gk, strengthTier: strengthTier));
    }
    for (int i = 0; i < 6; i++) {
      players.add(generate(position: Position.df, strengthTier: strengthTier));
    }
    for (int i = 0; i < 6; i++) {
      players.add(generate(position: Position.mf, strengthTier: strengthTier));
    }
    for (int i = 0; i < 4; i++) {
      players.add(generate(position: Position.fw, strengthTier: strengthTier));
    }
    return Team(id: id, name: name, players: players, isUserTeam: isUserTeam);
  }
}
