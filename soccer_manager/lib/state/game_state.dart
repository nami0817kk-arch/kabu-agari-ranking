import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/formation.dart';
import '../models/player.dart';
import '../models/save_game.dart';
import '../models/team.dart';
import '../models/league.dart';
import '../models/match_result.dart';
import '../logic/board_engine.dart';
import '../logic/player_generator.dart';
import '../logic/fixture_generator.dart';
import '../logic/lineup_utils.dart';
import '../logic/match_engine.dart';
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
    );
    transferMarket = TransferMarket.generate();
    notifyListeners();
    await _persist();
  }

  Future<void> deleteSave() async {
    _save = null;
    transferMarket = [];
    notifyListeners();
    await _persist();
  }

  Future<void> applyTraining(TrainingFocus focus) async {
    if (_save == null) return;
    TrainingEngine.applyWeeklyTraining(userTeam, focus);
    notifyListeners();
    await _persist();
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

  int weeklyIncomeFor(String teamId) {
    final league = _save!.league;
    final standings = league.sortedStandings;
    final rank = standings.indexWhere((r) => r.teamId == teamId) + 1;
    final teamCount = league.teams.length;
    final rankBonus = ((teamCount - rank) * 20).clamp(0, 999);
    return 150 + rankBonus;
  }

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

    final md = next.matchday;
    MatchResult? userResult;
    for (final f in league.fixturesForMatchday(md)) {
      final home = league.teams.firstWhere((t) => t.id == f.homeTeamId);
      final away = league.teams.firstWhere((t) => t.id == f.awayTeamId);
      final result = MatchEngine.simulate(home: home, away: away, matchday: md);
      f.result = result;
      if (f.homeTeamId == _save!.userTeamId || f.awayTeamId == _save!.userTeamId) {
        userResult = result;
      }
    }

    _save!.budget += weeklyIncomeFor(_save!.userTeamId);
    if (userResult != null) {
      final delta = BoardEngine.confidenceDeltaForMatch(userResult, _save!.userTeamId);
      _save!.confidence = (_save!.confidence + delta).clamp(0, 100);
    }
    transferMarket = TransferMarket.generate();

    notifyListeners();
    await _persist();
    return userResult;
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
    final newFixtures = FixtureGenerator.generateDoubleRoundRobin(league.teams);
    _save!.league = League(teams: league.teams, fixtures: newFixtures, season: league.season + 1);
    _save!.boardTargetRank = BoardEngine.estimateTargetRank(_save!.league, _save!.userTeamId);
    transferMarket = TransferMarket.generate();
    notifyListeners();
    await _persist();
  }
}
