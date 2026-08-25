import 'league.dart';

class SaveGame {
  String clubName;
  String userTeamId;
  League league;

  /// クラブ資金（万円）
  int budget;

  /// 理事会が今シーズンに求める目標順位（1が最高位）
  int boardTargetRank;

  /// 監督への信頼度（0-100）。0になると解任される。
  int confidence;

  SaveGame({
    required this.clubName,
    required this.userTeamId,
    required this.league,
    this.budget = 3000,
    this.boardTargetRank = 4,
    this.confidence = 60,
  });

  Map<String, dynamic> toJson() => {
        'clubName': clubName,
        'userTeamId': userTeamId,
        'league': league.toJson(),
        'budget': budget,
        'boardTargetRank': boardTargetRank,
        'confidence': confidence,
      };

  factory SaveGame.fromJson(Map<String, dynamic> json) => SaveGame(
        clubName: json['clubName'] as String,
        userTeamId: json['userTeamId'] as String,
        league: League.fromJson(json['league'] as Map<String, dynamic>),
        budget: json['budget'] as int? ?? 3000,
        boardTargetRank: json['boardTargetRank'] as int? ?? 4,
        confidence: json['confidence'] as int? ?? 60,
      );
}
