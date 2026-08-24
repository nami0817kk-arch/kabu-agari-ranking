import 'player.dart';

class Team {
  final String id;
  String name;
  List<Player> players;
  final bool isUserTeam;

  Team({
    required this.id,
    required this.name,
    required this.players,
    this.isUserTeam = false,
  });

  int get overallRating {
    if (players.isEmpty) return 0;
    final sum = players.fold<int>(0, (s, p) => s + p.overall);
    return (sum / players.length).round();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isUserTeam': isUserTeam,
        'players': players.map((p) => p.toJson()).toList(),
      };

  factory Team.fromJson(Map<String, dynamic> json) => Team(
        id: json['id'] as String,
        name: json['name'] as String,
        isUserTeam: json['isUserTeam'] as bool? ?? false,
        players: (json['players'] as List)
            .map((e) => Player.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
