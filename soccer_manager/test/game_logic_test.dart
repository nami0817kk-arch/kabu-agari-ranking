import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/board_engine.dart';
import 'package:soccer_manager/logic/contract_engine.dart';
import 'package:soccer_manager/logic/lineup_utils.dart';
import 'package:soccer_manager/logic/match_engine.dart';
import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/scouting_engine.dart';
import 'package:soccer_manager/logic/training_engine.dart';
import 'package:soccer_manager/logic/transfer_market.dart';
import 'package:soccer_manager/models/formation.dart';
import 'package:soccer_manager/models/match_result.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('LineupUtils.autoFill respects formation position quotas', () {
    final team = PlayerGenerator.generateSquad(id: 't1', name: 'Test FC', strengthTier: 60);
    team.formation = Formation.f433;
    LineupUtils.autoFill(team);

    expect(team.startingXI.length, 11);
    final byId = {for (final p in team.players) p.id: p};
    final lineup = team.startingXI.map((id) => byId[id]!).toList();
    expect(lineup.where((p) => p.position == Position.gk).length, 1);
    expect(lineup.where((p) => p.position == Position.df).length, 4);
    expect(lineup.where((p) => p.position == Position.mf).length, 3);
    expect(lineup.where((p) => p.position == Position.fw).length, 3);
  });

  test('LineupUtils.autoFill excludes injured players', () {
    final team = PlayerGenerator.generateSquad(id: 't2', name: 'Test FC', strengthTier: 60);
    for (final p in team.players.where((p) => p.position == Position.fw)) {
      p.injuryWeeks = 2;
    }
    LineupUtils.autoFill(team);
    final byId = {for (final p in team.players) p.id: p};
    final lineup = team.startingXI.map((id) => byId[id]!).toList();
    expect(lineup.every((p) => !p.isInjured), isTrue);
  });

  test('TransferMarket.generate returns the requested count', () {
    final market = TransferMarket.generate(count: 7);
    expect(market.length, 7);
  });

  test('BoardEngine confidence deltas reward wins and punish bad losses', () {
    final win = MatchResult(matchday: 1, homeTeamId: 'user', awayTeamId: 'cpu', homeGoals: 2, awayGoals: 0, events: []);
    final loss = MatchResult(matchday: 1, homeTeamId: 'user', awayTeamId: 'cpu', homeGoals: 0, awayGoals: 2, events: []);
    expect(BoardEngine.confidenceDeltaForMatch(win, 'user'), greaterThan(0));
    expect(BoardEngine.confidenceDeltaForMatch(loss, 'user'), lessThan(0));
  });

  test('BoardEngine.seasonPrizeMoney gives 1st place more than last place', () {
    final first = BoardEngine.seasonPrizeMoney(finalRank: 1, teamCount: 8);
    final last = BoardEngine.seasonPrizeMoney(finalRank: 8, teamCount: 8);
    expect(first, greaterThan(last));
  });

  test('GameState.buyPlayer deducts budget and adds the player to the squad', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final beforeCount = gameState.userTeam.players.length;
    final target = gameState.transferMarket.first;
    gameState.save!.budget = target.marketValue + 100;

    final ok = await gameState.buyPlayer(target.id);

    expect(ok, isTrue);
    expect(gameState.userTeam.players.length, beforeCount + 1);
    expect(gameState.save!.budget, 100);
  });

  test('GameState.buyPlayer fails when budget is insufficient', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final target = gameState.transferMarket.first;
    gameState.save!.budget = 0;

    final ok = await gameState.buyPlayer(target.id);

    expect(ok, isFalse);
  });

  test('GameState.sellPlayer refuses to drop below the minimum squad size', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    while (gameState.userTeam.players.length > minSquadSize) {
      final id = gameState.userTeam.players.first.id;
      await gameState.sellPlayer(id);
    }
    final lastId = gameState.userTeam.players.first.id;
    final ok = await gameState.sellPlayer(lastId);
    expect(ok, isFalse);
  });

  test('ContractEngine.advanceWeek decrements contracts and removes expired players', () {
    final team = PlayerGenerator.generateSquad(id: 't3', name: 'Test FC', strengthTier: 60);
    final soonToExpire = team.players.first;
    soonToExpire.contractWeeksRemaining = 1;
    team.startingXI = [soonToExpire.id];
    final beforeCount = team.players.length;

    final expired = ContractEngine.advanceWeek(team);

    expect(expired.map((p) => p.id), contains(soonToExpire.id));
    expect(team.players.length, beforeCount - 1);
    expect(team.startingXI, isNot(contains(soonToExpire.id)));
  });

  test('ContractEngine.weeklyWageBill sums all player wages', () {
    final team = PlayerGenerator.generateSquad(id: 't4', name: 'Test FC', strengthTier: 60);
    final expectedTotal = team.players.fold<int>(0, (s, p) => s + p.wage);
    expect(ContractEngine.weeklyWageBill(team), expectedTotal);
  });

  test('ScoutingEngine prospects are young academy-age players', () {
    final scouted = ScoutingEngine.generateScoutedProspect();
    final academy = ScoutingEngine.generateAcademyGraduate();
    expect(scouted.age, inInclusiveRange(16, 19));
    expect(academy.age, inInclusiveRange(16, 19));
  });

  test('TrainingEngine respects a player individual focus override', () {
    final team = PlayerGenerator.generateSquad(id: 't5', name: 'Test FC', strengthTier: 60);
    team.defaultTrainingFocus = TrainingFocus.rest;
    final target = team.players.firstWhere((p) => p.position == Position.fw);
    target.individualFocus = TrainingFocus.attack;
    target.attack = 40;
    target.potential = 99;
    target.fatigue = 50;

    // 個別方針(attack)が休養より疲労を増やす方向に働くことを確認する。
    final fatigueBefore = target.fatigue;
    TrainingEngine.applyWeeklyTraining(team);
    expect(target.fatigue, greaterThanOrEqualTo(fatigueBefore));
  });

  test('MatchEngine.simulate runs without error under extreme tactic settings', () {
    final aggressive = PlayerGenerator.generateSquad(id: 'agg', name: 'Aggressive FC', strengthTier: 60);
    final defensive = PlayerGenerator.generateSquad(id: 'def', name: 'Defensive FC', strengthTier: 60);
    aggressive.lineHeight = 100;
    aggressive.pressing = 100;
    defensive.lineHeight = 0;
    defensive.pressing = 0;
    LineupUtils.autoFill(aggressive);
    LineupUtils.autoFill(defensive);

    final result = MatchEngine.simulate(home: aggressive, away: defensive, matchday: 1);

    expect(result.homeGoals, greaterThanOrEqualTo(0));
    expect(result.awayGoals, greaterThanOrEqualTo(0));
  });

  test('GameState.scoutProspect deducts budget and adds a youth prospect', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    gameState.save!.budget = ScoutingEngine.scoutCost;

    final ok = await gameState.scoutProspect();

    expect(ok, isTrue);
    expect(gameState.save!.youthProspects.length, 1);
    expect(gameState.save!.budget, 0);
  });

  test('GameState.promoteYouthProspect moves the prospect into the squad', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    gameState.save!.budget = ScoutingEngine.scoutCost;
    await gameState.scoutProspect();
    final prospect = gameState.save!.youthProspects.first;
    final beforeCount = gameState.userTeam.players.length;

    final ok = await gameState.promoteYouthProspect(prospect.id);

    expect(ok, isTrue);
    expect(gameState.save!.youthProspects, isEmpty);
    expect(gameState.userTeam.players.length, beforeCount + 1);
  });

  test('GameState.renewContract deducts cost and resets contract length', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final player = gameState.userTeam.players.first;
    player.contractWeeksRemaining = 2;
    final cost = gameState.renewalCostFor(player.id);
    gameState.save!.budget = cost;

    final ok = await gameState.renewContract(player.id);

    expect(ok, isTrue);
    expect(player.contractWeeksRemaining, ContractEngine.renewalWeeks);
    expect(gameState.save!.budget, 0);
  });
}
