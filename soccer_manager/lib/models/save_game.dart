import 'league.dart';

class SaveGame {
  String clubName;
  String userTeamId;
  League league;

  SaveGame({
    required this.clubName,
    required this.userTeamId,
    required this.league,
  });

  Map<String, dynamic> toJson() => {
        'clubName': clubName,
        'userTeamId': userTeamId,
        'league': league.toJson(),
      };

  factory SaveGame.fromJson(Map<String, dynamic> json) => SaveGame(
        clubName: json['clubName'] as String,
        userTeamId: json['userTeamId'] as String,
        league: League.fromJson(json['league'] as Map<String, dynamic>),
      );
}
