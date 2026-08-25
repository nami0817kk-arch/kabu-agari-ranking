import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/club_infrastructure.dart';
import '../models/cup.dart';
import '../models/formation.dart';
import '../models/player.dart';
import '../models/save_game.dart';
import '../models/team.dart';
import '../models/league.dart';
import '../models/match_result.dart';
import '../logic/board_engine.dart';
import '../logic/contract_engine.dart';
import '../logic/cup_engine.dart';
import '../logic/player_generator.dart';
import '../logic/fixture_generator.dart';
import '../logic/lineup_utils.dart';
import '../logic/match_engine.dart';
import '../logic/scouting_engine.dart';
import '../logic/training_engine.dart';
import '../logic/transfer_market.dart';
import '../data/name_pool.dart';

const int maxSquadSize = 26;
const int minSquadSize = 12;

class GameState extends ChangeNotifier {
  static const _prefsKey = 'soccer_manager_save_v1';

  SaveGame? _save;
  bool initialized = false;
  List<Player> transferMarket = [];

  /// 直近のplayNextMatchdayで契約切れとなった選手名（1回表示したら呼び出し側でクリアする想定）。
  List<String> lastContractExpirations = [];

  SaveGame? get save => _save;
  bool get hasSave => _save != null;
  Team get userTeam => _save!.league.teams.firstWhere((t) => t.id == _save!.userTeamId);

  /// 信頼度が0まで落ち、監督が解任された状態かどうか。
  bool get isDismissed => _save != null && _save!.confidence <= 0;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        _save = SaveGame.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        _save = null;
      }
    }
    if (_save != null) {
      transferMarket = TransferMarket.generate();
    }
    initialized = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (_save == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, jsonEncode(_save!.toJson()));
    }
  }

  Future<void> startNewGame(String clubName) async {
    final userTeam = PlayerGenerator.generateSquad(
      id: 'user',
      name: clubName,
      strengthTier: 60,
      isUserTeam: true,
    );
    final cpuNames = NamePool.clubNames(7);
    final cpuTeams = <Team>[];
    final rng = Random();
    for (int i = 0; i < 7; i++) {
      final tier = 45 + rng.nextInt(30);
      cpuTeams.add(PlayerGenerator.generateSquad(id: 'cpu$i', name: cpuNames[i], strengthTier: tier));
    }
    final teams = [userTeam, ...cpuTeams];
    for (final t in teams) {
      LineupUtils.autoFill(t);
    }
    final fixtures = FixtureGenerator.generateDoubleRoundRobin(teams);
    final league = League(teams: teams, fixtures: fixtures, season: 1);
    _save = SaveGame(
      clubName: clubName,
      userTeamId: 'user',
      league: league,
      boardTargetRank: BoardEngine.estimateTargetRank(league, 'user'),
      cups: [
        CupEngine.createKnockout(
          type: CupType.domestic,
          name: '国内カップ',
          teamIds: teams.map((t) => t.id).toList(),
        ),
      ],
    );
    transferMarket = TransferMarket.generate();
    lastContractExpirations = [];
    notifyListeners();
    await _persist();
  }

  Future<void> deleteSave() async {
    _save = null;
    transferMarket = [];
    lastContractExpirations = [];
    notifyListeners();
    await _persist();
  }

  /// チーム既定のトレーニング方針を設定する（個別方針未設定の選手に適用される）。
  void setTeamTrainingFocus(TrainingFocus focus) {
    if (_save == null) return;
    userTeam.defaultTrainingFocus = focus;
    notifyListeners();
    _persist();
  }

  /// 選手個別のトレーニング方針を設定する。nullでチーム既定に戻す。
  void setPlayerTrainingFocus(String playerId, TrainingFocus? focus) {
    if (_save == null) return;
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    player.individualFocus = focus;
    notifyListeners();
    _persist();
  }

  Future<void> runWeeklyTraining() async {
    if (_save == null) return;
    final infra = _save!.infrastructure;
    TrainingEngine.applyWeeklyTraining(
      userTeam,
      headCoachLevel: infra.staffLevel(StaffRole.headCoach),
      trainingGroundLevel: infra.facilityLevel(FacilityType.trainingGround),
    );
    notifyListeners();
    await _persist();
  }

  /// スタッフ雇用・昇格の費用(万円)。上限レベルなら0を返す。
  int staffUpgradeCostFor(StaffRole role) {
    final lvl = _save!.infrastructure.staffLevel(role);
    return ClubInfrastructure.staffUpgradeCost(lvl);
  }

  int facilityUpgradeCostFor(FacilityType type) {
    final lvl = _save!.infrastructure.facilityLevel(type);
    return ClubInfrastructure.facilityUpgradeCost(lvl);
  }

  Future<bool> upgradeStaff(StaffRole role) async {
    if (_save == null) return false;
    final infra = _save!.infrastructure;
    final lvl = infra.staffLevel(role);
    if (lvl >= ClubInfrastructure.maxLevel) return false;
    final cost = ClubInfrastructure.staffUpgradeCost(lvl);
    if (_save!.budget < cost) return false;
    _save!.budget -= cost;
    infra.upgradeStaff(role);
    notifyListeners();
    await _persist();
    return true;
  }

  Future<bool> upgradeFacility(FacilityType type) async {
    if (_save == null) return false;
    final infra = _save!.infrastructure;
    final lvl = infra.facilityLevel(type);
    if (lvl >= ClubInfrastructure.maxLevel) return false;
    final cost = ClubInfrastructure.facilityUpgradeCost(lvl);
    if (_save!.budget < cost) return false;
    _save!.budget -= cost;
    infra.upgradeFacility(type);
    notifyListeners();
    await _persist();
    return true;
  }

  void setPressing(int value) {
    if (_save == null) return;
    userTeam.pressing = value.clamp(0, 100);
    notifyListeners();
    _persist();
  }

  void setLineHeight(int value) {
    if (_save == null) return;
    userTeam.lineHeight = value.clamp(0, 100);
    notifyListeners();
    _persist();
  }

  void setFormation(Formation formation) {
    if (_save == null) return;
    userTeam.formation = formation;
    LineupUtils.autoFill(userTeam);
    notifyListeners();
    _persist();
  }

  void autoFillStartingXI() {
    if (_save == null) return;
    LineupUtils.autoFill(userTeam);
    notifyListeners();
    _persist();
  }

  /// スタメン入り/除外を切り替える。フォーメーションのポジション別人数上限を超える場合は無視する。
  void toggleStartingPlayer(String playerId) {
    if (_save == null) return;
    final team = userTeam;
    final player = team.players.firstWhere((p) => p.id == playerId);
    if (player.isInjured) return;

    if (team.startingXI.contains(playerId)) {
      team.startingXI.remove(playerId);
    } else {
      final quota = team.formation.quotaFor(player.position);
      final currentInPosition = team.startingXI
          .map((id) => team.players.firstWhere((p) => p.id == id))
          .where((p) => p.position == player.position)
          .length;
      if (currentInPosition >= quota) return;
      team.startingXI.add(playerId);
    }
    notifyListeners();
    _persist();
  }

  Future<bool> buyPlayer(String playerId) async {
    if (_save == null) return false;
    final player = transferMarket.firstWhere((p) => p.id == playerId);
    if (_save!.budget < player.marketValue) return false;
    if (userTeam.players.length >= maxSquadSize) return false;
    _save!.budget -= player.marketValue;
    userTeam.players.add(player);
    transferMarket.removeWhere((p) => p.id == playerId);
    notifyListeners();
    await _persist();
    return true;
  }

  Future<bool> sellPlayer(String playerId) async {
    if (_save == null) return false;
    final team = userTeam;
    if (team.players.length <= minSquadSize) return false;
    final player = team.players.firstWhere((p) => p.id == playerId);
    final sellPrice = (player.marketValue * 0.7).round();
    team.players.removeWhere((p) => p.id == playerId);
    team.startingXI.remove(playerId);
    _save!.budget += sellPrice;
    notifyListeners();
    await _persist();
    return true;
  }

  int renewalCostFor(String playerId) {
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    return ContractEngine.renewalCost(player);
  }

  Future<bool> renewContract(String playerId) async {
    if (_save == null) return false;
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    final cost = ContractEngine.renewalCost(player);
    if (_save!.budget < cost) return false;
    _save!.budget -= cost;
    ContractEngine.renewContract(player);
    notifyListeners();
    await _persist();
    return true;
  }

  int get scoutCost => ScoutingEngine.scoutCostFor(_save!.infrastructure.staffLevel(StaffRole.scout));

  int get maxYouthProspects =>
      ScoutingEngine.maxProspectsFor(_save!.infrastructure.facilityLevel(FacilityType.youthFacility));

  Future<bool> scoutProspect() async {
    if (_save == null) return false;
    final infra = _save!.infrastructure;
    final cost = ScoutingEngine.scoutCostFor(infra.staffLevel(StaffRole.scout));
    final maxP = ScoutingEngine.maxProspectsFor(infra.facilityLevel(FacilityType.youthFacility));
    if (_save!.budget < cost) return false;
    if (_save!.youthProspects.length >= maxP) return false;
    _save!.budget -= cost;
    _save!.youthProspects.add(ScoutingEngine.generateScoutedProspect(scoutLevel: infra.staffLevel(StaffRole.scout)));
    notifyListeners();
    await _persist();
    return true;
  }

  Future<bool> promoteYouthProspect(String playerId) async {
    if (_save == null) return false;
    if (userTeam.players.length >= maxSquadSize) return false;
    final idx = _save!.youthProspects.indexWhere((p) => p.id == playerId);
    if (idx < 0) return false;
    final player = _save!.youthProspects.removeAt(idx);
    userTeam.players.add(player);
    notifyListeners();
    await _persist();
    return true;
  }

  Future<void> releaseYouthProspect(String playerId) async {
    if (_save == null) return;
    _save!.youthProspects.removeWhere((p) => p.id == playerId);
    notifyListeners();
    await _persist();
  }

  int weeklyIncomeFor(String teamId) {
    final league = _save!.league;
    final standings = league.sortedStandings;
    final rank = standings.indexWhere((r) => r.teamId == teamId) + 1;
    final teamCount = league.teams.length;
    final rankBonus = ((teamCount - rank) * 20).clamp(0, 999);
    final base = 150 + rankBonus;
    if (teamId == _save!.userTeamId) {
      final stadiumLevel = _save!.infrastructure.facilityLevel(FacilityType.stadium);
      return base + (stadiumLevel - 1) * 80;
    }
    return base;
  }

  int get weeklyWageBill => ContractEngine.weeklyWageBill(userTeam) + _save!.infrastructure.totalStaffWeeklyWage;

  /// フィジオのレベルに応じた負傷の発生率・療養期間の軽減係数(1.0で軽減なし)。
  double get _userInjuryFactor =>
      (1 - (_save!.infrastructure.staffLevel(StaffRole.physio) - 1) * 0.15).clamp(0.4, 1.0);

  double _injuryFactorFor(String teamId) => teamId == _save!.userTeamId ? _userInjuryFactor : 1.0;

  Future<MatchResult?> playNextMatchday() async {
    if (_save == null) return null;
    final league = _save!.league;
    final next = league.nextUnplayedFixture;
    if (next == null) return null;

    // 週の経過による負傷回復
    for (final t in league.teams) {
      for (final p in t.players) {
        if (p.injuryWeeks > 0) p.injuryWeeks -= 1;
      }
    }

    // ユーザークラブのみ契約消化・契約切れを処理する（CPUクラブは対象外）
    final expired = ContractEngine.advanceWeek(userTeam);
    lastContractExpirations = expired.map((p) => p.name).toList();

    final md = next.matchday;
    MatchResult? userResult;
    for (final f in league.fixturesForMatchday(md)) {
      final home = league.teams.firstWhere((t) => t.id == f.homeTeamId);
      final away = league.teams.firstWhere((t) => t.id == f.awayTeamId);
      final result = MatchEngine.simulate(
        home: home,
        away: away,
        matchday: md,
        homeInjuryFactor: _injuryFactorFor(home.id),
        awayInjuryFactor: _injuryFactorFor(away.id),
      );
      f.result = result;
      if (f.homeTeamId == _save!.userTeamId || f.awayTeamId == _save!.userTeamId) {
        userResult = result;
      }
    }

    _save!.budget += weeklyIncomeFor(_save!.userTeamId);
    _save!.budget -= weeklyWageBill;
    if (userResult != null) {
      final delta = BoardEngine.confidenceDeltaForMatch(userResult, _save!.userTeamId);
      _save!.confidence = (_save!.confidence + delta).clamp(0, 100);
    }
    transferMarket = TransferMarket.generate();

    notifyListeners();
    await _persist();
    return userResult;
  }

  List<Team> get allTeamsForCups => [..._save!.league.teams, ..._save!.continentalTeams];

  Cup? _cupOfType(CupType type) {
    for (final c in _save!.cups) {
      if (c.type == type) return c;
    }
    return null;
  }

  Cup? get domesticCup => _save == null ? null : _cupOfType(CupType.domestic);
  Cup? get continentalCup => _save == null ? null : _cupOfType(CupType.continental);

  /// 前シーズンの最終順位に基づき、来季の大陸カップ出場資格があるか。
  bool get qualifiedForContinentalCup => (_save?.lastSeasonRank ?? 99) <= 2;

  Future<MatchResult?> playNextCupMatch(CupType type) async {
    if (_save == null) return null;
    final cup = _cupOfType(type);
    if (cup == null) return null;
    final userId = _save!.userTeamId;

    final result = CupEngine.playNextMatch(cup, allTeamsForCups);
    if (result != null && (result.homeTeamId == userId || result.awayTeamId == userId)) {
      if (cup.isEliminated(userId)) {
        _save!.confidence = (_save!.confidence + (type == CupType.continental ? -3 : -1)).clamp(0, 100);
      }
    }
    if (cup.isComplete && cup.championId == userId && !cup.rewardClaimed) {
      cup.rewardClaimed = true;
      final prize = type == CupType.continental ? 1500 : 700;
      _save!.budget += prize;
      _save!.confidence = (_save!.confidence + (type == CupType.continental ? 20 : 10)).clamp(0, 100);
    }
    notifyListeners();
    await _persist();
    return result;
  }

  List<Team> _generateContinentalTeams() {
    final rng = Random();
    final names = NamePool.clubNames(7).map((n) => '$n（欧州）').toList();
    final teams = <Team>[];
    for (int i = 0; i < 7; i++) {
      final t = PlayerGenerator.generateSquad(
        id: 'continental$i',
        name: names[i],
        strengthTier: 65 + rng.nextInt(20),
      );
      LineupUtils.autoFill(t);
      teams.add(t);
    }
    return teams;
  }

  Future<void> startNextSeason() async {
    if (_save == null) return;
    final league = _save!.league;
    final standings = league.sortedStandings;
    final finalRank = standings.indexWhere((r) => r.teamId == _save!.userTeamId) + 1;

    _save!.budget += BoardEngine.seasonPrizeMoney(finalRank: finalRank, teamCount: league.teams.length);
    final confidenceDelta = BoardEngine.confidenceDeltaForSeasonEnd(
      finalRank: finalRank,
      targetRank: _save!.boardTargetRank,
    );
    _save!.confidence = (_save!.confidence + confidenceDelta).clamp(0, 100);

    for (final t in league.teams) {
      for (final p in t.players) {
        p.age += 1;
      }
    }
    final infra = _save!.infrastructure;
    if (_save!.youthProspects.length < ScoutingEngine.maxProspectsFor(infra.facilityLevel(FacilityType.youthFacility))) {
      _save!.youthProspects
          .add(ScoutingEngine.generateAcademyGraduate(youthCoachLevel: infra.staffLevel(StaffRole.youthCoach)));
    }
    final newFixtures = FixtureGenerator.generateDoubleRoundRobin(league.teams);
    _save!.league = League(teams: league.teams, fixtures: newFixtures, season: league.season + 1);
    _save!.boardTargetRank = BoardEngine.estimateTargetRank(_save!.league, _save!.userTeamId);
    transferMarket = TransferMarket.generate();

    _save!.lastSeasonRank = finalRank;
    final newCups = <Cup>[
      CupEngine.createKnockout(
        type: CupType.domestic,
        name: '国内カップ',
        teamIds: league.teams.map((t) => t.id).toList(),
      ),
    ];
    if (finalRank <= 2) {
      final continentalTeams = _generateContinentalTeams();
      _save!.continentalTeams = continentalTeams;
      newCups.add(CupEngine.createKnockout(
        type: CupType.continental,
        name: '大陸カップ',
        teamIds: [_save!.userTeamId, ...continentalTeams.map((t) => t.id)],
      ));
    } else {
      _save!.continentalTeams = [];
    }
    _save!.cups = newCups;

    notifyListeners();
    await _persist();
  }
}
