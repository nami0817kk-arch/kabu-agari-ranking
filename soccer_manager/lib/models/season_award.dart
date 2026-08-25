/// シーズン終了時に確定する個人タイトル(得点王・年間MVP)の記録。
class SeasonAward {
  final int season;
  final String? topScorerName;
  final String? topScorerTeamName;
  final int topScorerGoals;
  final String? mvpName;
  final String? mvpTeamName;

  SeasonAward({
    required this.season,
    this.topScorerName,
    this.topScorerTeamName,
    this.topScorerGoals = 0,
    this.mvpName,
    this.mvpTeamName,
  });

  Map<String, dynamic> toJson() => {
        'season': season,
        'topScorerName': topScorerName,
        'topScorerTeamName': topScorerTeamName,
        'topScorerGoals': topScorerGoals,
        'mvpName': mvpName,
        'mvpTeamName': mvpTeamName,
      };

  factory SeasonAward.fromJson(Map<String, dynamic> json) => SeasonAward(
        season: json['season'] as int,
        topScorerName: json['topScorerName'] as String?,
        topScorerTeamName: json['topScorerTeamName'] as String?,
        topScorerGoals: json['topScorerGoals'] as int? ?? 0,
        mvpName: json['mvpName'] as String?,
        mvpTeamName: json['mvpTeamName'] as String?,
      );
}
