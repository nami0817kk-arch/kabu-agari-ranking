import 'dart:math';
import '../models/player.dart';
import '../models/team.dart';

enum TrainingFocus { attack, defense, fitness, rest }

extension TrainingFocusLabel on TrainingFocus {
  String get label {
    switch (this) {
      case TrainingFocus.attack:
        return '攻撃強化';
      case TrainingFocus.defense:
        return '守備強化';
      case TrainingFocus.fitness:
        return '体力強化';
      case TrainingFocus.rest:
        return '休養';
    }
  }

  String get description {
    switch (this) {
      case TrainingFocus.attack:
        return 'FW・MFの攻撃力と技術が伸びやすくなる。疲労はやや増加。';
      case TrainingFocus.defense:
        return 'DF・GKの守備力と技術が伸びやすくなる。疲労はやや増加。';
      case TrainingFocus.fitness:
        return '全選手のスタミナが伸びやすくなる。疲労は少し増加。';
      case TrainingFocus.rest:
        return '疲労を大きく回復し、士気も上がる。成長は控えめ。';
    }
  }
}

class TrainingEngine {
  static final Random _rng = Random();

  static void applyWeeklyTraining(Team team, TrainingFocus focus) {
    for (final p in team.players) {
      switch (focus) {
        case TrainingFocus.attack:
          _grow(p, 'attack', (p.position == Position.fw || p.position == Position.mf) ? 0.5 : 0.15);
          _grow(p, 'technique', 0.25);
          p.fatigue = (p.fatigue + 12).clamp(0, 100);
          break;
        case TrainingFocus.defense:
          _grow(p, 'defense', (p.position == Position.df || p.position == Position.gk) ? 0.5 : 0.15);
          _grow(p, 'technique', 0.2);
          p.fatigue = (p.fatigue + 12).clamp(0, 100);
          break;
        case TrainingFocus.fitness:
          _grow(p, 'stamina', 0.45);
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
  }

  static void _grow(Player p, String stat, double chance) {
    var c = chance;
    if (p.age > 30) c *= 0.4;
    if (_rng.nextDouble() > c) return;
    final current = p.statValue(stat);
    if (current >= p.potential) return;
    p.setStatValue(stat, (current + 1).clamp(1, p.potential));
  }

  static void _decline(Player p) {
    const stats = ['attack', 'defense', 'technique', 'stamina'];
    final s = stats[_rng.nextInt(stats.length)];
    final current = p.statValue(s);
    p.setStatValue(s, (current - 1).clamp(20, 99));
  }
}
