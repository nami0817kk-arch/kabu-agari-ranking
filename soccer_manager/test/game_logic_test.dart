import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/board_engine.dart';
import 'package:soccer_manager/logic/lineup_utils.dart';
import 'package:soccer_manager/logic/player_generator.dart';
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
}
