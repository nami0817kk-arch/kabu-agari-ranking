import 'dart:math';
import '../models/player.dart';
import '../models/team.dart';
import '../data/name_pool.dart';

class PlayerGenerator {
  static final Random _rng = Random();
  static int _idCounter = 0;

  static Player generate({required Position position, required int strengthTier}) {
    final id = 'pl${_idCounter++}';
    final age = 17 + _rng.nextInt(18);
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

    int attack = baseAbility;
    int defense = baseAbility;
    int technique = baseAbility;
    int stamina = baseAbility;

    switch (position) {
      case Position.gk:
        defense += 12;
        attack -= 30;
        technique -= 10;
        break;
      case Position.df:
        defense += 14;
        attack -= 14;
        break;
      case Position.mf:
        technique += 8;
        break;
      case Position.fw:
        attack += 14;
        defense -= 14;
        break;
    }

    attack = attack.clamp(20, 99);
    defense = defense.clamp(20, 99);
    technique = technique.clamp(20, 99);
    stamina = stamina.clamp(20, 99);

    return Player(
      id: id,
      name: NamePool.randomPlayerName(),
      age: age,
      position: position,
      attack: attack,
      defense: defense,
      technique: technique,
      stamina: stamina,
      potential: potential,
      fatigue: _rng.nextInt(15),
      morale: 65 + _rng.nextInt(25),
    );
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
