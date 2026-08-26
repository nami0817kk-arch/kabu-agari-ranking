import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/ai_transfer_engine.dart';
import 'package:soccer_manager/logic/awards_engine.dart';
import 'package:soccer_manager/logic/best_eleven_engine.dart';
import 'package:soccer_manager/logic/board_engine.dart';
import 'package:soccer_manager/logic/contract_engine.dart';
import 'package:soccer_manager/logic/continental_cup_engine.dart';
import 'package:soccer_manager/logic/cup_engine.dart';
import 'package:soccer_manager/logic/happiness_engine.dart';
import 'package:soccer_manager/logic/lineup_utils.dart';
import 'package:soccer_manager/logic/loan_engine.dart';
import 'package:soccer_manager/logic/match_engine.dart';
import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/promotion_engine.dart';
import 'package:soccer_manager/logic/retirement_engine.dart';
import 'package:soccer_manager/logic/rotation_engine.dart';
import 'package:soccer_manager/logic/super_cup_engine.dart';
import 'package:soccer_manager/logic/scout_report_engine.dart';
import 'package:soccer_manager/logic/scouting_engine.dart';
import 'package:soccer_manager/logic/season_projection_engine.dart';
import 'package:soccer_manager/logic/sponsor_engine.dart';
import 'package:soccer_manager/logic/training_engine.dart';
import 'package:soccer_manager/logic/transfer_market.dart';
import 'package:soccer_manager/logic/weather_engine.dart';
import 'package:soccer_manager/data/name_pool.dart';
import 'package:soccer_manager/models/attributes.dart';
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/models/contract_negotiation.dart';
import 'package:soccer_manager/models/cup.dart';
import 'package:soccer_manager/models/formation.dart';
import 'package:soccer_manager/models/incoming_offer.dart';
import 'package:soccer_manager/models/league.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/models/match_result.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/save_game.dart';
import 'package:soccer_manager/models/team.dart';
import 'package:soccer_manager/models/weather.dart';
import 'package:soccer_manager/screens/squad_screen.dart';
import 'package:soccer_manager/screens/transfer_screen.dart';
import 'package:soccer_manager/screens/young_talent_screen.dart';
import 'package:soccer_manager/state/game_state.dart';
import 'package:soccer_manager/widgets/formation_layout.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
      'LineupUtils.autoFill fills all 11 formation slots with a real goalkeeper in goal',
      () {
    final team = PlayerGenerator.generateSquad(
        id: 't1', name: 'Test FC', strengthTier: 60);
    team.formation = Formation.f433;
    LineupUtils.autoFill(team);

    expect(team.startingXI.length, 11);
    expect(team.startingXI.toSet().length, 11);
    final byId = {for (final p in team.players) p.id: p};
    // 副ポジションはグループを跨いで設定されうる(例: トップ下がセンターMFを兼任)ため、
    // グループ単位の人数一致までは保証されない。ただしGK枠は他ポジションの副ポジション
    // 候補になり得ないため、常にGKで埋まることは保証できる。
    expect(byId[team.startingXI.first]!.position, Position.gk);
  });

  test('LineupUtils.autoFill excludes injured players', () {
    final team = PlayerGenerator.generateSquad(
        id: 't2', name: 'Test FC', strengthTier: 60);
    for (final p in team.players.where((p) => p.position == Position.st)) {
      p.injuryWeeks = 2;
    }
    LineupUtils.autoFill(team);
    final byId = {for (final p in team.players) p.id: p};
    final lineup = team.startingXI.map((id) => byId[id]!).toList();
    expect(lineup.every((p) => !p.isInjured), isTrue);
  });

  test(
      'LineupUtils.autoFill falls back to same-group players when a position is missing',
      () {
    final team = PlayerGenerator.generateSquad(
        id: 't1b', name: 'Test FC', strengthTier: 60);
    team.players.removeWhere((p) => p.position == Position.st);
    team.formation = Formation.f442; // needs 2 ST, none available
    LineupUtils.autoFill(team);

    expect(team.startingXI.length, 11);
    final byId = {for (final p in team.players) p.id: p};
    final lineup = team.startingXI.map((id) => byId[id]!).toList();
    // ST枠はATTグループの他ポジション(AMR/AMC/AML)で代用されているはず
    expect(lineup.any((p) => p.position.group == PositionGroup.att), isTrue);
  });

  test('TransferMarket.generate returns the requested count', () {
    final market = TransferMarket.generate(count: 7);
    expect(market.length, 7);
  });

  test('BoardEngine confidence deltas reward wins and punish bad losses', () {
    final win = MatchResult(
        matchday: 1,
        homeTeamId: 'user',
        awayTeamId: 'cpu',
        homeGoals: 2,
        awayGoals: 0,
        events: []);
    final loss = MatchResult(
        matchday: 1,
        homeTeamId: 'user',
        awayTeamId: 'cpu',
        homeGoals: 0,
        awayGoals: 2,
        events: []);
    expect(BoardEngine.confidenceDeltaForMatch(win, 'user'), greaterThan(0));
    expect(BoardEngine.confidenceDeltaForMatch(loss, 'user'), lessThan(0));
  });

  test('BoardEngine.seasonPrizeMoney gives 1st place more than last place', () {
    final first = BoardEngine.seasonPrizeMoney(finalRank: 1, teamCount: 8);
    final last = BoardEngine.seasonPrizeMoney(finalRank: 8, teamCount: 8);
    expect(first, greaterThan(last));
  });

  test(
      'BoardEngine.midSeasonReviewDelta rewards being on pace and punishes '
      'badly trailing the target', () {
    expect(BoardEngine.midSeasonReviewDelta(currentRank: 2, targetRank: 4),
        greaterThan(0));
    expect(BoardEngine.midSeasonReviewDelta(currentRank: 5, targetRank: 4), 0);
    expect(BoardEngine.midSeasonReviewDelta(currentRank: 10, targetRank: 4),
        lessThan(0));
  });

  test(
      'GameState.playNextMatchday triggers exactly one board review at mid-season',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    expect(gameState.save!.boardReviewDoneThisSeason, isFalse);

    var reviewSeenCount = 0;
    while (!gameState.save!.league.isSeasonComplete) {
      await gameState.playNextMatchday();
      if (gameState.isHalfTime) {
        await gameState.playSecondHalf();
      }
      if (gameState.pendingBoardReviewMessage != null) {
        reviewSeenCount++;
        await gameState.dismissBoardReview();
      }
    }

    expect(reviewSeenCount, 1);
    expect(gameState.save!.boardReviewDoneThisSeason, isTrue);
  });

  test(
      'GameState.playSecondHalf advances the manager-of-the-month checkpoint '
      'in steps of 4 matchdays and resets it for the next season', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');

    var lastCheckpoint = 0;
    while (!gameState.save!.league.isSeasonComplete) {
      await gameState.playNextMatchday();
      if (gameState.isHalfTime) {
        await gameState.playSecondHalf();
      }
      final checkpoint = gameState.save!.lastManagerOfMonthCheckpoint;
      expect(checkpoint - lastCheckpoint, anyOf(0, 4));
      lastCheckpoint = checkpoint;
    }

    await gameState.startNextSeason();
    expect(gameState.save!.lastManagerOfMonthCheckpoint, 0);
  });

  test('GameState.buyPlayer deducts budget and adds the player to the squad',
      () async {
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

  test('GameState.sellPlayer refuses to drop below the minimum squad size',
      () async {
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

  test(
      'ContractEngine.advanceWeek decrements contracts and removes expired players',
      () {
    final team = PlayerGenerator.generateSquad(
        id: 't3', name: 'Test FC', strengthTier: 60);
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
    final team = PlayerGenerator.generateSquad(
        id: 't4', name: 'Test FC', strengthTier: 60);
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
    final team = PlayerGenerator.generateSquad(
        id: 't5', name: 'Test FC', strengthTier: 60);
    team.defaultTrainingFocus = TrainingFocus.rest;
    final target = team.players.firstWhere((p) => p.position == Position.st);
    target.individualFocus = TrainingFocus.attack;
    target.setAttributeValue(AttributeKeys.finishing, 40);
    target.potential = 99;
    target.fatigue = 50;

    // 個別方針(attack)が休養より疲労を増やす方向に働くことを確認する。
    final fatigueBefore = target.fatigue;
    TrainingEngine.applyWeeklyTraining(team);
    expect(target.fatigue, greaterThanOrEqualTo(fatigueBefore));
  });

  test('MatchEngine.simulate runs without error under extreme tactic settings',
      () {
    final aggressive = PlayerGenerator.generateSquad(
        id: 'agg', name: 'Aggressive FC', strengthTier: 60);
    final defensive = PlayerGenerator.generateSquad(
        id: 'def', name: 'Defensive FC', strengthTier: 60);
    aggressive.lineHeight = 100;
    aggressive.pressing = 100;
    defensive.lineHeight = 0;
    defensive.pressing = 0;
    LineupUtils.autoFill(aggressive);
    LineupUtils.autoFill(defensive);

    final result =
        MatchEngine.simulate(home: aggressive, away: defensive, matchday: 1);

    expect(result.homeGoals, greaterThanOrEqualTo(0));
    expect(result.awayGoals, greaterThanOrEqualTo(0));
  });

  test('MatchEngine.lineupOf excludes suspended players from the starting XI',
      () {
    final team = PlayerGenerator.generateSquad(
        id: 'susp', name: 'Suspend FC', strengthTier: 60);
    LineupUtils.autoFill(team);
    final suspended =
        team.players.firstWhere((p) => team.startingXI.contains(p.id));
    suspended.suspendedMatches = 1;

    final lineup = MatchEngine.lineupOf(team);

    expect(lineup.any((p) => p.id == suspended.id), isFalse);
  });

  test(
      'MatchEngine.applyPostMatchEffects only counts down suspensions for '
      'players who actually sat the match out', () {
    final home = PlayerGenerator.generateSquad(
        id: 'home', name: 'Home FC', strengthTier: 60);
    final away = PlayerGenerator.generateSquad(
        id: 'away', name: 'Away FC', strengthTier: 60);
    LineupUtils.autoFill(home);
    LineupUtils.autoFill(away);

    // 出場停止中でスタメン対象外の選手(前節までに受けた出場停止): 今節を
    // 消化したので1減るはず。
    final benched =
        home.players.firstWhere((p) => !home.startingXI.contains(p.id));
    benched.suspendedMatches = 2;
    // 今節に退場処分を受けるスタメン選手: 今節はまだ出場するので、退場の
    // 出場停止は今節では消化されず、次節から適用されるはず(据え置きで1)。
    final justSentOff =
        home.players.firstWhere((p) => home.startingXI.contains(p.id));

    MatchEngine.applyPostMatchEffects(
      home: home,
      away: away,
      events: [
        MatchEvent(
          minute: 10,
          teamId: home.id,
          scorerName: justSentOff.name,
          scorerId: justSentOff.id,
          type: MatchEventType.redCard,
        ),
      ],
    );

    expect(benched.suspendedMatches, 1);
    expect(justSentOff.suspendedMatches, 1);
  });

  test(
      'MatchEngine.applyPostMatchEffects suspends a player once yellow cards '
      'reach the threshold, and resets the counter', () {
    final home = PlayerGenerator.generateSquad(
        id: 'home2', name: 'Home FC 2', strengthTier: 60);
    final away = PlayerGenerator.generateSquad(
        id: 'away2', name: 'Away FC 2', strengthTier: 60);
    LineupUtils.autoFill(home);
    LineupUtils.autoFill(away);

    final player =
        home.players.firstWhere((p) => home.startingXI.contains(p.id));
    player.yellowCards = yellowCardSuspensionThreshold - 1;

    MatchEngine.applyPostMatchEffects(
      home: home,
      away: away,
      events: [
        MatchEvent(
          minute: 20,
          teamId: home.id,
          scorerName: player.name,
          scorerId: player.id,
          type: MatchEventType.yellowCard,
        ),
      ],
    );

    expect(player.yellowCards, 0);
    expect(player.suspendedMatches, 1);
  });

  test(
      'MatchEngine.computePlayerRatings rewards goals and penalizes red '
      'cards, and MatchResult.manOfTheMatchId picks the top scorer', () {
    final home = PlayerGenerator.generateSquad(
        id: 'home3', name: 'Home FC 3', strengthTier: 60);
    final away = PlayerGenerator.generateSquad(
        id: 'away3', name: 'Away FC 3', strengthTier: 60);
    LineupUtils.autoFill(home);
    LineupUtils.autoFill(away);

    final scorer =
        home.players.firstWhere((p) => home.startingXI.contains(p.id));
    final cardedAwayPlayer =
        away.players.firstWhere((p) => away.startingXI.contains(p.id));

    final events = [
      MatchEvent(
          minute: 10,
          teamId: home.id,
          scorerName: scorer.name,
          scorerId: scorer.id),
      MatchEvent(
        minute: 30,
        teamId: away.id,
        scorerName: cardedAwayPlayer.name,
        scorerId: cardedAwayPlayer.id,
        type: MatchEventType.redCard,
      ),
    ];

    final ratings = MatchEngine.computePlayerRatings(
      home: home,
      away: away,
      events: events,
      homeGoals: 1,
      awayGoals: 0,
    );

    expect(ratings[scorer.id], greaterThan(6.0));
    expect(ratings[cardedAwayPlayer.id], lessThan(6.0));

    final result = MatchResult(
      matchday: 1,
      homeTeamId: home.id,
      awayTeamId: away.id,
      homeGoals: 1,
      awayGoals: 0,
      events: events,
      playerRatings: ratings,
    );
    expect(result.manOfTheMatchId, scorer.id);
  });

  test(
      'MatchEngine.applyPostMatchEffects tallies career appearances and '
      'goals for the players who took part', () {
    final home = PlayerGenerator.generateSquad(
        id: 'home4', name: 'Home FC 4', strengthTier: 60);
    final away = PlayerGenerator.generateSquad(
        id: 'away4', name: 'Away FC 4', strengthTier: 60);
    LineupUtils.autoFill(home);
    LineupUtils.autoFill(away);

    final scorer =
        home.players.firstWhere((p) => home.startingXI.contains(p.id));
    final benched =
        home.players.firstWhere((p) => !home.startingXI.contains(p.id));

    MatchEngine.applyPostMatchEffects(
      home: home,
      away: away,
      events: [
        MatchEvent(
            minute: 5,
            teamId: home.id,
            scorerName: scorer.name,
            scorerId: scorer.id),
      ],
    );

    expect(scorer.careerAppearances, 1);
    expect(scorer.careerGoals, 1);
    expect(benched.careerAppearances, 0);
  });

  test('RetirementEngine.retirementChance is zero below 32 and rises with age',
      () {
    final young = PlayerGenerator.generate(
        position: Position.st, strengthTier: 60, ageOverride: 25);
    final veteran = PlayerGenerator.generate(
        position: Position.st, strengthTier: 60, ageOverride: 37);

    expect(RetirementEngine.retirementChance(young), 0.0);
    expect(RetirementEngine.retirementChance(veteran), greaterThan(0.0));
  });

  test('RetirementEngine.resolveRetirements removes retirees from the squad',
      () {
    final team = PlayerGenerator.generateSquad(
        id: 'ret', name: 'Retire FC', strengthTier: 60);
    LineupUtils.autoFill(team);
    // 90%の確率で引退する年齢に全員を揃え、23人独立試行でほぼ確実に
    // 1人以上引退する状況を作る(単独選手の抽選に依存しない安定したテストにする)。
    for (final p in team.players) {
      p.age = 45;
    }

    final retirees = RetirementEngine.resolveRetirements(team);

    expect(retirees, isNotEmpty);
    for (final r in retirees) {
      expect(team.players.contains(r), isFalse);
      expect(team.startingXI.contains(r.id), isFalse);
    }
  });

  test('GameState.scoutProspect deducts budget and adds a youth prospect',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    gameState.save!.budget = ScoutingEngine.scoutCost;
    final candidateId = gameState.scoutCandidates.first.id;
    final poolSizeBefore = gameState.scoutCandidates.length;

    final ok = await gameState.scoutProspect(candidateId);

    expect(ok, isTrue);
    expect(gameState.save!.youthProspects.length, 1);
    expect(gameState.save!.youthProspects.first.id, candidateId);
    expect(gameState.save!.budget, 0);
    // 選んだ候補は補充され、閲覧できる候補数は変わらない。
    expect(gameState.scoutCandidates.length, poolSizeBefore);
    expect(gameState.scoutCandidates.any((p) => p.id == candidateId), isFalse);
  });

  test(
      'GameState.scoutCandidates offers more candidates as scout staff level rises',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final baseCount = gameState.scoutCandidates.length;
    gameState.save!.budget = 100000;

    await gameState.upgradeStaff(StaffRole.scout);

    expect(gameState.scoutCandidateCount, baseCount + 1);
  });

  test('GameState.promoteYouthProspect moves the prospect into the squad',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    gameState.save!.budget = ScoutingEngine.scoutCost;
    final candidateId = gameState.scoutCandidates.first.id;
    await gameState.scoutProspect(candidateId);
    final prospect = gameState.save!.youthProspects.first;
    final beforeCount = gameState.userTeam.players.length;

    final ok = await gameState.promoteYouthProspect(prospect.id);

    expect(ok, isTrue);
    expect(gameState.save!.youthProspects, isEmpty);
    expect(gameState.userTeam.players.length, beforeCount + 1);
  });

  test('PlayerGenerator populates all 42 detailed attributes within range', () {
    final p = PlayerGenerator.generate(position: Position.mc, strengthTier: 60);
    expect(p.attributes.keys.toSet(), AttributeKeys.all.toSet());
    for (final key in AttributeKeys.all) {
      expect(p.attributeValue(key), inInclusiveRange(1, 99));
    }
  });

  test('Goalkeepers have much higher goalkeeping attributes than forwards', () {
    final gk =
        PlayerGenerator.generate(position: Position.gk, strengthTier: 60);
    final fw =
        PlayerGenerator.generate(position: Position.st, strengthTier: 60);
    expect(gk.attributeValue(AttributeKeys.handling),
        greaterThan(fw.attributeValue(AttributeKeys.handling)));
    expect(gk.attributeValue(AttributeKeys.reflexes),
        greaterThan(fw.attributeValue(AttributeKeys.reflexes)));
  });

  test('Player.overall is the average of the four composite ratings', () {
    final p = PlayerGenerator.generate(position: Position.mc, strengthTier: 60);
    final expected =
        ((p.attack + p.defense + p.technique + p.stamina) / 4).round();
    expect(p.overall, expected);
  });

  test('Player.fromJson migrates a legacy save without an attributes map', () {
    final legacyJson = {
      'id': 'legacy1',
      'name': 'Legacy Player',
      'age': 25,
      'position': 'mf',
      'attack': 70,
      'defense': 60,
      'technique': 65,
      'stamina': 55,
      'potential': 75,
    };
    final p = Player.fromJson(legacyJson);
    expect(p.attributeValue(AttributeKeys.finishing), 70);
    expect(p.attributeValue(AttributeKeys.tackling), 60);
    expect(p.attributeValue(AttributeKeys.passing), 65);
    expect(p.attributeValue(AttributeKeys.stamina), 55);
  });

  test('parsePosition migrates legacy df/mf/fw position names', () {
    expect(parsePosition('df'), Position.dc);
    expect(parsePosition('mf'), Position.mc);
    expect(parsePosition('fw'), Position.st);
    expect(parsePosition('gk'), Position.gk);
    expect(parsePosition('amc'), Position.amc);
  });

  test('Formation.f442 has 11 slots matching its label composition', () {
    final slots = Formation.f442.slots;
    expect(slots.length, 11);
    expect(slots.where((p) => p == Position.gk).length, 1);
    expect(slots.where((p) => p == Position.st).length, 2);
    expect(slots.where((p) => p.group == PositionGroup.def).length, 4);
    expect(slots.where((p) => p.group == PositionGroup.mid).length, 4);
  });

  test(
      'Every Formation has 11 slots and a matching FormationLayout coordinate entry',
      () {
    for (final formation in Formation.values) {
      final slots = formation.slots;
      expect(slots.length, 11,
          reason: '${formation.name} should have exactly 11 slots');
      final offsets = FormationLayout.offsetsFor(formation);
      expect(offsets.length, slots.length,
          reason:
              '${formation.name} layout coordinates must match its slot count');
    }
  });

  test(
      'Formation.f4141 and f343 add distinct shapes not covered by the original four',
      () {
    expect(Formation.f4141.slots.where((p) => p == Position.dm).length, 1);
    expect(
        Formation.f4141.slots.where((p) => p.group == PositionGroup.def).length,
        4);
    expect(Formation.f343.slots.where((p) => p == Position.dc).length, 3);
    expect(Formation.f343.slots.where((p) => p == Position.st).length, 1);
  });

  test('Team.fromJson falls back to f442 for a removed formation name', () {
    final team = PlayerGenerator.generateSquad(
        id: 'tf', name: 'Test FC', strengthTier: 60);
    final json = team.toJson();
    json['formation'] = 'f532'; // 廃止された旧フォーメーション名
    final restored = Team.fromJson(json);
    expect(restored.formation, Formation.f442);
  });

  test('GameState.renewContract deducts cost and resets contract length',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final player = gameState.userTeam.players.first;
    player.contractWeeksRemaining = 2;
    final cost = gameState.renewalCostFor(player.id) +
        gameState.signingBonusFor(player.id);
    gameState.save!.budget = cost;

    final ok = await gameState.renewContract(player.id);

    expect(ok, isTrue);
    expect(player.contractWeeksRemaining, ContractEngine.renewalWeeks);
    expect(gameState.save!.budget, 0);
  });

  test('ClubInfrastructure upgrades increase level and cost more each time',
      () {
    final infra = ClubInfrastructure();
    expect(infra.staffLevel(StaffRole.physio), 1);
    final firstCost =
        ClubInfrastructure.staffUpgradeCost(infra.staffLevel(StaffRole.physio));

    final upgraded = infra.upgradeStaff(StaffRole.physio);

    expect(upgraded, isTrue);
    expect(infra.staffLevel(StaffRole.physio), 2);
    final secondCost =
        ClubInfrastructure.staffUpgradeCost(infra.staffLevel(StaffRole.physio));
    expect(secondCost, greaterThan(firstCost));
  });

  test('ClubInfrastructure staff cannot upgrade past max level', () {
    final infra = ClubInfrastructure();
    for (int i = 0; i < ClubInfrastructure.maxLevel - 1; i++) {
      expect(infra.upgradeStaff(StaffRole.scout), isTrue);
    }
    expect(infra.staffLevel(StaffRole.scout), ClubInfrastructure.maxLevel);
    expect(infra.upgradeStaff(StaffRole.scout), isFalse);
  });

  test('GameState.upgradeFacility deducts budget and raises the level',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final cost = gameState.facilityUpgradeCostFor(FacilityType.stadium);
    gameState.save!.budget = cost;

    final ok = await gameState.upgradeFacility(FacilityType.stadium);

    expect(ok, isTrue);
    expect(
        gameState.save!.infrastructure.facilityLevel(FacilityType.stadium), 2);
    expect(gameState.save!.budget, 0);
  });

  test('GameState.upgradeStaff fails when budget is insufficient', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    gameState.save!.budget = 0;

    final ok = await gameState.upgradeStaff(StaffRole.headCoach);

    expect(ok, isFalse);
    expect(gameState.save!.infrastructure.staffLevel(StaffRole.headCoach), 1);
  });

  test(
      'CupEngine.createKnockout builds a full bracket for a power-of-two field with no byes',
      () {
    final teamIds = List.generate(8, (i) => 't$i');
    final cup = CupEngine.createKnockout(
        type: CupType.domestic, name: '国内カップ', teamIds: teamIds);

    expect(cup.rounds.length, 1);
    expect(cup.rounds.first.length, 4);
    expect(cup.rounds.first.every((m) => !m.isBye), isTrue);
  });

  test(
      'CupEngine.playNextMatch advances rounds until a single champion remains',
      () {
    final teams = List.generate(
        8,
        (i) => PlayerGenerator.generateSquad(
            id: 't$i', name: 'Club $i', strengthTier: 60));
    for (final t in teams) {
      LineupUtils.autoFill(t);
    }
    final cup = CupEngine.createKnockout(
      type: CupType.domestic,
      name: '国内カップ',
      teamIds: teams.map((t) => t.id).toList(),
    );

    // 8チーム(準々決勝4+準決勝2+決勝1=7試合)を全て消化する。
    for (int i = 0; i < 7; i++) {
      final result = CupEngine.playNextMatch(cup, teams);
      expect(result, isNotNull);
    }

    expect(cup.isComplete, isTrue);
    expect(cup.championId, isNotNull);
    expect(cup.rounds.length, 3);
    expect(CupEngine.playNextMatch(cup, teams), isNull);
  });

  test(
      'GameState creates a domestic cup on new game that can be played to completion',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');

    expect(gameState.domesticCup, isNotNull);
    expect(gameState.continentalCup, isNull);

    int guard = 0;
    do {
      await gameState.playNextCupMatch();
      guard++;
    } while (gameState.domesticCup!.nextUnplayedMatch != null && guard < 20);

    expect(gameState.domesticCup!.isComplete, isTrue);
  });

  test(
      'GameState.startNewGame names the domestic cup after the chosen '
      'league theme', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC', theme: LeagueTheme.spain);

    expect(gameState.domesticCup!.name, LeagueTheme.spain.domesticCupName);
  });

  test(
      'ContinentalCupEngine.create splits teams into 4-team groups with a '
      'full round robin', () {
    final ids = List.generate(8, (i) => 't$i');
    final cup = ContinentalCupEngine.create(name: '大陸カップ', teamIds: ids);

    expect(cup.groups.length, 2);
    expect(cup.groups.expand((g) => g).toSet(), ids.toSet());
    expect(cup.groupMatches.length, 12);
    for (final group in cup.groups) {
      for (final id in group) {
        final played = cup.groupMatches
            .where((m) => m.homeTeamId == id || m.awayTeamId == id)
            .length;
        expect(played, 3);
      }
    }
  });

  test(
      'ContinentalCupEngine plays from the group stage through to a champion, '
      'swapping home/away for the second knockout leg', () {
    final teams = List.generate(
        8,
        (i) => PlayerGenerator.generateSquad(
            id: 'c$i', name: 'Club $i', strengthTier: 60));
    for (final t in teams) {
      LineupUtils.autoFill(t);
    }
    final cup = ContinentalCupEngine.create(
        name: '大陸カップ', teamIds: teams.map((t) => t.id).toList());

    int guard = 0;
    while (!cup.isGroupStageComplete && guard < 50) {
      ContinentalCupEngine.playNextGroupMatch(cup, teams);
      guard++;
    }
    expect(cup.isGroupStageComplete, isTrue);
    expect(cup.knockoutRounds.length, 1);
    expect(cup.knockoutRounds.first.length, 2);

    // 準決勝は同組同士が当たらないよう、他組の2位とクロスで組まれる。
    for (final tie in cup.knockoutRounds.first) {
      final groupOfA = cup.groups.indexWhere((g) => g.contains(tie.teamAId));
      final groupOfB = cup.groups.indexWhere((g) => g.contains(tie.teamBId));
      expect(groupOfA, isNot(groupOfB));
    }

    guard = 0;
    while (!cup.isComplete && guard < 50) {
      ContinentalCupEngine.playNextKnockoutLeg(cup, teams);
      guard++;
    }

    expect(cup.isComplete, isTrue);
    expect(cup.championId, isNotNull);
    expect(cup.knockoutRounds.length, 2);
    final finalTie = cup.knockoutRounds.last.first;
    expect(finalTie.singleLeg, isTrue);
    expect(finalTie.legs.length, 1);

    final semi = cup.knockoutRounds.first.first;
    expect(semi.legs.length, 2);
    expect(semi.legs[0].homeTeamId, semi.teamAId);
    expect(semi.legs[1].homeTeamId, semi.teamBId);
  });

  test(
      "GameState.startNextSeason creates a continental cup with two 4-team "
      "groups when the user finishes in the league's top two", () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final userId = gameState.userTeam.id;
    for (final f in gameState.save!.league.fixtures) {
      final userIsHome = f.homeTeamId == userId;
      final userIsAway = f.awayTeamId == userId;
      f.result = MatchResult(
        matchday: f.matchday,
        homeTeamId: f.homeTeamId,
        awayTeamId: f.awayTeamId,
        homeGoals: userIsHome ? 3 : (userIsAway ? 0 : 1),
        awayGoals: userIsHome ? 0 : (userIsAway ? 3 : 1),
        events: [],
      );
    }

    await gameState.startNextSeason();

    expect(gameState.continentalCup, isNotNull);
    final cup = gameState.continentalCup!;
    expect(cup.groups.length, 2);
    expect(cup.groups.expand((g) => g), contains(userId));
  });

  test(
      'HappinessEngine boosts happiness for starters and penalizes benched players',
      () {
    final team = PlayerGenerator.generateSquad(
        id: 'hteam', name: 'Happy FC', strengthTier: 60);
    LineupUtils.autoFill(team);
    for (final p in team.players) {
      p.happiness = 50;
      p.personality = PlayerPersonality.balanced;
    }
    final starter =
        team.players.firstWhere((p) => team.startingXI.contains(p.id));
    final benched =
        team.players.firstWhere((p) => !team.startingXI.contains(p.id));
    // 待遇要因を打ち消して出場機会の影響だけを検証できるようにする。
    starter.wage = 99999;
    benched.wage = 1;

    HappinessEngine.applyWeekly(team, leagueRank: 1, boardTargetRank: 4);

    expect(starter.happiness, greaterThan(50));
    expect(benched.happiness, lessThan(50));
  });

  test(
      'HappinessEngine.reassure raises happiness but not above the threshold gate',
      () {
    final p = PlayerGenerator.generate(position: Position.st, strengthTier: 60);
    p.happiness = 20;

    final ok = HappinessEngine.reassure(p);

    expect(ok, isTrue);
    expect(p.happiness, 40);
  });

  test('HappinessEngine.reassure fails once happiness is already high', () {
    final p = PlayerGenerator.generate(position: Position.st, strengthTier: 60);
    p.happiness = 80;

    final ok = HappinessEngine.reassure(p);

    expect(ok, isFalse);
    expect(p.happiness, 80);
  });

  test('Player.wantsTransfer reflects personality-specific thresholds', () {
    final p = PlayerGenerator.generate(position: Position.st, strengthTier: 60);
    p.personality = PlayerPersonality.ambitious; // 閾値30

    p.happiness = 35;
    expect(p.wantsTransfer, isFalse);

    p.happiness = 29;
    expect(p.wantsTransfer, isTrue);
  });

  test('SponsorEngine.generateOffers trades higher income for shorter duration',
      () {
    final offers = SponsorEngine.generateOffers(70);
    expect(offers.length, 3);
    final sorted = [...offers]
      ..sort((a, b) => a.weeklyIncome.compareTo(b.weeklyIncome));
    expect(
        sorted.first.weeksRemaining, greaterThan(sorted.last.weeksRemaining));
  });

  test('GameState.chooseSponsor applies the selected deal and clears offers',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    expect(gameState.pendingSponsorOffers, isNotEmpty);

    final ok = await gameState.chooseSponsor(0);

    expect(ok, isTrue);
    expect(gameState.save!.sponsorDeal, isNotNull);
    expect(gameState.pendingSponsorOffers, isEmpty);
  });

  test(
      'GameState.signLoanPlayer adds a loan player that returns after loanDurationWeeks',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final target = gameState.transferMarket.first;
    gameState.save!.budget = target.marketValue; // ローン料は移籍金の一部で足りるはず

    final ok = await gameState.signLoanPlayer(target.id);

    expect(ok, isTrue);
    final signed =
        gameState.userTeam.players.firstWhere((p) => p.id == target.id);
    expect(signed.isLoan, isTrue);
    expect(signed.loanWeeksRemaining, GameState.loanDurationWeeks);
  });

  test(
      'GameState.signLoanPlayer with a buy option lets exerciseLoanBuyOption '
      'convert the loan into a permanent signing', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final target = gameState.transferMarket.first;
    final expectedFee =
        (target.marketValue * GameState.loanBuyOptionRatio).round();
    gameState.save!.budget = target.marketValue + expectedFee;

    final signed =
        await gameState.signLoanPlayer(target.id, withBuyOption: true);
    expect(signed, isTrue);
    final player =
        gameState.userTeam.players.firstWhere((p) => p.id == target.id);
    expect(player.loanBuyOptionFee, expectedFee);
    final budgetBeforeBuyout = gameState.save!.budget;

    final bought = await gameState.exerciseLoanBuyOption(target.id);

    expect(bought, isTrue);
    expect(player.isLoan, isFalse);
    expect(player.loanWeeksRemaining, 0);
    expect(player.loanBuyOptionFee, isNull);
    expect(gameState.save!.budget, budgetBeforeBuyout - expectedFee);
  });

  test(
      'GameState.exerciseLoanBuyOption fails for a plain loan without a buy option',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final target = gameState.transferMarket.first;
    gameState.save!.budget = target.marketValue;
    await gameState.signLoanPlayer(target.id);
    gameState.save!.budget = 999999;

    final bought = await gameState.exerciseLoanBuyOption(target.id);

    expect(bought, isFalse);
  });

  test('Weather multipliers reflect worsening conditions for bad weather', () {
    expect(Weather.clear.attackMultiplier, 1.0);
    expect(Weather.clear.defenseMultiplier, 1.0);
    expect(Weather.clear.chanceCountMultiplier, 1.0);
    expect(Weather.clear.fatigueMultiplier, 1.0);

    for (final bad in [
      Weather.rain,
      Weather.wind,
      Weather.heatwave,
      Weather.snow,
    ]) {
      expect(bad.attackMultiplier, lessThan(1.0));
    }
    expect(Weather.heatwave.fatigueMultiplier, greaterThan(1.0));
    expect(Weather.snow.chanceCountMultiplier,
        lessThan(Weather.rain.chanceCountMultiplier));
  });

  test('WeatherEngine.roll eventually produces every weather type', () {
    final seen = <Weather>{};
    for (int i = 0; i < 2000 && seen.length < Weather.values.length; i++) {
      seen.add(WeatherEngine.roll());
    }
    expect(seen, containsAll(Weather.values));
  });

  test('MatchEngine.simulate records the requested weather on the result', () {
    final home = PlayerGenerator.generateSquad(
        id: 'wh', name: 'Home FC', strengthTier: 60);
    final away = PlayerGenerator.generateSquad(
        id: 'wa', name: 'Away FC', strengthTier: 60);
    LineupUtils.autoFill(home);
    LineupUtils.autoFill(away);

    final result = MatchEngine.simulate(
        home: home, away: away, matchday: 1, weather: Weather.snow);

    expect(result.weather, Weather.snow);
  });

  test('Fixture and MatchResult round-trip their weather through JSON', () {
    final fixture = Fixture(
      matchday: 3,
      homeTeamId: 'h',
      awayTeamId: 'a',
      weather: Weather.wind,
      result: MatchResult(
        matchday: 3,
        homeTeamId: 'h',
        awayTeamId: 'a',
        homeGoals: 1,
        awayGoals: 1,
        events: [],
        weather: Weather.wind,
      ),
    );

    final restored = Fixture.fromJson(fixture.toJson());

    expect(restored.weather, Weather.wind);
    expect(restored.result!.weather, Weather.wind);
  });

  test(
      'GameState.playNextMatchday assigns a weather to the fixture that carries through to playSecondHalf',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');

    await gameState.playNextMatchday();
    final fixture = gameState.liveFixture;
    expect(fixture, isNotNull);
    expect(fixture!.weather, isNotNull);

    if (gameState.isHalfTime) {
      final result = await gameState.playSecondHalf();
      expect(result!.weather, fixture.weather);
    }
  });

  test(
      'A designated penalty taker scores more often than a teammate with '
      'equal attack but no set-piece duty', () {
    Player makeOutfield(String id, Position pos, {int penalties = 50}) {
      final attrs = {for (final k in AttributeKeys.all) k: 60};
      attrs[AttributeKeys.penalties] = penalties;
      return Player(
        id: id,
        name: id,
        age: 25,
        position: pos,
        potential: 70,
        attributes: attrs,
      );
    }

    final gk = makeOutfield('gk', Position.gk);
    final defs = [for (int i = 0; i < 4; i++) makeOutfield('d$i', Position.dc)];
    final mids = [for (int i = 0; i < 4; i++) makeOutfield('m$i', Position.mc)];
    final strikerA = makeOutfield('strikerA', Position.st, penalties: 99);
    final strikerB = makeOutfield('strikerB', Position.st, penalties: 1);
    final allPlayers = [gk, ...defs, ...mids, strikerA, strikerB];
    final team = Team(
        id: 'setpiece',
        name: 'Set Piece FC',
        players: allPlayers,
        formation: Formation.f442);
    team.startingXI = allPlayers.map((p) => p.id).toList();
    team.penaltyTakerId = strikerA.id;

    final away = PlayerGenerator.generateSquad(
        id: 'weak', name: 'Weak FC', strengthTier: 10);
    LineupUtils.autoFill(away);

    var strikerAGoals = 0;
    var strikerBGoals = 0;
    for (int i = 0; i < 300; i++) {
      final result = MatchEngine.simulateMinutes(
          home: team, away: away, startMinute: 1, endMinute: 90);
      for (final e in result.events) {
        if (e.type != MatchEventType.goal) continue;
        if (e.scorerId == strikerA.id) strikerAGoals++;
        if (e.scorerId == strikerB.id) strikerBGoals++;
      }
    }

    expect(strikerAGoals, greaterThan(strikerBGoals));
  });

  test(
      'RotationEngine.suggest recommends swapping in a fresher bench player '
      'of the same position', () {
    final team = PlayerGenerator.generateSquad(
        id: 'rot', name: 'Rotation FC', strengthTier: 60);
    LineupUtils.autoFill(team);
    final tired =
        team.players.firstWhere((p) => team.startingXI.contains(p.id));
    tired.fatigue = 90;
    for (final p
        in team.players.where((p) => !team.startingXI.contains(p.id))) {
      p.fatigue = 80;
    }
    final fresh = team.players.firstWhere(
        (p) => !team.startingXI.contains(p.id) && p.canPlay(tired.position));
    fresh.fatigue = 10;

    final suggestions = RotationEngine.suggest(team);
    final match = suggestions.where((s) => s.tiredPlayerId == tired.id);

    expect(match, isNotEmpty);
    expect(match.first.replacementId, fresh.id);
  });

  test('RotationEngine.suggest ignores starters below the fatigue threshold',
      () {
    final team = PlayerGenerator.generateSquad(
        id: 'rot2', name: 'Rested FC', strengthTier: 60);
    LineupUtils.autoFill(team);
    for (final p in team.players) {
      p.fatigue = 10;
    }

    final suggestions = RotationEngine.suggest(team);

    expect(suggestions, isEmpty);
  });

  test(
      'GameState.buyPlayerOnInstallments splits the remaining cost into weekly payments',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final target = gameState.transferMarket.first;
    gameState.save!.budget = target.marketValue; // 頭金分は十分ある

    final ok = await gameState.buyPlayerOnInstallments(target.id);

    expect(ok, isTrue);
    expect(gameState.save!.pendingInstallments.length, 1);
    expect(gameState.userTeam.players.any((p) => p.id == target.id), isTrue);
  });

  test(
      'ContractEngine.advanceWeek removes a loan player once loanWeeksRemaining reaches 0',
      () {
    final team = PlayerGenerator.generateSquad(
        id: 'lteam', name: 'Loan FC', strengthTier: 60);
    final loanPlayer = team.players.first;
    loanPlayer.isLoan = true;
    loanPlayer.loanWeeksRemaining = 1;

    final expired = ContractEngine.advanceWeek(team);

    expect(expired.any((p) => p.id == loanPlayer.id), isTrue);
    expect(team.players.any((p) => p.id == loanPlayer.id), isFalse);
  });

  test(
      'NamePool.themedClubNames generates enough unique names for a full league',
      () {
    for (final theme in LeagueTheme.values) {
      final names = NamePool.themedClubNames(theme, teamsPerLeague - 1);
      expect(names.toSet().length, teamsPerLeague - 1);
    }
  });

  test(
      'CupEngine.createKnockout never leaves a bye-vs-bye match unresolved for a non-power-of-two field',
      () {
    // 20チーム(2の累乗ではない)は32枠に切り上げられ、12個のBYEが生じる。
    final teamIds = List.generate(teamsPerLeague, (i) => 't$i');
    final teams = teamIds
        .map((id) =>
            PlayerGenerator.generateSquad(id: id, name: id, strengthTier: 60))
        .toList();
    for (final t in teams) {
      LineupUtils.autoFill(t);
    }
    final cup = CupEngine.createKnockout(
        type: CupType.domestic, name: '国内カップ', teamIds: teamIds);

    // 全てのBYEを含む試合が単独で解決済み(勝者が決まっている)ことを確認する。
    for (final m in cup.rounds.first) {
      if (m.isBye) {
        expect(m.winnerId, isNotNull);
      }
    }

    // 決勝まで全試合を消化できる(BYE同士の対戦で永久に止まらない)ことを確認する。
    var guard = 0;
    while (cup.nextUnplayedMatch != null && guard < 100) {
      CupEngine.playNextMatch(cup, teams);
      guard++;
    }
    expect(cup.isComplete, isTrue);
    expect(cup.championId, isNotNull);
  });

  test(
      'GameState.startNewGame creates a full-size league with the selected theme name',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC', theme: LeagueTheme.spain);

    expect(gameState.save!.league.teams.length, teamsPerLeague);
    expect(gameState.save!.leagueName, LeagueTheme.spain.label);
  });

  test(
      'MatchEngine.simulateMinutes only generates events within the requested minute range',
      () {
    final home = PlayerGenerator.generateSquad(
        id: 'h', name: 'Home FC', strengthTier: 60);
    final away = PlayerGenerator.generateSquad(
        id: 'a', name: 'Away FC', strengthTier: 60);
    LineupUtils.autoFill(home);
    LineupUtils.autoFill(away);

    final half = MatchEngine.simulateMinutes(
        home: home, away: away, startMinute: 46, endMinute: 90);

    expect(half.events.every((e) => e.minute >= 46 && e.minute <= 90), isTrue);
  });

  test(
      'GameState.playNextMatchday stops at half-time for the user fixture; playSecondHalf finalizes it',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');

    final firstHalf = await gameState.playNextMatchday();

    expect(firstHalf, isNotNull);
    expect(gameState.isHalfTime, isTrue);
    expect(firstHalf!.events.every((e) => e.minute <= 45), isTrue);

    final merged = await gameState.playSecondHalf();

    expect(merged, isNotNull);
    expect(gameState.isHalfTime, isFalse);
    final fixture = gameState.save!.league
        .fixturesForMatchday(merged!.matchday)
        .firstWhere((f) =>
            f.homeTeamId == merged.homeTeamId &&
            f.awayTeamId == merged.awayTeamId);
    expect(fixture.result, isNotNull);
  });

  test(
      'GameState.makeHalfTimeSubstitution swaps players and enforces the substitution limit',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    await gameState.playNextMatchday();
    expect(gameState.isHalfTime, isTrue);

    final team = gameState.userTeam;
    final outId = team.startingXI.first;
    final inId = team.players
        .firstWhere((p) => !team.startingXI.contains(p.id) && !p.isInjured)
        .id;

    final ok = gameState.makeHalfTimeSubstitution(
        outPlayerId: outId, inPlayerId: inId);

    expect(ok, isTrue);
    expect(team.startingXI.contains(inId), isTrue);
    expect(team.startingXI.contains(outId), isFalse);
    expect(gameState.substitutionsUsed, 1);
  });

  test(
      'GameState.playFriendly resolves a friendly without affecting league standings',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    expect(gameState.save!.friendlies, isNotEmpty);

    final result = await gameState.playFriendly(0);

    expect(result, isNotNull);
    expect(gameState.save!.friendlies[0].result, isNotNull);
    expect(
        gameState.save!.league.fixtures.every((f) => f.result == null), isTrue);
  });

  test(
      'GameState.acceptIncomingOffer sells the player and adds the offered amount to budget',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final target = gameState.userTeam.players.first;
    gameState.save!.budget = 0;
    gameState.save!.incomingOffers.add(IncomingOffer(
      id: 'o1',
      playerId: target.id,
      playerName: target.name,
      buyerClubName: 'よそのクラブ',
      amount: 500,
    ));

    final ok = await gameState.acceptIncomingOffer('o1');

    expect(ok, isTrue);
    expect(gameState.save!.budget, 500);
    expect(gameState.userTeam.players.any((p) => p.id == target.id), isFalse);
    expect(gameState.incomingOffers, isEmpty);
  });

  test(
      'GameState.acceptIncomingOffer discards rival competing offers for the same player',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final target = gameState.userTeam.players.first;
    gameState.save!.budget = 0;
    gameState.save!.incomingOffers.addAll([
      IncomingOffer(
        id: 'o1',
        playerId: target.id,
        playerName: target.name,
        buyerClubName: 'クラブA',
        amount: 500,
      ),
      IncomingOffer(
        id: 'o2',
        playerId: target.id,
        playerName: target.name,
        buyerClubName: 'クラブB',
        amount: 650,
      ),
    ]);

    final ok = await gameState.acceptIncomingOffer('o2');

    expect(ok, isTrue);
    expect(gameState.save!.budget, 650);
    expect(gameState.incomingOffers, isEmpty);
  });

  test(
      'GameState.playNextMatchday never lets more than 2 clubs compete for the same player',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    for (final p in gameState.userTeam.players) {
      p.contractWeeksRemaining = 999;
    }

    for (int i = 0; i < 20; i++) {
      await gameState.playNextMatchday();
      if (gameState.isHalfTime) {
        await gameState.playSecondHalf();
      }
      if (gameState.save!.league.isSeasonComplete) break;
      final counts = <String, int>{};
      for (final o in gameState.incomingOffers) {
        counts[o.playerId] = (counts[o.playerId] ?? 0) + 1;
      }
      expect(counts.values.every((c) => c <= 2), isTrue);
    }
  });

  test(
      'GameState.acceptIncomingOffer backfills the starting XI when a starter is sold',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final team = gameState.userTeam;
    final target =
        team.players.firstWhere((p) => team.startingXI.contains(p.id));
    gameState.save!.incomingOffers.add(IncomingOffer(
      id: 'starter-offer',
      playerId: target.id,
      playerName: target.name,
      buyerClubName: 'よそのクラブ',
      amount: 500,
    ));

    final ok = await gameState.acceptIncomingOffer('starter-offer');

    expect(ok, isTrue);
    expect(team.startingXI.contains(target.id), isFalse);
    expect(team.startingXI.length, 11);
  });

  test(
      'GameState.acceptIncomingOffer discards a stale offer without crediting budget '
      'when the player already left the team', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final target = gameState.userTeam.players.first;
    gameState.save!.budget = 1000;
    gameState.save!.incomingOffers.add(IncomingOffer(
      id: 'stale-offer',
      playerId: target.id,
      playerName: target.name,
      buyerClubName: 'よそのクラブ',
      amount: 500,
    ));
    gameState.userTeam.players.removeWhere((p) => p.id == target.id);

    final ok = await gameState.acceptIncomingOffer('stale-offer');

    expect(ok, isFalse);
    expect(gameState.save!.budget, 1000);
    expect(gameState.incomingOffers, isEmpty);
  });

  test(
      'GameState.acceptIncomingOffer keeps the offer pending when the squad-size guard blocks the sale',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final team = gameState.userTeam;
    while (team.players.length > minSquadSize) {
      final removable =
          team.players.firstWhere((p) => !team.startingXI.contains(p.id));
      team.players.remove(removable);
    }
    final target = team.players.first;
    gameState.save!.budget = 1000;
    gameState.save!.incomingOffers.add(IncomingOffer(
      id: 'guarded-offer',
      playerId: target.id,
      playerName: target.name,
      buyerClubName: 'よそのクラブ',
      amount: 500,
    ));

    final ok = await gameState.acceptIncomingOffer('guarded-offer');

    expect(ok, isFalse);
    expect(gameState.save!.budget, 1000);
    expect(
        gameState.incomingOffers.any((o) => o.id == 'guarded-offer'), isTrue);
  });

  test('GameState.playFriendly does not accumulate fatigue or cause injuries',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final lineup = MatchEngine.lineupOf(gameState.userTeam);
    final fatigueBefore = {for (final p in lineup) p.id: p.fatigue};
    final injuredBefore =
        lineup.where((p) => p.isInjured).map((p) => p.id).toSet();

    final result = await gameState.playFriendly(0);

    expect(result, isNotNull);
    for (final p in lineup) {
      expect(p.fatigue, fatigueBefore[p.id]);
    }
    final injuredAfter =
        lineup.where((p) => p.isInjured).map((p) => p.id).toSet();
    expect(injuredAfter, injuredBefore);
  });

  test(
      'GameState.declineIncomingOffer removes the offer without affecting budget',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final target = gameState.userTeam.players.first;
    gameState.save!.budget = 1000;
    gameState.save!.incomingOffers.add(IncomingOffer(
      id: 'o2',
      playerId: target.id,
      playerName: target.name,
      buyerClubName: 'よそのクラブ',
      amount: 500,
    ));

    await gameState.declineIncomingOffer('o2');

    expect(gameState.save!.budget, 1000);
    expect(gameState.userTeam.players.any((p) => p.id == target.id), isTrue);
    expect(gameState.incomingOffers, isEmpty);
  });

  test('GameState.setReleaseClause sets and clears the release clause',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final target = gameState.userTeam.players.first;

    await gameState.setReleaseClause(target.id, 1234);
    expect(target.releaseClause, 1234);

    await gameState.setReleaseClause(target.id, null);
    expect(target.releaseClause, isNull);
  });

  test(
      'GameState.acceptJobOffer switches clubs and resets confidence/board target',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final newTeamId =
        gameState.save!.league.teams.firstWhere((t) => t.id != 'user').id;
    gameState.save!.pendingJobOfferTeamId = newTeamId;
    gameState.save!.confidence = 10;

    final ok = await gameState.acceptJobOffer();

    expect(ok, isTrue);
    expect(gameState.save!.userTeamId, newTeamId);
    expect(gameState.save!.pendingJobOfferTeamId, isNull);
    expect(gameState.save!.confidence, 60);
  });

  test(
      'GameState.declineJobOffer clears the pending offer without switching clubs',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    gameState.save!.pendingJobOfferTeamId = 'cpu0';

    await gameState.declineJobOffer();

    expect(gameState.save!.pendingJobOfferTeamId, isNull);
    expect(gameState.save!.userTeamId, 'user');
  });

  test(
      'GameState.startNextSeason generates a batch of youth intake candidates within bounds',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');

    await gameState.startNextSeason();

    expect(gameState.pendingYouthIntake.length, inInclusiveRange(3, 5));
    expect(gameState.managerReputation, inInclusiveRange(0, 100));
  });

  test('GameState.keepYouthIntakePlayer moves a candidate into youth prospects',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    await gameState.startNextSeason();
    final candidate = gameState.pendingYouthIntake.first;

    final ok = await gameState.keepYouthIntakePlayer(candidate.id);

    expect(ok, isTrue);
    expect(gameState.save!.youthProspects.any((p) => p.id == candidate.id),
        isTrue);
    expect(
        gameState.pendingYouthIntake.any((p) => p.id == candidate.id), isFalse);
  });

  test(
      'LoanEngine.weeklyRepaymentFor charges more in total for the longer, higher-interest term',
      () {
    const principal = 1000;
    final shortTerm = LoanEngine.terms.firstWhere((t) => t.weeks == 12);
    final longTerm = LoanEngine.terms.firstWhere((t) => t.weeks == 26);

    final shortTotal = LoanEngine.totalRepaymentFor(principal, shortTerm);
    final longTotal = LoanEngine.totalRepaymentFor(principal, longTerm);

    expect(shortTotal, greaterThan(principal));
    expect(longTotal, greaterThan(shortTotal));
    expect(
      LoanEngine.weeklyRepaymentFor(principal, longTerm),
      lessThan(LoanEngine.weeklyRepaymentFor(principal, shortTerm)),
    );
  });

  test(
      'GameState.takeLoan adds funds to the budget and refuses amounts above the borrowing limit',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    gameState.save!.budget = 0;
    final term = LoanEngine.terms.first;
    final maxAmount = gameState.maxLoanAmount;

    final tooMuch = await gameState.takeLoan(maxAmount + 1000, term);
    expect(tooMuch, isFalse);
    expect(gameState.bankLoans, isEmpty);

    final ok = await gameState.takeLoan(maxAmount, term);

    expect(ok, isTrue);
    expect(gameState.save!.budget, maxAmount);
    expect(gameState.bankLoans.length, 1);
    expect(gameState.bankLoans.first.weeksRemaining, term.weeks);
  });

  test(
      'GameState.maxLoanAmount shrinks by the outstanding debt of existing loans',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final term = LoanEngine.terms.first;
    final beforeMax = gameState.maxLoanAmount;

    await gameState.takeLoan((beforeMax * 0.5).round(), term);

    expect(gameState.maxLoanAmount, lessThan(beforeMax));
  });

  test(
      'GameState.playNextMatchday counts down the loan and clears it once the term ends',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final term = LoanEngine.terms.firstWhere((t) => t.weeks == 12);
    await gameState.takeLoan(500, term);

    await gameState.playNextMatchday();
    if (gameState.isHalfTime) {
      await gameState.playSecondHalf();
    }

    expect(gameState.bankLoans.first.weeksRemaining, term.weeks - 1);

    for (int i = 1; i < term.weeks; i++) {
      await gameState.playNextMatchday();
      if (gameState.isHalfTime) {
        await gameState.playSecondHalf();
      }
    }

    expect(gameState.bankLoans, isEmpty);
  });

  test(
      'AwardsEngine.computeAwards picks the top scorer by goal tally and an MVP among starters',
      () {
    final home = PlayerGenerator.generateSquad(
        id: 'h', name: 'Home FC', strengthTier: 60);
    final away = PlayerGenerator.generateSquad(
        id: 'a', name: 'Away FC', strengthTier: 60);
    LineupUtils.autoFill(home);
    LineupUtils.autoFill(away);
    final topScorer = home.players.first;
    final otherScorer = away.players[1];
    final fixture = Fixture(
      matchday: 1,
      homeTeamId: home.id,
      awayTeamId: away.id,
      result: MatchResult(
        matchday: 1,
        homeTeamId: home.id,
        awayTeamId: away.id,
        homeGoals: 2,
        awayGoals: 1,
        events: [
          MatchEvent(
              minute: 10,
              teamId: home.id,
              scorerName: topScorer.name,
              scorerId: topScorer.id),
          MatchEvent(
              minute: 30,
              teamId: home.id,
              scorerName: topScorer.name,
              scorerId: topScorer.id),
          MatchEvent(
              minute: 50,
              teamId: away.id,
              scorerName: otherScorer.name,
              scorerId: otherScorer.id),
        ],
      ),
    );
    final league = League(teams: [home, away], fixtures: [fixture], season: 1);

    final award = AwardsEngine.computeAwards(league, 1);

    expect(award.season, 1);
    expect(award.topScorerName, topScorer.name);
    expect(award.topScorerTeamName, home.name);
    expect(award.topScorerGoals, 2);
    expect(award.mvpName, isNotNull);
  });

  test(
      'AwardsEngine.computeManagerOfPeriod picks the best record within the '
      'matchday range and ignores fixtures outside it', () {
    final home = PlayerGenerator.generateSquad(
        id: 'h2', name: 'Home FC', strengthTier: 60);
    final away = PlayerGenerator.generateSquad(
        id: 'a2', name: 'Away FC', strengthTier: 60);
    final fixtures = [
      Fixture(
        matchday: 1,
        homeTeamId: home.id,
        awayTeamId: away.id,
        result: MatchResult(
            matchday: 1,
            homeTeamId: home.id,
            awayTeamId: away.id,
            homeGoals: 3,
            awayGoals: 0,
            events: []),
      ),
      Fixture(
        matchday: 2,
        homeTeamId: away.id,
        awayTeamId: home.id,
        result: MatchResult(
            matchday: 2,
            homeTeamId: away.id,
            awayTeamId: home.id,
            homeGoals: 0,
            awayGoals: 0,
            events: []),
      ),
      // このシーズン後半の結果は範囲外なので無視されるべき。
      Fixture(
        matchday: 10,
        homeTeamId: away.id,
        awayTeamId: home.id,
        result: MatchResult(
            matchday: 10,
            homeTeamId: away.id,
            awayTeamId: home.id,
            homeGoals: 5,
            awayGoals: 0,
            events: []),
      ),
    ];
    final league = League(teams: [home, away], fixtures: fixtures, season: 1);

    final winner = AwardsEngine.computeManagerOfPeriod(league,
        fromMatchday: 1, toMatchday: 4);

    expect(winner, home.name);
  });

  test(
      'AwardsEngine.computeManagerOfSeason rewards the club that most '
      'overachieved its expected rank', () {
    final strong = PlayerGenerator.generateSquad(
        id: 'strong', name: 'Strong FC', strengthTier: 90);
    final weak = PlayerGenerator.generateSquad(
        id: 'weak2', name: 'Weak FC', strengthTier: 20);
    // 総合力ではstrongが優位だが、最終順位はweakが上(=weakの大健闘)。
    final league = League(
      teams: [strong, weak],
      fixtures: [
        Fixture(
          matchday: 1,
          homeTeamId: weak.id,
          awayTeamId: strong.id,
          result: MatchResult(
              matchday: 1,
              homeTeamId: weak.id,
              awayTeamId: strong.id,
              homeGoals: 2,
              awayGoals: 0,
              events: []),
        ),
      ],
      season: 1,
    );

    final winner = AwardsEngine.computeManagerOfSeason(league);

    expect(winner, weak.name);
  });

  test('GameState.startNextSeason records a season award once the season ends',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    while (!gameState.save!.league.isSeasonComplete) {
      await gameState.playNextMatchday();
      if (gameState.isHalfTime) {
        await gameState.playSecondHalf();
      }
    }

    await gameState.startNextSeason();

    expect(gameState.seasonAwards, isNotEmpty);
    expect(gameState.seasonAwards.first.season, 1);
  });

  test('LineupUtils.autoFill excludes players on international duty', () {
    final team = PlayerGenerator.generateSquad(
        id: 't6', name: 'Test FC', strengthTier: 60);
    for (final p in team.players.where((p) => p.position == Position.st)) {
      p.internationalDutyWeeksRemaining = 2;
    }
    LineupUtils.autoFill(team);
    final byId = {for (final p in team.players) p.id: p};
    final lineup = team.startingXI.map((id) => byId[id]!).toList();
    expect(lineup.every((p) => !p.isOnInternationalDuty), isTrue);
  });

  test(
      'GameState.playNextMatchday counts down a user player\'s international duty',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final player = gameState.userTeam.players.first;
    player.internationalDutyWeeksRemaining = 2;

    await gameState.playNextMatchday();

    expect(player.internationalDutyWeeksRemaining, 1);
  });

  test(
      'GameState.playSecondHalf generates a press conference question that can be answered',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    await gameState.playNextMatchday();
    expect(gameState.isHalfTime, isTrue);

    await gameState.playSecondHalf();

    expect(gameState.pendingPressConference, isNotNull);
    final confidenceBefore = gameState.save!.confidence;
    final option = gameState.pendingPressConference!.options.first;

    await gameState.answerPressConference(0);

    expect(gameState.pendingPressConference, isNull);
    expect(gameState.save!.confidence,
        (confidenceBefore + option.confidenceDelta).clamp(0, 100));
  });

  test(
      'GameState.isRivalFixture matches the user-vs-rival fixture regardless of home/away order',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final userId = gameState.userTeam.id;
    final rivalId = gameState.save!.rivalTeamId!;
    final otherId = gameState.save!.league.teams
        .firstWhere((t) => t.id != userId && t.id != rivalId)
        .id;

    expect(
        gameState.isRivalFixture(
            Fixture(matchday: 1, homeTeamId: userId, awayTeamId: rivalId)),
        isTrue);
    expect(
        gameState.isRivalFixture(
            Fixture(matchday: 1, homeTeamId: rivalId, awayTeamId: userId)),
        isTrue);
    expect(
        gameState.isRivalFixture(
            Fixture(matchday: 1, homeTeamId: userId, awayTeamId: otherId)),
        isFalse);
    expect(
        gameState.isRivalFixture(
            Fixture(matchday: 1, homeTeamId: otherId, awayTeamId: rivalId)),
        isFalse);
  });

  test(
      'PromotionEngine.resolve swaps the bottom of tier1 with the top of tier2',
      () {
    List<Team> makeTeams(String prefix, int count) => List.generate(
          count,
          (i) => PlayerGenerator.generateSquad(
              id: '$prefix$i', name: '$prefix Team $i', strengthTier: 60),
        );

    final tier1Teams = makeTeams('t1', 8);
    final tier2Teams = makeTeams('t2', 8);
    for (final t in [...tier1Teams, ...tier2Teams]) {
      LineupUtils.autoFill(t);
    }
    // tier1PlayedOrderは実際の最終順位(良い順)を模した並び。
    final tier1PlayedOrder = List<Team>.from(tier1Teams);

    final result = PromotionEngine.resolve(
      tier1Teams: tier1Teams,
      tier2Teams: tier2Teams,
      tier1PlayedOrder: tier1PlayedOrder,
    );

    expect(result.tier1.length, 8);
    expect(result.tier2.length, 8);

    final survivorsTop = tier1PlayedOrder.take(5).map((t) => t.id).toSet();
    final relegatedIds = tier1PlayedOrder.skip(5).map((t) => t.id).toSet();
    final newTier1Ids = result.tier1.map((t) => t.id).toSet();
    final newTier2Ids = result.tier2.map((t) => t.id).toSet();

    // 上位5チームは残留し、下位3チームは降格する。
    expect(newTier1Ids.containsAll(survivorsTop), isTrue);
    expect(newTier2Ids.containsAll(relegatedIds), isTrue);
    // 昇格した3チームはすべてtier2の元メンバーから来ている。
    expect(
        newTier1Ids
            .difference(survivorsTop)
            .every((id) => tier2Teams.any((t) => t.id == id)),
        isTrue);
    // チームが増減せず、全チームがどちらかのディビジョンに存在する。
    final allOriginalIds = {
      ...tier1Teams.map((t) => t.id),
      ...tier2Teams.map((t) => t.id)
    };
    expect(newTier1Ids.union(newTier2Ids), allOriginalIds);
    expect(result.relegatedTeamNames.length, 3);
    expect(result.promotedTeamNames.length, 3);
  });

  test(
      'PromotionEngine.resolve runs a promotion playoff among 3rd-6th place '
      'for the final promotion spot', () {
    List<Team> makeTeams(String prefix, int count) => List.generate(
          count,
          (i) => PlayerGenerator.generateSquad(
              id: '$prefix$i', name: '$prefix Team $i', strengthTier: 60),
        );

    final tier1Teams = makeTeams('q1', 8);
    final tier2Teams = makeTeams('q2', 8);
    for (final t in [...tier1Teams, ...tier2Teams]) {
      LineupUtils.autoFill(t);
    }
    final tier1PlayedOrder = List<Team>.from(tier1Teams);
    final tier2PlayedOrder = List<Team>.from(tier2Teams);

    final result = PromotionEngine.resolve(
      tier1Teams: tier1Teams,
      tier2Teams: tier2Teams,
      tier1PlayedOrder: tier1PlayedOrder,
      tier2PlayedOrder: tier2PlayedOrder,
    );

    expect(result.promotionPlayoff.length, 3);
    final semiA = result.promotionPlayoff[0];
    final semiB = result.promotionPlayoff[1];
    final finalMatch = result.promotionPlayoff[2];

    // 準決勝は3位対6位、4位対5位の組み合わせで行われる。
    expect({semiA.homeId, semiA.awayId},
        {tier2PlayedOrder[2].id, tier2PlayedOrder[5].id});
    expect({semiB.homeId, semiB.awayId},
        {tier2PlayedOrder[3].id, tier2PlayedOrder[4].id});
    expect({finalMatch.homeId, finalMatch.awayId},
        {semiA.winnerId, semiB.winnerId});

    final newTier1Ids = result.tier1.map((t) => t.id).toSet();
    final newTier2Ids = result.tier2.map((t) => t.id).toSet();

    // 自動昇格の上位2チームは必ず昇格する。
    expect(newTier1Ids, contains(tier2PlayedOrder[0].id));
    expect(newTier1Ids, contains(tier2PlayedOrder[1].id));
    // プレーオフ決勝の勝者も昇格する。
    expect(newTier1Ids, contains(finalMatch.winnerId));

    // プレーオフで敗れた3チーム(両準決勝の敗者+決勝の敗者)は昇格しない。
    final playoffLosers = {
      semiA.homeId == semiA.winnerId ? semiA.awayId : semiA.homeId,
      semiB.homeId == semiB.winnerId ? semiB.awayId : semiB.homeId,
      finalMatch.homeId == finalMatch.winnerId
          ? finalMatch.awayId
          : finalMatch.homeId,
    };
    expect(playoffLosers.length, 3);
    for (final loserId in playoffLosers) {
      expect(newTier2Ids, contains(loserId));
    }

    // 昇格したのはちょうど3チーム(自動2+プレーオフ勝者1)。
    final survivingTier1Ids = tier1PlayedOrder.take(5).map((t) => t.id).toSet();
    expect(newTier1Ids.difference(survivingTier1Ids).length, 3);
  });

  test(
      'GameState.startNextSeason relegates the user to the second division when they finish last',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final userId = gameState.userTeam.id;
    for (final f in gameState.save!.league.fixtures) {
      final userIsHome = f.homeTeamId == userId;
      final userIsAway = f.awayTeamId == userId;
      if (userIsHome || userIsAway) {
        f.result = MatchResult(
          matchday: f.matchday,
          homeTeamId: f.homeTeamId,
          awayTeamId: f.awayTeamId,
          homeGoals: userIsHome ? 0 : 3,
          awayGoals: userIsHome ? 3 : 0,
          events: [],
        );
      } else {
        f.result = MatchResult(
          matchday: f.matchday,
          homeTeamId: f.homeTeamId,
          awayTeamId: f.awayTeamId,
          homeGoals: 1,
          awayGoals: 1,
          events: [],
        );
      }
    }

    await gameState.startNextSeason();

    expect(gameState.currentDivisionTier, 2);
    expect(gameState.lastDivisionChangeMessage, contains('降格'));
    expect(() => gameState.userTeam, returnsNormally);
    expect(gameState.save!.league.teams.length, teamsPerLeague);
    expect(gameState.save!.secondDivisionTeams.length, teamsPerLeague);
  });

  test(
      'ScoutReportEngine.generateFor produces a report with a key player and recommendation',
      () {
    final opponent = PlayerGenerator.generateSquad(
        id: 'opp', name: '対戦相手FC', strengthTier: 70);
    final userTeam = PlayerGenerator.generateSquad(
        id: 'user', name: 'テストFC', strengthTier: 60);
    LineupUtils.autoFill(opponent);
    LineupUtils.autoFill(userTeam);

    final report =
        ScoutReportEngine.generateFor(opponent: opponent, userTeam: userTeam);

    expect(report.opponentName, '対戦相手FC');
    expect(report.keyPlayerName, isNotNull);
    expect(report.recommendation, isNotEmpty);
  });

  test(
      'GameState.loanOutPlayer sends a player out on loan, excluding them from the wage bill and lineup',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final team = gameState.userTeam;
    final target =
        team.players.firstWhere((p) => team.startingXI.contains(p.id));
    final wageBefore = ContractEngine.weeklyWageBill(team);

    final ok = await gameState.loanOutPlayer(target.id, 8);

    expect(ok, isTrue);
    expect(target.isLoanedOut, isTrue);
    expect(target.loanedOutWeeksRemaining, 8);
    expect(team.startingXI.contains(target.id), isFalse);
    expect(ContractEngine.weeklyWageBill(team), wageBefore - target.wage);
  });

  test(
      'GameState.playNextMatchday returns a loaned-out player to the squad once the term ends',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final target = gameState.userTeam.players.first;
    await gameState.loanOutPlayer(target.id, GameState.loanOutMinWeeks);

    for (int i = 0; i < GameState.loanOutMinWeeks; i++) {
      await gameState.playNextMatchday();
      if (gameState.isHalfTime) {
        await gameState.playSecondHalf();
      }
    }

    expect(target.isLoanedOut, isFalse);
    expect(gameState.lastLoanReturns, contains(target.name));
  });

  test(
      'GameState.startNewGame seeds a free-agent pool, and signFreeAgent '
      'moves a pooled player into the squad without charging a transfer fee',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    expect(gameState.freeAgents, isNotEmpty);

    final target = gameState.freeAgents.first;
    final budgetBefore = gameState.save!.budget;
    final squadSizeBefore = gameState.userTeam.players.length;

    final ok = await gameState.signFreeAgent(target.id);

    expect(ok, isTrue);
    expect(gameState.save!.budget, budgetBefore);
    expect(gameState.userTeam.players.length, squadSizeBefore + 1);
    expect(gameState.userTeam.players.any((p) => p.id == target.id), isTrue);
    expect(gameState.freeAgents.any((p) => p.id == target.id), isFalse);
  });

  test(
      'GameState.setCaptain/setViceCaptain keep the two roles mutually '
      'exclusive', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final a = gameState.userTeam.players[0].id;
    final b = gameState.userTeam.players[1].id;

    await gameState.setCaptain(a);
    expect(gameState.userTeam.captainId, a);

    // 同じ選手を副キャプテンにも指名すると、キャプテンの指名は解除される。
    await gameState.setViceCaptain(a);
    expect(gameState.userTeam.viceCaptainId, a);
    expect(gameState.userTeam.captainId, isNull);

    // 別の選手をキャプテンにしても、副キャプテンの指名はそのまま残る。
    await gameState.setCaptain(b);
    expect(gameState.userTeam.captainId, b);
    expect(gameState.userTeam.viceCaptainId, a);
  });

  test('GameState.isTransferWindowOpen closes mid-season and blocks buyPlayer',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    expect(gameState.isTransferWindowOpen, isTrue);

    for (int i = 0; i < 5; i++) {
      await gameState.playNextMatchday();
      if (gameState.isHalfTime) {
        await gameState.playSecondHalf();
      }
    }
    expect(gameState.isTransferWindowOpen, isFalse);

    gameState.save!.budget = 999999;
    final target = gameState.transferMarket.first;
    final ok = await gameState.buyPlayer(target.id);
    expect(ok, isFalse);
  });

  test('GameState.isTransferWindowOpen reopens for the mid-season window',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final league = gameState.save!.league;
    for (final f in league.fixtures) {
      if (f.matchday < 19) {
        f.result ??= MatchResult(
          matchday: f.matchday,
          homeTeamId: f.homeTeamId,
          awayTeamId: f.awayTeamId,
          homeGoals: 0,
          awayGoals: 0,
          events: [],
        );
      }
    }

    expect(gameState.isTransferWindowOpen, isTrue);
  });

  test('GameState.setTransferListed toggles the listed flag', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final target = gameState.userTeam.players.first;

    await gameState.setTransferListed(target.id, true);
    expect(target.isTransferListed, isTrue);

    await gameState.setTransferListed(target.id, false);
    expect(target.isTransferListed, isFalse);
  });

  test(
      'GameState.setPlayerDuty updates the duty and MatchEngine.simulate still runs under extreme tactics',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final team = gameState.userTeam;
    for (final id in team.startingXI) {
      gameState.setPlayerDuty(id, PlayerDuty.attack);
    }
    team.width = 100;
    team.tempo = 100;
    expect(team.players.firstWhere((p) => p.id == team.startingXI.first).duty,
        PlayerDuty.attack);

    final away = PlayerGenerator.generateSquad(
        id: 'awayX', name: 'Away FC', strengthTier: 60);
    LineupUtils.autoFill(away);
    final result = MatchEngine.simulate(home: team, away: away, matchday: 1);

    expect(result.homeGoals, greaterThanOrEqualTo(0));
    expect(result.awayGoals, greaterThanOrEqualTo(0));
  });

  test('ClubInfrastructure.stadiumCapacity increases with facility level', () {
    final level1 = ClubInfrastructure.stadiumCapacity(1);
    final level5 = ClubInfrastructure.stadiumCapacity(5);
    expect(level5, greaterThan(level1));
  });

  test('GameState.expectedAttendance stays within the stadium capacity',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');

    expect(gameState.expectedAttendance, greaterThan(0));
    expect(gameState.expectedAttendance,
        lessThanOrEqualTo(gameState.stadiumCapacity));
  });

  test(
      'GameState.playNextMatchday records last match attendance within capacity',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');

    await gameState.playNextMatchday();

    expect(gameState.lastMatchAttendance, isNotNull);
    expect(gameState.lastMatchAttendance, greaterThan(0));
    expect(gameState.lastMatchAttendance,
        lessThanOrEqualTo(gameState.stadiumCapacity));
  });

  test(
      'AiTransferEngine.maybeGenerate never touches the user team and preserves total player count',
      () {
    final rng = Random(7);
    final user = PlayerGenerator.generateSquad(
        id: 'user', name: 'ユーザーFC', strengthTier: 60);
    final cpu1 = PlayerGenerator.generateSquad(
        id: 'cpu1', name: 'CPU1', strengthTier: 60);
    final cpu2 = PlayerGenerator.generateSquad(
        id: 'cpu2', name: 'CPU2', strengthTier: 60);
    final teams = [user, cpu1, cpu2];
    final totalBefore = teams.fold<int>(0, (s, t) => s + t.players.length);
    final userCountBefore = user.players.length;

    for (int i = 0; i < 30; i++) {
      AiTransferEngine.maybeGenerate(teams, 'user', rng);
    }

    final totalAfter = teams.fold<int>(0, (s, t) => s + t.players.length);
    expect(totalAfter, totalBefore);
    expect(user.players.length, userCountBefore);
  });

  test(
      'GameState.playNextMatchday generates CPU-to-CPU transfer news without touching the user squad',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    // 契約切れによる離脱と混同しないよう、ユーザークラブの契約を十分延長しておく。
    for (final p in gameState.userTeam.players) {
      p.contractWeeksRemaining = 999;
    }
    final userCountBefore = gameState.userTeam.players.length;

    for (int i = 0; i < 20; i++) {
      await gameState.playNextMatchday();
      if (gameState.isHalfTime) await gameState.playSecondHalf();
      if (gameState.save!.league.isSeasonComplete) break;
    }

    expect(gameState.userTeam.players.length, userCountBefore);
  });

  test(
      'ContractEngine.signingBonusFor and appearanceFeeFor scale with personality wage sensitivity',
      () {
    final player = PlayerGenerator.generateSquad(
            id: 't', name: 'Test FC', strengthTier: 70)
        .players
        .first;
    player.personality = PlayerPersonality.ambitious;
    final ambitiousBonus = ContractEngine.signingBonusFor(player);
    final ambitiousFee = ContractEngine.appearanceFeeFor(player);

    player.personality = PlayerPersonality.loyal;
    final loyalBonus = ContractEngine.signingBonusFor(player);
    final loyalFee = ContractEngine.appearanceFeeFor(player);

    expect(ambitiousBonus, greaterThan(loyalBonus));
    expect(ambitiousFee, greaterThan(loyalFee));
  });

  test(
      'GameState.renewContract charges a signing bonus and sets a new appearance fee',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final player = gameState.userTeam.players.first;
    player.contractWeeksRemaining = 2;
    final baseCost = gameState.renewalCostFor(player.id);
    final bonus = gameState.signingBonusFor(player.id);
    expect(bonus, greaterThan(0));
    gameState.save!.budget = baseCost + bonus;

    final ok = await gameState.renewContract(player.id);

    expect(ok, isTrue);
    expect(gameState.save!.budget, 0);
    expect(player.appearanceFee, greaterThan(0));
  });

  test(
      'GameState.playNextMatchday pays appearance fees for the starting lineup',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final team = gameState.userTeam;
    for (final id in team.startingXI) {
      team.players.firstWhere((p) => p.id == id).appearanceFee = 10;
    }
    final expectedFee = team.startingXI.length * 10;

    await gameState.playNextMatchday();

    expect(gameState.lastAppearanceFeesPaid, expectedFee);
  });

  test(
      'GameState.startNextSeason records career stats and a league trophy when the user finishes first',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final userId = gameState.userTeam.id;
    for (final f in gameState.save!.league.fixtures) {
      final userIsHome = f.homeTeamId == userId;
      final userIsAway = f.awayTeamId == userId;
      if (userIsHome || userIsAway) {
        f.result = MatchResult(
          matchday: f.matchday,
          homeTeamId: f.homeTeamId,
          awayTeamId: f.awayTeamId,
          homeGoals: userIsHome ? 3 : 0,
          awayGoals: userIsHome ? 0 : 3,
          events: [],
        );
      } else {
        f.result = MatchResult(
          matchday: f.matchday,
          homeTeamId: f.homeTeamId,
          awayTeamId: f.awayTeamId,
          homeGoals: 1,
          awayGoals: 1,
          events: [],
        );
      }
    }

    await gameState.startNextSeason();

    expect(gameState.save!.careerSeasons, 1);
    final totalMatches = gameState.save!.careerWins +
        gameState.save!.careerDraws +
        gameState.save!.careerLosses;
    expect(totalMatches, greaterThan(0));
    expect(gameState.save!.careerWins, totalMatches);
    expect(gameState.save!.trophyHistory, isNotEmpty);
    expect(gameState.save!.trophyHistory.last, contains('優勝'));
  });

  test(
      'SuperCupEngine.pairing pits the league champion against the domestic '
      'cup champion', () {
    final cup = Cup(type: CupType.domestic, name: '国内カップ', rounds: [
      [
        CupMatch(
          round: 1,
          homeTeamId: 'cupWinner',
          awayTeamId: 'cupRunnerUp',
          result: MatchResult(
              matchday: 0,
              homeTeamId: 'cupWinner',
              awayTeamId: 'cupRunnerUp',
              homeGoals: 2,
              awayGoals: 1,
              events: []),
        ),
      ],
    ]);

    final pairing = SuperCupEngine.pairing(
        leagueChampionId: 'leagueChamp', domesticCup: cup);

    expect(pairing, ('leagueChamp', 'cupWinner'));
  });

  test(
      'SuperCupEngine.pairing falls back to the cup runner-up when one club '
      'won both titles', () {
    final cup = Cup(type: CupType.domestic, name: '国内カップ', rounds: [
      [
        CupMatch(
          round: 1,
          homeTeamId: 'doubleWinner',
          awayTeamId: 'cupRunnerUp',
          result: MatchResult(
              matchday: 0,
              homeTeamId: 'doubleWinner',
              awayTeamId: 'cupRunnerUp',
              homeGoals: 3,
              awayGoals: 0,
              events: []),
        ),
      ],
    ]);

    final pairing = SuperCupEngine.pairing(
        leagueChampionId: 'doubleWinner', domesticCup: cup);

    expect(pairing, ('doubleWinner', 'cupRunnerUp'));
  });

  test(
      'SuperCupEngine.pairing returns null when the domestic cup has not '
      'finished', () {
    final cup = Cup(type: CupType.domestic, name: '国内カップ', rounds: [
      [CupMatch(round: 1, homeTeamId: 'a', awayTeamId: 'b')],
    ]);

    final pairing = SuperCupEngine.pairing(
        leagueChampionId: 'leagueChamp', domesticCup: cup);

    expect(pairing, isNull);
  });

  test(
      'GameState.startNextSeason schedules a pending Super Cup for the '
      'league champion once the domestic cup has finished', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final userId = gameState.userTeam.id;
    for (final f in gameState.save!.league.fixtures) {
      final userIsHome = f.homeTeamId == userId;
      final userIsAway = f.awayTeamId == userId;
      f.result = MatchResult(
        matchday: f.matchday,
        homeTeamId: f.homeTeamId,
        awayTeamId: f.awayTeamId,
        homeGoals: userIsHome ? 3 : (userIsAway ? 0 : 1),
        awayGoals: userIsHome ? 0 : (userIsAway ? 3 : 1),
        events: [],
      );
    }
    // 国内カップを最後まで消化しておく(誰が優勝してもよい)。
    while (gameState.domesticCup?.nextUnplayedMatch != null) {
      await gameState.playNextCupMatch();
    }

    await gameState.startNextSeason();

    expect(gameState.pendingSuperCup, isNotNull);
    final match = gameState.pendingSuperCup!;
    expect(match.homeTeamId == userId || match.awayTeamId == userId, isTrue);
  });

  test(
      'GameState.startNextSeason archives a SeasonRecord with the final standing',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final userId = gameState.userTeam.id;
    for (final f in gameState.save!.league.fixtures) {
      final userIsHome = f.homeTeamId == userId;
      f.result = MatchResult(
        matchday: f.matchday,
        homeTeamId: f.homeTeamId,
        awayTeamId: f.awayTeamId,
        homeGoals: userIsHome ? 3 : 0,
        awayGoals: userIsHome ? 0 : 3,
        events: [],
      );
    }

    expect(gameState.seasonHistory, isEmpty);
    await gameState.startNextSeason();

    expect(gameState.seasonHistory.length, 1);
    final record = gameState.seasonHistory.first;
    expect(record.season, 1);
    expect(record.finalRank, 1);
    expect(record.wonLeague, isTrue);
    expect(record.won, greaterThan(0));
    expect(record.points, record.won * 3 + record.draw);
  });

  test(
      'BestElevenEngine.compute selects the highest average-rated player per position group',
      () {
    final teamA =
        PlayerGenerator.generateSquad(id: 'a', name: 'AFC', strengthTier: 60);
    final teamB =
        PlayerGenerator.generateSquad(id: 'b', name: 'BFC', strengthTier: 60);
    LineupUtils.autoFill(teamA);
    LineupUtils.autoFill(teamB);

    final gkA = teamA.players.firstWhere((p) => p.position == Position.gk);
    final gkB = teamB.players.firstWhere((p) => p.position == Position.gk);

    final fixtures = <Fixture>[
      for (int md = 1; md <= 3; md++)
        Fixture(
          matchday: md,
          homeTeamId: 'a',
          awayTeamId: 'b',
          result: MatchResult(
            matchday: md,
            homeTeamId: 'a',
            awayTeamId: 'b',
            homeGoals: 1,
            awayGoals: 0,
            events: [],
            playerRatings: {gkA.id: 8.0, gkB.id: 5.0},
          ),
        ),
    ];
    final league = League(teams: [teamA, teamB], fixtures: fixtures, season: 1);

    final best = BestElevenEngine.compute(league, 1);

    final gkEntries =
        best.entries.where((e) => e.group == PositionGroup.gk).toList();
    expect(gkEntries.length, 1);
    expect(gkEntries.first.playerId, gkA.id);
    expect(gkEntries.first.avgRating, 8.0);
  });

  test(
      'BestElevenEngine.compute excludes players below the minimum appearance count',
      () {
    final teamA =
        PlayerGenerator.generateSquad(id: 'a', name: 'AFC', strengthTier: 60);
    LineupUtils.autoFill(teamA);
    final gk = teamA.players.firstWhere((p) => p.position == Position.gk);

    final fixtures = <Fixture>[
      Fixture(
        matchday: 1,
        homeTeamId: 'a',
        awayTeamId: 'a',
        result: MatchResult(
          matchday: 1,
          homeTeamId: 'a',
          awayTeamId: 'a',
          homeGoals: 1,
          awayGoals: 0,
          events: [],
          playerRatings: {gk.id: 9.0},
        ),
      ),
    ];
    final league = League(teams: [teamA], fixtures: fixtures, season: 1);

    final best = BestElevenEngine.compute(league, 1);

    expect(best.entries, isEmpty);
  });

  test(
      'GameState.acceptJobOffer appends the new club to the manager\'s club history',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    gameState.save!.pendingJobOfferTeamId =
        gameState.save!.league.teams.firstWhere((t) => !t.isUserTeam).id;
    final newTeamName = gameState.save!.league.teams
        .firstWhere((t) => t.id == gameState.save!.pendingJobOfferTeamId)
        .name;

    final ok = await gameState.acceptJobOffer();

    expect(ok, isTrue);
    expect(gameState.save!.clubHistory.length, 2);
    expect(gameState.save!.clubHistory.last, newTeamName);
  });

  test('GameState.exportSaveJson/importSaveJson round-trips the save data',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    gameState.save!.budget = 12345;

    final json = gameState.exportSaveJson();
    expect(json, isNotNull);

    final fresh = GameState();
    final ok = await fresh.importSaveJson(json!);

    expect(ok, isTrue);
    expect(fresh.save!.clubName, 'テストFC');
    expect(fresh.save!.budget, 12345);
  });

  test('GameState.importSaveJson rejects malformed JSON without crashing',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');

    final ok = await gameState.importSaveJson('not valid json');

    expect(ok, isFalse);
    expect(gameState.save!.clubName, 'テストFC');
  });

  test('GameState save slots keep independent clubs and support delete',
      () async {
    final gameState = GameState();
    await gameState.init();

    await gameState.loadSlot(0);
    await gameState.startNewGame('スロット0FC');
    await gameState.loadSlot(1);
    await gameState.startNewGame('スロット1FC');

    final slots = await gameState.listSaveSlots();
    expect(slots.length, GameState.maxSaveSlots);
    expect(slots[0].clubName, 'スロット0FC');
    expect(slots[1].clubName, 'スロット1FC');
    expect(slots[2].hasSave, isFalse);

    await gameState.loadSlot(0);
    expect(gameState.save!.clubName, 'スロット0FC');

    await gameState.deleteSlot(1);
    final afterDelete = await gameState.listSaveSlots();
    expect(afterDelete[1].hasSave, isFalse);
    // Deleting a non-current slot must not touch the currently loaded save.
    expect(gameState.save!.clubName, 'スロット0FC');
  });

  test('GameState.init migrates a legacy single-slot save into slot 0',
      () async {
    final legacy = GameState();
    await legacy.startNewGame('レガシーFC');
    final json = legacy.exportSaveJson()!;

    SharedPreferences.setMockInitialValues({'soccer_manager_save_v1': json});
    final migrated = GameState();
    await migrated.init();

    expect(migrated.save!.clubName, 'レガシーFC');
    expect(migrated.currentSlot, 0);
  });

  test(
      'GameState.isBusy toggles off after startNewGame and startNextSeason complete',
      () async {
    final gameState = GameState();
    expect(gameState.isBusy, isFalse);

    await gameState.startNewGame('テストFC');
    expect(gameState.isBusy, isFalse);

    await gameState.startNextSeason();
    expect(gameState.isBusy, isFalse);
  });

  test(
      'YoungTalentScreen.topProspects excludes older players and sorts by potential then overall',
      () {
    Player make(String id, int age, int potential) => Player(
          id: id,
          name: id,
          age: age,
          position: Position.mc,
          potential: potential,
        );

    final young1 = make('y1', 19, 90);
    final young2 = make('y2', 20, 90);
    final young3 = make('y3', 21, 70);
    final old1 = make('o1', 30, 95);

    final teamA = Team(id: 'a', name: 'A', players: [young1, old1]);
    final teamB = Team(id: 'b', name: 'B', players: [young2, young3]);
    final league = League(teams: [teamA], fixtures: [], season: 1);
    final save = SaveGame(
      clubName: 'テストFC',
      userTeamId: 'a',
      league: league,
      secondDivisionTeams: [teamB],
    );

    final top = YoungTalentScreen.topProspects(save, limit: 10);

    expect(top.length, 3);
    expect(top.any((p) => p.player.id == 'o1'), isFalse);
    expect(top.every((p) => p.player.age <= YoungTalentScreen.maxAge), isTrue);
    expect(top.first.player.potential, 90);
    expect(top.last.player.id, 'y3');
  });

  test('YoungTalentScreen.topProspects respects the limit parameter', () {
    Player make(String id, int potential) => Player(
          id: id,
          name: id,
          age: 18,
          position: Position.mc,
          potential: potential,
        );

    final players = List.generate(5, (i) => make('p$i', 60 + i));
    final team = Team(id: 'a', name: 'A', players: players);
    final league = League(teams: [team], fixtures: [], season: 1);
    final save = SaveGame(clubName: 'テストFC', userTeamId: 'a', league: league);

    final top = YoungTalentScreen.topProspects(save, limit: 2);

    expect(top.length, 2);
    expect(top.first.player.id, 'p4');
  });

  test('SquadScreen.filterAndSort filters by position group and search query',
      () {
    Player make(String id, String name, Position pos) => Player(
          id: id,
          name: name,
          age: 20,
          position: pos,
          potential: 70,
        );

    final gk = make('gk', 'GKプレイヤー', Position.gk);
    final df = make('df', 'ディフェンダー', Position.dc);
    final mf = make('mf', 'サントス', Position.mc);
    final all = [gk, df, mf];

    final defOnly = SquadScreen.filterAndSort(all, group: PositionGroup.def);
    expect(defOnly.map((p) => p.id), ['df']);

    final searched = SquadScreen.filterAndSort(all, query: 'サントス');
    expect(searched.map((p) => p.id), ['mf']);

    final none = SquadScreen.filterAndSort(all, query: '存在しない名前');
    expect(none, isEmpty);
  });

  test('SquadScreen.filterAndSort sorts by the requested criterion', () {
    Player make(String id,
        {required int overall,
        required int age,
        required int potential,
        required int wage}) {
      final p = Player(
          id: id,
          name: id,
          age: age,
          position: Position.mc,
          potential: potential,
          wage: wage);
      for (final key in AttributeKeys.all) {
        p.setAttributeValue(key, overall);
      }
      return p;
    }

    final a = make('a', overall: 80, age: 30, potential: 60, wage: 100);
    final b = make('b', overall: 60, age: 20, potential: 90, wage: 200);
    final all = [a, b];

    expect(
        SquadScreen.filterAndSort(all, sort: SquadSortOption.overall).first.id,
        'a');
    expect(SquadScreen.filterAndSort(all, sort: SquadSortOption.age).first.id,
        'b');
    expect(
        SquadScreen.filterAndSort(all, sort: SquadSortOption.potential)
            .first
            .id,
        'b');
    expect(SquadScreen.filterAndSort(all, sort: SquadSortOption.wage).first.id,
        'b');
  });

  test(
      'TransferScreen.filterAndSort filters by position group and search query',
      () {
    Player make(String id, String name, Position pos) => Player(
          id: id,
          name: name,
          age: 20,
          position: pos,
          potential: 70,
        );

    final gk = make('gk', 'GKプレイヤー', Position.gk);
    final st = make('st', 'ストライカー', Position.st);
    final all = [gk, st];

    final attOnly = TransferScreen.filterAndSort(all, group: PositionGroup.att);
    expect(attOnly.map((p) => p.id), ['st']);

    final searched = TransferScreen.filterAndSort(all, query: 'ストライカー');
    expect(searched.map((p) => p.id), ['st']);
  });

  test('TransferScreen.filterAndSort sorts by the requested criterion', () {
    Player make(String id,
        {required int overall, required int potential, required int age}) {
      final p = Player(
          id: id,
          name: id,
          age: age,
          position: Position.mc,
          potential: potential);
      for (final key in AttributeKeys.all) {
        p.setAttributeValue(key, overall);
      }
      return p;
    }

    final expensive = make('expensive', overall: 80, potential: 60, age: 25);
    final cheap = make('cheap', overall: 40, potential: 90, age: 18);
    final all = [expensive, cheap];

    expect(
        TransferScreen.filterAndSort(all, sort: TransferSortOption.overall)
            .first
            .id,
        'expensive');
    expect(
        TransferScreen.filterAndSort(all, sort: TransferSortOption.potential)
            .first
            .id,
        'cheap');
    expect(
        TransferScreen.filterAndSort(all, sort: TransferSortOption.age)
            .first
            .id,
        'cheap');
    expect(
      TransferScreen.filterAndSort(all, sort: TransferSortOption.marketValue)
          .first
          .id,
      cheap.marketValue <= expensive.marketValue ? 'cheap' : 'expensive',
    );
  });

  test(
      'ContractEngine.minimumAcceptableWage scales with personality wage sensitivity',
      () {
    final player = PlayerGenerator.generateSquad(
            id: 't', name: 'Test FC', strengthTier: 70)
        .players
        .first;
    player.wage = 100;
    player.personality = PlayerPersonality.ambitious;
    final ambitious = ContractEngine.minimumAcceptableWage(player);

    player.personality = PlayerPersonality.loyal;
    final loyal = ContractEngine.minimumAcceptableWage(player);

    expect(ambitious, greaterThan(loyal));
    expect(ambitious, greaterThan(player.wage));
  });

  test(
      'ContractEngine.counterOffer never falls below the minimum acceptable wage',
      () {
    final player = PlayerGenerator.generateSquad(
            id: 't', name: 'Test FC', strengthTier: 70)
        .players
        .first;
    player.wage = 100;
    player.personality = PlayerPersonality.balanced;
    final minAcceptable = ContractEngine.minimumAcceptableWage(player);

    final counterFromLowOffer = ContractEngine.counterOffer(player, 0);
    final counterFromHighOffer =
        ContractEngine.counterOffer(player, minAcceptable * 2);

    expect(counterFromLowOffer, greaterThanOrEqualTo(minAcceptable));
    expect(counterFromHighOffer, greaterThanOrEqualTo(minAcceptable));
    expect(counterFromHighOffer, greaterThan(counterFromLowOffer));
  });

  test(
      'GameState.startContractNegotiation initializes a negotiation demanding at least the minimum acceptable wage',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final player = gameState.userTeam.players.first;
    player.personality = PlayerPersonality.balanced;

    gameState.startContractNegotiation(player.id);

    final negotiation = gameState.pendingContractNegotiation;
    expect(negotiation, isNotNull);
    expect(negotiation!.playerId, player.id);
    expect(negotiation.initialWage, player.wage);
    expect(
        negotiation.counterWage, ContractEngine.minimumAcceptableWage(player));
    expect(negotiation.roundsUsed, 0);
  });

  test(
      'GameState.offerContractWage accepts an offer at or above the minimum acceptable wage',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final player = gameState.userTeam.players.first;
    player.personality = PlayerPersonality.balanced;
    player.contractWeeksRemaining = 2;
    gameState.startContractNegotiation(player.id);
    final minAcceptable = ContractEngine.minimumAcceptableWage(player);
    final cost = gameState.renewalCostFor(player.id) +
        gameState.signingBonusFor(player.id);
    gameState.save!.budget = cost;

    final result = await gameState.offerContractWage(minAcceptable);

    expect(result, ContractOfferResult.accepted);
    expect(player.wage, minAcceptable);
    expect(player.contractWeeksRemaining, ContractEngine.renewalWeeks);
    expect(gameState.save!.budget, 0);
    expect(gameState.pendingContractNegotiation, isNull);
  });

  test(
      'GameState.offerContractWage returns insufficientFunds when the club cannot afford an accepted offer',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final player = gameState.userTeam.players.first;
    player.personality = PlayerPersonality.balanced;
    gameState.startContractNegotiation(player.id);
    final minAcceptable = ContractEngine.minimumAcceptableWage(player);
    gameState.save!.budget = 0;

    final result = await gameState.offerContractWage(minAcceptable);

    expect(result, ContractOfferResult.insufficientFunds);
    expect(gameState.pendingContractNegotiation, isNotNull);
  });

  test(
      'GameState.offerContractWage counters a low offer and walks away after too many rejected rounds',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final player = gameState.userTeam.players.first;
    player.personality = PlayerPersonality.balanced;
    gameState.startContractNegotiation(player.id);

    ContractOfferResult result = ContractOfferResult.countered;
    for (int i = 0; i < ContractEngine.maxNegotiationRounds; i++) {
      result = await gameState.offerContractWage(1);
      if (result != ContractOfferResult.countered) break;
      expect(gameState.pendingContractNegotiation!.roundsUsed, i + 1);
    }

    expect(result, ContractOfferResult.walkedAway);
    expect(gameState.pendingContractNegotiation, isNull);
  });

  test(
      'League.sortedStandings breaks a points tie by head-to-head record '
      'before falling back to overall goal difference', () {
    final a =
        PlayerGenerator.generateSquad(id: 'ha', name: 'A FC', strengthTier: 60);
    final b =
        PlayerGenerator.generateSquad(id: 'hb', name: 'B FC', strengthTier: 60);
    final c =
        PlayerGenerator.generateSquad(id: 'hc', name: 'C FC', strengthTier: 60);
    final d =
        PlayerGenerator.generateSquad(id: 'hd', name: 'D FC', strengthTier: 60);

    MatchResult result(String home, String away, int hg, int ag) => MatchResult(
        matchday: 1,
        homeTeamId: home,
        awayTeamId: away,
        homeGoals: hg,
        awayGoals: ag,
        events: []);
    Fixture fixture(String home, String away, int hg, int ag) => Fixture(
        matchday: 1,
        homeTeamId: home,
        awayTeamId: away,
        result: result(home, away, hg, ag));

    // Aとbは総勝点6で並ぶが、AはBより総得失点差で上回る(+3 対 0)。
    // ただし直接対決ではBがAに勝っているため、直接対決を優先すればBが上位になる。
    final fixtures = [
      fixture(a.id, b.id, 0, 1),
      fixture(a.id, c.id, 2, 0),
      fixture(a.id, d.id, 2, 0),
      fixture(b.id, c.id, 1, 0),
      fixture(b.id, d.id, 0, 2),
      fixture(c.id, d.id, 1, 1),
    ];
    final league = League(teams: [a, b, c, d], fixtures: fixtures, season: 1);

    final order = league.sortedStandings.map((r) => r.teamId).toList();

    expect(order, [b.id, a.id, d.id, c.id]);
  });

  test('GameState.cancelContractNegotiation clears the pending negotiation',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final player = gameState.userTeam.players.first;
    gameState.startContractNegotiation(player.id);
    expect(gameState.pendingContractNegotiation, isNotNull);

    gameState.cancelContractNegotiation();

    expect(gameState.pendingContractNegotiation, isNull);
  });

  test(
      'SeasonProjectionEngine.project favors the stronger team over many remaining fixtures',
      () {
    final strong = PlayerGenerator.generateSquad(
        id: 's', name: 'Strong FC', strengthTier: 90);
    final weak = PlayerGenerator.generateSquad(
        id: 'w', name: 'Weak FC', strengthTier: 30);
    final league = League(teams: [
      strong,
      weak
    ], fixtures: [
      Fixture(matchday: 1, homeTeamId: strong.id, awayTeamId: weak.id),
      Fixture(matchday: 2, homeTeamId: weak.id, awayTeamId: strong.id),
    ]);

    final projections = SeasonProjectionEngine.project(league,
        iterations: 300, random: Random(7));
    final strongProjection =
        projections.firstWhere((p) => p.teamId == strong.id);
    final weakProjection = projections.firstWhere((p) => p.teamId == weak.id);

    expect(strongProjection.avgFinalPoints,
        greaterThan(weakProjection.avgFinalPoints));
    expect(strongProjection.titleProbability,
        greaterThan(weakProjection.titleProbability));
  });

  test(
      'SeasonProjectionEngine.project reflects current standings exactly once the season is complete',
      () {
    final teamA =
        PlayerGenerator.generateSquad(id: 'a', name: 'A FC', strengthTier: 60);
    final teamB =
        PlayerGenerator.generateSquad(id: 'b', name: 'B FC', strengthTier: 60);
    final league = League(teams: [
      teamA,
      teamB
    ], fixtures: [
      Fixture(
        matchday: 1,
        homeTeamId: teamA.id,
        awayTeamId: teamB.id,
        result: MatchResult(
          matchday: 1,
          homeTeamId: teamA.id,
          awayTeamId: teamB.id,
          homeGoals: 3,
          awayGoals: 0,
          events: [],
        ),
      ),
    ]);

    final projections = SeasonProjectionEngine.project(league, iterations: 50);
    final aProjection = projections.firstWhere((p) => p.teamId == teamA.id);
    final bProjection = projections.firstWhere((p) => p.teamId == teamB.id);

    expect(aProjection.avgFinalPoints, 3);
    expect(bProjection.avgFinalPoints, 0);
    expect(aProjection.titleProbability, 1.0);
    expect(bProjection.titleProbability, 0.0);
  });

  test(
      'GameState.playNextMatchdayQuickSim resolves the whole matchday without leaving a half-time state',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');

    final result = await gameState.playNextMatchdayQuickSim();

    expect(result, isNotNull);
    expect(result!.matchday, 1);
    expect(gameState.isHalfTime, isFalse);
    expect(
        gameState.save!.league.fixturesForMatchday(1).any((f) =>
            (f.homeTeamId == gameState.userTeam.id ||
                f.awayTeamId == gameState.userTeam.id) &&
            f.result != null),
        isTrue);
  });

  test(
      'GameState.simulateAheadMatchdays advances several matchdays in order and clears isBusy',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');

    final results = await gameState.simulateAheadMatchdays(3);

    expect(results.length, 3);
    expect(results.map((r) => r.matchday).toList(), [1, 2, 3]);
    expect(gameState.isBusy, isFalse);
  });

  test(
      'GameState.seasonProjection ranks every league team with valid probabilities',
      () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');

    final projections = gameState.seasonProjection;

    expect(projections.length, gameState.save!.league.teams.length);
    for (final p in projections) {
      expect(p.titleProbability, inInclusiveRange(0.0, 1.0));
      expect(p.continentalProbability, inInclusiveRange(0.0, 1.0));
      expect(p.relegationProbability, inInclusiveRange(0.0, 1.0));
    }
    for (int i = 1; i < projections.length; i++) {
      expect(projections[i].avgFinalRank,
          greaterThanOrEqualTo(projections[i - 1].avgFinalRank));
    }
  });
}
