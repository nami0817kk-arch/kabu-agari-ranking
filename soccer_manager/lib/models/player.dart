import 'dart:math';

enum Position { gk, df, mf, fw }

extension PositionLabel on Position {
  String get label {
    switch (this) {
      case Position.gk:
        return 'GK';
      case Position.df:
        return 'DF';
      case Position.mf:
        return 'MF';
      case Position.fw:
        return 'FW';
    }
  }
}

class Player {
  final String id;
  String name;
  int age;
  Position position;
  int attack;
  int defense;
  int technique;
  int stamina;
  int potential;
  int fatigue;
  int morale;
  int injuryWeeks;

  Player({
    required this.id,
    required this.name,
    required this.age,
    required this.position,
    required this.attack,
    required this.defense,
    required this.technique,
    required this.stamina,
    required this.potential,
    this.fatigue = 0,
    this.morale = 75,
    this.injuryWeeks = 0,
  });

  int get overall => ((attack + defense + technique + stamina) / 4).round();

  bool get isInjured => injuryWeeks > 0;

  /// 想定移籍金（万円）。年齢・現在能力・伸びしろから概算する。
  int get marketValue {
    final ovr = (overall - 40).clamp(0, 60);
    final base = pow(ovr, 1.8) * 3;
    final potentialBonus = (potential - overall).clamp(0, 40) * 15;
    double ageFactor;
    if (age <= 21) {
      ageFactor = 1.4;
    } else if (age <= 27) {
      ageFactor = 1.1;
    } else if (age <= 30) {
      ageFactor = 0.8;
    } else {
      ageFactor = 0.4;
    }
    final value = (base + potentialBonus) * ageFactor;
    return value.round().clamp(50, 20000);
  }

  int statValue(String stat) {
    switch (stat) {
      case 'attack':
        return attack;
      case 'defense':
        return defense;
      case 'technique':
        return technique;
      case 'stamina':
        return stamina;
      default:
        throw ArgumentError('unknown stat $stat');
    }
  }

  void setStatValue(String stat, int value) {
    switch (stat) {
      case 'attack':
        attack = value;
        break;
      case 'defense':
        defense = value;
        break;
      case 'technique':
        technique = value;
        break;
      case 'stamina':
        stamina = value;
        break;
      default:
        throw ArgumentError('unknown stat $stat');
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'age': age,
        'position': position.name,
        'attack': attack,
        'defense': defense,
        'technique': technique,
        'stamina': stamina,
        'potential': potential,
        'fatigue': fatigue,
        'morale': morale,
        'injuryWeeks': injuryWeeks,
      };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        id: json['id'] as String,
        name: json['name'] as String,
        age: json['age'] as int,
        position: Position.values.byName(json['position'] as String),
        attack: json['attack'] as int,
        defense: json['defense'] as int,
        technique: json['technique'] as int,
        stamina: json['stamina'] as int,
        potential: json['potential'] as int,
        fatigue: json['fatigue'] as int? ?? 0,
        morale: json['morale'] as int? ?? 75,
        injuryWeeks: json['injuryWeeks'] as int? ?? 0,
      );
}
