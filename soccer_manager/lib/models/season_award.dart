/// シーズン終了時に確定する個人タイトル(得点王・年間MVP)の記録。
class SeasonAward {
  final int season;
  final String? topScorerName;
  final String? topScorerTeamName;
  final String? topScorerTeamId;
  final int topScorerGoals;
  final String? mvpName;
  final String? mvpTeamName;
  final String? mvpTeamId;

  SeasonAward({
    required this.season,
    this.topScorerName,
    this.topScorerTeamName,
    this.topScorerTeamId,
    this.topScorerGoals = 0,
    this.mvpName,
    this.mvpTeamName,
    this.mvpTeamId,
  });

  Map<String, dynamic> toJson() => {
        'season': season,
        'topScorerName': topScorerName,
        'topScorerTeamName': topScorerTeamName,
        'topScorerTeamId': topScorerTeamId,
        'topScorerGoals': topScorerGoals,
        'mvpName': mvpName,
        'mvpTeamName': mvpTeamName,
        'mvpTeamId': mvpTeamId,
      };

  factory SeasonAward.fromJson(Map<String, dynamic> json) => SeasonAward(
        season: json['season'] as int,
        topScorerName: json['topScorerName'] as String?,
        topScorerTeamName: json['topScorerTeamName'] as String?,
        topScorerTeamId: json['topScorerTeamId'] as String?,
        topScorerGoals: json['topScorerGoals'] as int? ?? 0,
        mvpName: json['mvpName'] as String?,
        mvpTeamName: json['mvpTeamName'] as String?,
        mvpTeamId: json['mvpTeamId'] as String?,
      );
}
