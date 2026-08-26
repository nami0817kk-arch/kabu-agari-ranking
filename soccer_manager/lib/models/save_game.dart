import 'bank_loan.dart';
import 'club_infrastructure.dart';
import 'cup.dart';
import 'incoming_offer.dart';
import 'installment.dart';
import 'league.dart';
import 'player.dart';
import 'press_question.dart';
import 'season_award.dart';
import 'sponsor.dart';
import 'team.dart';

class SaveGame {
  String clubName;
  String userTeamId;
  League league;

  /// 所属リーグの表示名(例: 「アルビオン・リーグ」)。
  String leagueName;

  /// クラブ資金（万円）
  int budget;

  /// 理事会が今シーズンに求める目標順位（1が最高位）
  int boardTargetRank;

  /// 監督への信頼度（0-100）。0になると解任される。
  int confidence;

  /// 監督としての世間の評価（0-100）。信頼度と異なり解任されても引き継がれ、
  /// 他クラブからのオファーの受けやすさに影響する。
  int managerReputation;

  /// 他クラブから監督就任オファーが届いている場合、そのクラブのID。
  String? pendingJobOfferTeamId;

  /// ユース昇格候補・スカウトした有望株。
  List<Player> youthProspects;

  /// シーズン終了時に一括生成された、選抜待ちのユースインテーク候補。
  List<Player> pendingYouthIntake;

  /// スタッフ・施設のレベル。
  ClubInfrastructure infrastructure;

  /// 今シーズン進行中のカップ戦(国内・大陸)。
  List<Cup> cups;

  /// 前シーズン終了時の最終順位(大陸カップ出場資格判定に使用)。未経験の場合はnull。
  int? lastSeasonRank;

  /// 大陸カップに参加する海外クラブ(出場資格がある間のみ生成される)。
  List<Team> continentalTeams;

  /// 現在契約中のスポンサー。未契約の場合はnull。
  SponsorDeal? sponsorDeal;

  /// 契約更新・新規契約のために提示されている候補(未選択の間はスポンサー収入が発生しない)。
  List<SponsorDeal> pendingSponsorOffers;

  /// 分割払いで獲得した選手の残金支払い予定。
  List<Installment> pendingInstallments;

  /// シーズン開幕前の親善試合日程。
  List<Fixture> friendlies;

  /// 他クラブから届いている、自クラブ選手への移籍オファー。
  List<IncomingOffer> incomingOffers;

  /// 銀行から借り入れている融資。
  List<BankLoan> bankLoans;

  /// シーズンごとに確定した個人タイトル(得点王・年間MVP)の履歴。
  List<SeasonAward> seasonAwards;

  /// ライバルクラブのID・表示名(開幕時に決定し、以後固定)。
  String? rivalTeamId;
  String? rivalTeamName;

  /// 回答待ちの記者会見の質問。ない場合はnull。
  PressQuestion? pendingPressConference;

  /// 現在ユーザーが所属していない方のディビジョンのチーム一覧。週次では進行させず、
  /// シーズン終了時にまとめてシミュレートして昇格・降格を決定する。
  List<Team> secondDivisionTeams;

  /// ユーザークラブが現在所属するディビジョン(1部/2部)。
  int currentDivisionTier;

  /// 監督としての通算成績。
  int careerWins;
  int careerDraws;
  int careerLosses;
  int careerSeasons;

  /// 獲得したタイトルの履歴(リーグ優勝・カップ優勝など)。
  List<String> trophyHistory;

  /// これまで指揮したクラブ名の履歴(就任順)。
  List<String> clubHistory;

  /// 契約満了で放出された選手や、市場に出回っているベテランなど、
  /// 移籍金なし(週俸のみ)で獲得できるフリーエージェントのプール。
  List<Player> freeAgents;

  /// 引退した選手(殿堂)。契約満了で単に自由契約になった選手とは異なり、
  /// 高齢による正式な引退のため再契約はできない。
  List<Player> retiredLegends;

  SaveGame({
    required this.clubName,
    required this.userTeamId,
    required this.league,
    this.leagueName = 'リーグ',
    this.budget = 3000,
    this.boardTargetRank = 4,
    this.confidence = 60,
    this.managerReputation = 50,
    this.pendingJobOfferTeamId,
    List<Player>? youthProspects,
    List<Player>? pendingYouthIntake,
    ClubInfrastructure? infrastructure,
    List<Cup>? cups,
    this.lastSeasonRank,
    List<Team>? continentalTeams,
    this.sponsorDeal,
    List<SponsorDeal>? pendingSponsorOffers,
    List<Installment>? pendingInstallments,
    List<Fixture>? friendlies,
    List<IncomingOffer>? incomingOffers,
    List<BankLoan>? bankLoans,
    List<SeasonAward>? seasonAwards,
    this.rivalTeamId,
    this.rivalTeamName,
    this.pendingPressConference,
    List<Team>? secondDivisionTeams,
    this.currentDivisionTier = 1,
    this.careerWins = 0,
    this.careerDraws = 0,
    this.careerLosses = 0,
    this.careerSeasons = 0,
    List<String>? trophyHistory,
    List<String>? clubHistory,
    List<Player>? freeAgents,
    List<Player>? retiredLegends,
  })  : trophyHistory = trophyHistory ?? [],
        clubHistory = clubHistory ?? [],
        freeAgents = freeAgents ?? [],
        retiredLegends = retiredLegends ?? [],
        youthProspects = youthProspects ?? [],
        pendingYouthIntake = pendingYouthIntake ?? [],
        infrastructure = infrastructure ?? ClubInfrastructure(),
        cups = cups ?? [],
        continentalTeams = continentalTeams ?? [],
        pendingSponsorOffers = pendingSponsorOffers ?? [],
        pendingInstallments = pendingInstallments ?? [],
        friendlies = friendlies ?? [],
        incomingOffers = incomingOffers ?? [],
        bankLoans = bankLoans ?? [],
        seasonAwards = seasonAwards ?? [],
        secondDivisionTeams = secondDivisionTeams ?? [];

  Map<String, dynamic> toJson() => {
        'clubName': clubName,
        'userTeamId': userTeamId,
        'league': league.toJson(),
        'leagueName': leagueName,
        'budget': budget,
        'boardTargetRank': boardTargetRank,
        'confidence': confidence,
        'managerReputation': managerReputation,
        'pendingJobOfferTeamId': pendingJobOfferTeamId,
        'youthProspects': youthProspects.map((p) => p.toJson()).toList(),
        'pendingYouthIntake':
            pendingYouthIntake.map((p) => p.toJson()).toList(),
        'infrastructure': infrastructure.toJson(),
        'cups': cups.map((c) => c.toJson()).toList(),
        'lastSeasonRank': lastSeasonRank,
        'continentalTeams': continentalTeams.map((t) => t.toJson()).toList(),
        'sponsorDeal': sponsorDeal?.toJson(),
        'pendingSponsorOffers':
            pendingSponsorOffers.map((s) => s.toJson()).toList(),
        'pendingInstallments':
            pendingInstallments.map((i) => i.toJson()).toList(),
        'friendlies': friendlies.map((f) => f.toJson()).toList(),
        'incomingOffers': incomingOffers.map((o) => o.toJson()).toList(),
        'bankLoans': bankLoans.map((l) => l.toJson()).toList(),
        'seasonAwards': seasonAwards.map((a) => a.toJson()).toList(),
        'rivalTeamId': rivalTeamId,
        'rivalTeamName': rivalTeamName,
        'pendingPressConference': pendingPressConference?.toJson(),
        'secondDivisionTeams':
            secondDivisionTeams.map((t) => t.toJson()).toList(),
        'currentDivisionTier': currentDivisionTier,
        'careerWins': careerWins,
        'careerDraws': careerDraws,
        'careerLosses': careerLosses,
        'careerSeasons': careerSeasons,
        'trophyHistory': trophyHistory,
        'clubHistory': clubHistory,
        'freeAgents': freeAgents.map((p) => p.toJson()).toList(),
        'retiredLegends': retiredLegends.map((p) => p.toJson()).toList(),
      };

  factory SaveGame.fromJson(Map<String, dynamic> json) => SaveGame(
        clubName: json['clubName'] as String,
        userTeamId: json['userTeamId'] as String,
        league: League.fromJson(json['league'] as Map<String, dynamic>),
        leagueName: json['leagueName'] as String? ?? 'リーグ',
        budget: json['budget'] as int? ?? 3000,
        boardTargetRank: json['boardTargetRank'] as int? ?? 4,
        confidence: json['confidence'] as int? ?? 60,
        managerReputation: json['managerReputation'] as int? ?? 50,
        pendingJobOfferTeamId: json['pendingJobOfferTeamId'] as String?,
        youthProspects: (json['youthProspects'] as List?)
                ?.map((e) => Player.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        pendingYouthIntake: (json['pendingYouthIntake'] as List?)
                ?.map((e) => Player.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        infrastructure: ClubInfrastructure.fromJson(
            json['infrastructure'] as Map<String, dynamic>?),
        cups: (json['cups'] as List?)
                ?.map((e) => Cup.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        lastSeasonRank: json['lastSeasonRank'] as int?,
        continentalTeams: (json['continentalTeams'] as List?)
                ?.map((e) => Team.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        sponsorDeal: json['sponsorDeal'] == null
            ? null
            : SponsorDeal.fromJson(json['sponsorDeal'] as Map<String, dynamic>),
        pendingSponsorOffers: (json['pendingSponsorOffers'] as List?)
                ?.map((e) => SponsorDeal.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        pendingInstallments: (json['pendingInstallments'] as List?)
                ?.map((e) => Installment.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        friendlies: (json['friendlies'] as List?)
                ?.map((e) => Fixture.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        incomingOffers: (json['incomingOffers'] as List?)
                ?.map((e) => IncomingOffer.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        bankLoans: (json['bankLoans'] as List?)
                ?.map((e) => BankLoan.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        seasonAwards: (json['seasonAwards'] as List?)
                ?.map((e) => SeasonAward.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        rivalTeamId: json['rivalTeamId'] as String?,
        rivalTeamName: json['rivalTeamName'] as String?,
        pendingPressConference: json['pendingPressConference'] == null
            ? null
            : PressQuestion.fromJson(
                json['pendingPressConference'] as Map<String, dynamic>),
        secondDivisionTeams: (json['secondDivisionTeams'] as List?)
                ?.map((e) => Team.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        currentDivisionTier: json['currentDivisionTier'] as int? ?? 1,
        careerWins: json['careerWins'] as int? ?? 0,
        careerDraws: json['careerDraws'] as int? ?? 0,
        careerLosses: json['careerLosses'] as int? ?? 0,
        careerSeasons: json['careerSeasons'] as int? ?? 0,
        trophyHistory: (json['trophyHistory'] as List?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        clubHistory:
            (json['clubHistory'] as List?)?.map((e) => e as String).toList() ??
                [],
        freeAgents: (json['freeAgents'] as List?)
                ?.map((e) => Player.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        retiredLegends: (json['retiredLegends'] as List?)
                ?.map((e) => Player.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
