import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/save_game.dart';
import '../models/team.dart';
import '../models/league.dart';
import '../models/match_result.dart';
import '../logic/player_generator.dart';
import '../logic/fixture_generator.dart';
import '../logic/match_engine.dart';
import '../logic/training_engine.dart';
import '../data/name_pool.dart';

class GameState extends ChangeNotifier {
  static const _prefsKey = 'soccer_manager_save_v1';

  SaveGame? _save;
  bool initialized = false;

  SaveGame? get save => _save;
  bool get hasSave => _save != null;
  Team get userTeam => _save!.league.teams.firstWhere((t) => t.id == _save!.userTeamId);

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
    final fixtures = FixtureGenerator.generateDoubleRoundRobin(teams);
    _save = SaveGame(
      clubName: clubName,
      userTeamId: 'user',
      league: League(teams: teams, fixtures: fixtures, season: 1),
    );
    notifyListeners();
    await _persist();
  }

  Future<void> deleteSave() async {
    _save = null;
    notifyListeners();
    await _persist();
  }

  Future<void> applyTraining(TrainingFocus focus) async {
    if (_save == null) return;
    TrainingEngine.applyWeeklyTraining(userTeam, focus);
    notifyListeners();
    await _persist();
  }

  Future<MatchResult?> playNextMatchday() async {
    if (_save == null) return null;
    final league = _save!.league;
    final next = league.nextUnplayedFixture;
    if (next == null) return null;
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
    notifyListeners();
    await _persist();
    return userResult;
  }

  Future<void> startNextSeason() async {
    if (_save == null) return;
    final league = _save!.league;
    for (final t in league.teams) {
      for (final p in t.players) {
        p.age += 1;
      }
    }
    final newFixtures = FixtureGenerator.generateDoubleRoundRobin(league.teams);
    _save!.league = League(teams: league.teams, fixtures: newFixtures, season: league.season + 1);
    notifyListeners();
    await _persist();
  }
}
