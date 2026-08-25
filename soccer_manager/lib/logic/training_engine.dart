import 'dart:math';
import '../models/attributes.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../models/training_focus.dart';

export '../models/training_focus.dart';

class TrainingEngine {
  static final Random _rng = Random();

  /// チームの全選手にトレーニングを適用する。個別方針が設定されている選手は
  /// それを優先し、未設定の選手はチームの既定方針に従う。
  static void applyWeeklyTraining(Team team) {
    for (final p in team.players) {
      final focus = p.individualFocus ?? team.defaultTrainingFocus;
      _applyToPlayer(p, focus);
    }
  }

  static void _applyToPlayer(Player p, TrainingFocus focus) {
    switch (focus) {
      case TrainingFocus.attack:
        final primary = (p.position == Position.fw || p.position == Position.mf) ? 0.5 : 0.15;
        for (final k in [
          AttributeKeys.finishing,
          AttributeKeys.longShots,
          AttributeKeys.dribbling,
          AttributeKeys.offTheBall,
        ]) {
          _grow(p, k, primary);
        }
        for (final k in [AttributeKeys.passing, AttributeKeys.firstTouch, AttributeKeys.technique]) {
          _grow(p, k, 0.25);
        }
        p.fatigue = (p.fatigue + 12).clamp(0, 100);
        break;
      case TrainingFocus.defense:
        final primary = (p.position == Position.df || p.position == Position.gk) ? 0.5 : 0.15;
        for (final k in [
          AttributeKeys.tackling,
          AttributeKeys.marking,
          AttributeKeys.positioning,
          AttributeKeys.anticipation,
        ]) {
          _grow(p, k, primary);
        }
        for (final k in [AttributeKeys.passing, AttributeKeys.firstTouch, AttributeKeys.technique]) {
          _grow(p, k, 0.2);
        }
        p.fatigue = (p.fatigue + 12).clamp(0, 100);
        break;
      case TrainingFocus.fitness:
        for (final k in [
          AttributeKeys.stamina,
          AttributeKeys.naturalFitness,
          AttributeKeys.acceleration,
          AttributeKeys.strength,
        ]) {
          _grow(p, k, 0.45);
        }
        p.fatigue = (p.fatigue + 6).clamp(0, 100);
        break;
      case TrainingFocus.rest:
        p.fatigue = (p.fatigue - 30).clamp(0, 100);
        p.morale = (p.morale + 8).clamp(0, 100);
        break;
    }
    p.fatigue = (p.fatigue - 5).clamp(0, 100);
    if (p.age >= 31 && _rng.nextDouble() < 0.1) {
      _decline(p);
    }
  }

  static void _grow(Player p, String key, double chance) {
    var c = chance;
    if (p.age > 30) c *= 0.4;
    if (_rng.nextDouble() > c) return;
    final current = p.attributeValue(key);
    if (current >= p.potential) return;
    p.setAttributeValue(key, (current + 1).clamp(1, p.potential));
  }

  static void _decline(Player p) {
    final key = AttributeKeys.all[_rng.nextInt(AttributeKeys.all.length)];
    final current = p.attributeValue(key);
    p.setAttributeValue(key, (current - 1).clamp(20, 99));
  }
}
