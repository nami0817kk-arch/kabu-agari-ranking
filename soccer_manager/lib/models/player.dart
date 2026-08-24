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
  });

  int get overall => ((attack + defense + technique + stamina) / 4).round();

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
      );
}
