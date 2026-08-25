import 'formation.dart';
import 'player.dart';

class Team {
  final String id;
  String name;
  List<Player> players;
  final bool isUserTeam;
  Formation formation;

  /// 現在の先発11人（Player.id）。フォーメーションの人数配分と一致する。
  List<String> startingXI;

  Team({
    required this.id,
    required this.name,
    required this.players,
    this.isUserTeam = false,
    this.formation = Formation.f442,
    List<String>? startingXI,
  }) : startingXI = startingXI ?? [];

  int get overallRating {
    if (players.isEmpty) return 0;
    final sum = players.fold<int>(0, (s, p) => s + p.overall);
    return (sum / players.length).round();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isUserTeam': isUserTeam,
        'formation': formation.name,
        'startingXI': startingXI,
        'players': players.map((p) => p.toJson()).toList(),
      };

  factory Team.fromJson(Map<String, dynamic> json) => Team(
        id: json['id'] as String,
        name: json['name'] as String,
        isUserTeam: json['isUserTeam'] as bool? ?? false,
        formation: json['formation'] == null
            ? Formation.f442
            : Formation.values.byName(json['formation'] as String),
        startingXI: (json['startingXI'] as List?)?.map((e) => e as String).toList() ?? [],
        players: (json['players'] as List)
            .map((e) => Player.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
