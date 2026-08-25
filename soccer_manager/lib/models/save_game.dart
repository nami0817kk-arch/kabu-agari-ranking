import 'club_infrastructure.dart';
import 'cup.dart';
import 'league.dart';
import 'player.dart';
import 'team.dart';

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

  /// ユース昇格候補・スカウトした有望株。
  List<Player> youthProspects;

  /// スタッフ・施設のレベル。
  ClubInfrastructure infrastructure;

  /// 今シーズン進行中のカップ戦(国内・大陸)。
  List<Cup> cups;

  /// 前シーズン終了時の最終順位(大陸カップ出場資格判定に使用)。未経験の場合はnull。
  int? lastSeasonRank;

  /// 大陸カップに参加する海外クラブ(出場資格がある間のみ生成される)。
  List<Team> continentalTeams;

  SaveGame({
    required this.clubName,
    required this.userTeamId,
    required this.league,
    this.budget = 3000,
    this.boardTargetRank = 4,
    this.confidence = 60,
    List<Player>? youthProspects,
    ClubInfrastructure? infrastructure,
    List<Cup>? cups,
    this.lastSeasonRank,
    List<Team>? continentalTeams,
  })  : youthProspects = youthProspects ?? [],
        infrastructure = infrastructure ?? ClubInfrastructure(),
        cups = cups ?? [],
        continentalTeams = continentalTeams ?? [];

  Map<String, dynamic> toJson() => {
        'clubName': clubName,
        'userTeamId': userTeamId,
        'league': league.toJson(),
        'budget': budget,
        'boardTargetRank': boardTargetRank,
        'confidence': confidence,
        'youthProspects': youthProspects.map((p) => p.toJson()).toList(),
        'infrastructure': infrastructure.toJson(),
        'cups': cups.map((c) => c.toJson()).toList(),
        'lastSeasonRank': lastSeasonRank,
        'continentalTeams': continentalTeams.map((t) => t.toJson()).toList(),
      };

  factory SaveGame.fromJson(Map<String, dynamic> json) => SaveGame(
        clubName: json['clubName'] as String,
        userTeamId: json['userTeamId'] as String,
        league: League.fromJson(json['league'] as Map<String, dynamic>),
        budget: json['budget'] as int? ?? 3000,
        boardTargetRank: json['boardTargetRank'] as int? ?? 4,
        confidence: json['confidence'] as int? ?? 60,
        youthProspects: (json['youthProspects'] as List?)
                ?.map((e) => Player.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        infrastructure: ClubInfrastructure.fromJson(json['infrastructure'] as Map<String, dynamic>?),
        cups: (json['cups'] as List?)?.map((e) => Cup.fromJson(e as Map<String, dynamic>)).toList() ?? [],
        lastSeasonRank: json['lastSeasonRank'] as int?,
        continentalTeams: (json['continentalTeams'] as List?)
                ?.map((e) => Team.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
