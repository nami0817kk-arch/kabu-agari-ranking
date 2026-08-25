import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soccer_manager/logic/board_engine.dart';
import 'package:soccer_manager/logic/contract_engine.dart';
import 'package:soccer_manager/logic/cup_engine.dart';
import 'package:soccer_manager/logic/happiness_engine.dart';
import 'package:soccer_manager/logic/lineup_utils.dart';
import 'package:soccer_manager/logic/loan_engine.dart';
import 'package:soccer_manager/logic/match_engine.dart';
import 'package:soccer_manager/logic/player_generator.dart';
import 'package:soccer_manager/logic/scouting_engine.dart';
import 'package:soccer_manager/logic/sponsor_engine.dart';
import 'package:soccer_manager/logic/training_engine.dart';
import 'package:soccer_manager/logic/transfer_market.dart';
import 'package:soccer_manager/data/name_pool.dart';
import 'package:soccer_manager/models/attributes.dart';
import 'package:soccer_manager/models/club_infrastructure.dart';
import 'package:soccer_manager/models/cup.dart';
import 'package:soccer_manager/models/formation.dart';
import 'package:soccer_manager/models/incoming_offer.dart';
import 'package:soccer_manager/models/league_theme.dart';
import 'package:soccer_manager/models/match_result.dart';
import 'package:soccer_manager/models/player.dart';
import 'package:soccer_manager/models/team.dart';
import 'package:soccer_manager/state/game_state.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('LineupUtils.autoFill fills the formation slot groups correctly', () {
    final team = PlayerGenerator.generateSquad(id: 't1', name: 'Test FC', strengthTier: 60);
    team.formation = Formation.f433;
    LineupUtils.autoFill(team);

    expect(team.startingXI.length, 11);
    final byId = {for (final p in team.players) p.id: p};
    // 完全一致した候補がいない枠は同じ大分類(グループ)内から補われるため、
    // 常に保証できるのはグループ単位の人数一致。
    final lineupGroups = team.startingXI.map((id) => byId[id]!.position.group).toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final expectedGroups = Formation.f433.slots.map((p) => p.group).toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    expect(lineupGroups, expectedGroups);
  });

  test('LineupUtils.autoFill excludes injured players', () {
    final team = PlayerGenerator.generateSquad(id: 't2', name: 'Test FC', strengthTier: 60);
    for (final p in team.players.where((p) => p.position == Position.st)) {
      p.injuryWeeks = 2;
    }
    LineupUtils.autoFill(team);
    final byId = {for (final p in team.players) p.id: p};
    final lineup = team.startingXI.map((id) => byId[id]!).toList();
    expect(lineup.every((p) => !p.isInjured), isTrue);
  });

  test('LineupUtils.autoFill falls back to same-group players when a position is missing', () {
    final team = PlayerGenerator.generateSquad(id: 't1b', name: 'Test FC', strengthTier: 60);
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

  test('GameState.scoutCandidates offers more candidates as scout staff level rises', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final baseCount = gameState.scoutCandidates.length;
    gameState.save!.budget = 100000;

    await gameState.upgradeStaff(StaffRole.scout);

    expect(gameState.scoutCandidateCount, baseCount + 1);
  });

  test('GameState.promoteYouthProspect moves the prospect into the squad', () async {
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
    final gk = PlayerGenerator.generate(position: Position.gk, strengthTier: 60);
    final fw = PlayerGenerator.generate(position: Position.st, strengthTier: 60);
    expect(gk.attributeValue(AttributeKeys.handling), greaterThan(fw.attributeValue(AttributeKeys.handling)));
    expect(gk.attributeValue(AttributeKeys.reflexes), greaterThan(fw.attributeValue(AttributeKeys.reflexes)));
  });

  test('Player.overall is the average of the four composite ratings', () {
    final p = PlayerGenerator.generate(position: Position.mc, strengthTier: 60);
    final expected = ((p.attack + p.defense + p.technique + p.stamina) / 4).round();
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

  test('Team.fromJson falls back to f442 for a removed formation name', () {
    final team = PlayerGenerator.generateSquad(id: 'tf', name: 'Test FC', strengthTier: 60);
    final json = team.toJson();
    json['formation'] = 'f532'; // 廃止された旧フォーメーション名
    final restored = Team.fromJson(json);
    expect(restored.formation, Formation.f442);
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

  test('ClubInfrastructure upgrades increase level and cost more each time', () {
    final infra = ClubInfrastructure();
    expect(infra.staffLevel(StaffRole.physio), 1);
    final firstCost = ClubInfrastructure.staffUpgradeCost(infra.staffLevel(StaffRole.physio));

    final upgraded = infra.upgradeStaff(StaffRole.physio);

    expect(upgraded, isTrue);
    expect(infra.staffLevel(StaffRole.physio), 2);
    final secondCost = ClubInfrastructure.staffUpgradeCost(infra.staffLevel(StaffRole.physio));
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

  test('GameState.upgradeFacility deducts budget and raises the level', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final cost = gameState.facilityUpgradeCostFor(FacilityType.stadium);
    gameState.save!.budget = cost;

    final ok = await gameState.upgradeFacility(FacilityType.stadium);

    expect(ok, isTrue);
    expect(gameState.save!.infrastructure.facilityLevel(FacilityType.stadium), 2);
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

  test('CupEngine.createKnockout builds a full bracket for a power-of-two field with no byes', () {
    final teamIds = List.generate(8, (i) => 't$i');
    final cup = CupEngine.createKnockout(type: CupType.domestic, name: '国内カップ', teamIds: teamIds);

    expect(cup.rounds.length, 1);
    expect(cup.rounds.first.length, 4);
    expect(cup.rounds.first.every((m) => !m.isBye), isTrue);
  });

  test('CupEngine.playNextMatch advances rounds until a single champion remains', () {
    final teams = List.generate(8, (i) => PlayerGenerator.generateSquad(id: 't$i', name: 'Club $i', strengthTier: 60));
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

  test('GameState creates a domestic cup on new game that can be played to completion', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');

    expect(gameState.domesticCup, isNotNull);
    expect(gameState.continentalCup, isNull);

    int guard = 0;
    do {
      await gameState.playNextCupMatch(CupType.domestic);
      guard++;
    } while (gameState.domesticCup!.nextUnplayedMatch != null && guard < 20);

    expect(gameState.domesticCup!.isComplete, isTrue);
  });

  test('HappinessEngine boosts happiness for starters and penalizes benched players', () {
    final team = PlayerGenerator.generateSquad(id: 'hteam', name: 'Happy FC', strengthTier: 60);
    LineupUtils.autoFill(team);
    for (final p in team.players) {
      p.happiness = 50;
      p.personality = PlayerPersonality.balanced;
    }
    final starter = team.players.firstWhere((p) => team.startingXI.contains(p.id));
    final benched = team.players.firstWhere((p) => !team.startingXI.contains(p.id));
    // 待遇要因を打ち消して出場機会の影響だけを検証できるようにする。
    starter.wage = 99999;
    benched.wage = 1;

    HappinessEngine.applyWeekly(team, leagueRank: 1, boardTargetRank: 4);

    expect(starter.happiness, greaterThan(50));
    expect(benched.happiness, lessThan(50));
  });

  test('HappinessEngine.reassure raises happiness but not above the threshold gate', () {
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

  test('SponsorEngine.generateOffers trades higher income for shorter duration', () {
    final offers = SponsorEngine.generateOffers(70);
    expect(offers.length, 3);
    final sorted = [...offers]..sort((a, b) => a.weeklyIncome.compareTo(b.weeklyIncome));
    expect(sorted.first.weeksRemaining, greaterThan(sorted.last.weeksRemaining));
  });

  test('GameState.chooseSponsor applies the selected deal and clears offers', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    expect(gameState.pendingSponsorOffers, isNotEmpty);

    final ok = await gameState.chooseSponsor(0);

    expect(ok, isTrue);
    expect(gameState.save!.sponsorDeal, isNotNull);
    expect(gameState.pendingSponsorOffers, isEmpty);
  });

  test('GameState.signLoanPlayer adds a loan player that returns after loanDurationWeeks', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final target = gameState.transferMarket.first;
    gameState.save!.budget = target.marketValue; // ローン料は移籍金の一部で足りるはず

    final ok = await gameState.signLoanPlayer(target.id);

    expect(ok, isTrue);
    final signed = gameState.userTeam.players.firstWhere((p) => p.id == target.id);
    expect(signed.isLoan, isTrue);
    expect(signed.loanWeeksRemaining, GameState.loanDurationWeeks);
  });

  test('GameState.buyPlayerOnInstallments splits the remaining cost into weekly payments', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final target = gameState.transferMarket.first;
    gameState.save!.budget = target.marketValue; // 頭金分は十分ある

    final ok = await gameState.buyPlayerOnInstallments(target.id);

    expect(ok, isTrue);
    expect(gameState.save!.pendingInstallments.length, 1);
    expect(gameState.userTeam.players.any((p) => p.id == target.id), isTrue);
  });

  test('ContractEngine.advanceWeek removes a loan player once loanWeeksRemaining reaches 0', () {
    final team = PlayerGenerator.generateSquad(id: 'lteam', name: 'Loan FC', strengthTier: 60);
    final loanPlayer = team.players.first;
    loanPlayer.isLoan = true;
    loanPlayer.loanWeeksRemaining = 1;

    final expired = ContractEngine.advanceWeek(team);

    expect(expired.any((p) => p.id == loanPlayer.id), isTrue);
    expect(team.players.any((p) => p.id == loanPlayer.id), isFalse);
  });

  test('NamePool.themedClubNames generates enough unique names for a full league', () {
    for (final theme in LeagueTheme.values) {
      final names = NamePool.themedClubNames(theme, teamsPerLeague - 1);
      expect(names.toSet().length, teamsPerLeague - 1);
    }
  });

  test('CupEngine.createKnockout never leaves a bye-vs-bye match unresolved for a non-power-of-two field', () {
    // 20チーム(2の累乗ではない)は32枠に切り上げられ、12個のBYEが生じる。
    final teamIds = List.generate(teamsPerLeague, (i) => 't$i');
    final teams = teamIds
        .map((id) => PlayerGenerator.generateSquad(id: id, name: id, strengthTier: 60))
        .toList();
    for (final t in teams) {
      LineupUtils.autoFill(t);
    }
    final cup = CupEngine.createKnockout(type: CupType.domestic, name: '国内カップ', teamIds: teamIds);

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

  test('GameState.startNewGame creates a full-size league with the selected theme name', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC', theme: LeagueTheme.spain);

    expect(gameState.save!.league.teams.length, teamsPerLeague);
    expect(gameState.save!.leagueName, LeagueTheme.spain.label);
  });

  test('MatchEngine.simulateMinutes only generates events within the requested minute range', () {
    final home = PlayerGenerator.generateSquad(id: 'h', name: 'Home FC', strengthTier: 60);
    final away = PlayerGenerator.generateSquad(id: 'a', name: 'Away FC', strengthTier: 60);
    LineupUtils.autoFill(home);
    LineupUtils.autoFill(away);

    final half = MatchEngine.simulateMinutes(home: home, away: away, startMinute: 46, endMinute: 90);

    expect(half.events.every((e) => e.minute >= 46 && e.minute <= 90), isTrue);
  });

  test('GameState.playNextMatchday stops at half-time for the user fixture; playSecondHalf finalizes it', () async {
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
        .firstWhere((f) => f.homeTeamId == merged.homeTeamId && f.awayTeamId == merged.awayTeamId);
    expect(fixture.result, isNotNull);
  });

  test('GameState.makeHalfTimeSubstitution swaps players and enforces the substitution limit', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    await gameState.playNextMatchday();
    expect(gameState.isHalfTime, isTrue);

    final team = gameState.userTeam;
    final outId = team.startingXI.first;
    final inId = team.players.firstWhere((p) => !team.startingXI.contains(p.id) && !p.isInjured).id;

    final ok = gameState.makeHalfTimeSubstitution(outPlayerId: outId, inPlayerId: inId);

    expect(ok, isTrue);
    expect(team.startingXI.contains(inId), isTrue);
    expect(team.startingXI.contains(outId), isFalse);
    expect(gameState.substitutionsUsed, 1);
  });

  test('GameState.playFriendly resolves a friendly without affecting league standings', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    expect(gameState.save!.friendlies, isNotEmpty);

    final result = await gameState.playFriendly(0);

    expect(result, isNotNull);
    expect(gameState.save!.friendlies[0].result, isNotNull);
    expect(gameState.save!.league.fixtures.every((f) => f.result == null), isTrue);
  });

  test('GameState.acceptIncomingOffer sells the player and adds the offered amount to budget', () async {
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

  test('GameState.acceptIncomingOffer backfills the starting XI when a starter is sold', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final team = gameState.userTeam;
    final target = team.players.firstWhere((p) => team.startingXI.contains(p.id));
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

  test('GameState.acceptIncomingOffer discards a stale offer without crediting budget '
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

  test('GameState.acceptIncomingOffer keeps the offer pending when the squad-size guard blocks the sale', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final team = gameState.userTeam;
    while (team.players.length > minSquadSize) {
      final removable = team.players.firstWhere((p) => !team.startingXI.contains(p.id));
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
    expect(gameState.incomingOffers.any((o) => o.id == 'guarded-offer'), isTrue);
  });

  test('GameState.playFriendly does not accumulate fatigue or cause injuries', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final lineup = MatchEngine.lineupOf(gameState.userTeam);
    final fatigueBefore = {for (final p in lineup) p.id: p.fatigue};
    final injuredBefore = lineup.where((p) => p.isInjured).map((p) => p.id).toSet();

    final result = await gameState.playFriendly(0);

    expect(result, isNotNull);
    for (final p in lineup) {
      expect(p.fatigue, fatigueBefore[p.id]);
    }
    final injuredAfter = lineup.where((p) => p.isInjured).map((p) => p.id).toSet();
    expect(injuredAfter, injuredBefore);
  });

  test('GameState.declineIncomingOffer removes the offer without affecting budget', () async {
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

  test('GameState.setReleaseClause sets and clears the release clause', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final target = gameState.userTeam.players.first;

    await gameState.setReleaseClause(target.id, 1234);
    expect(target.releaseClause, 1234);

    await gameState.setReleaseClause(target.id, null);
    expect(target.releaseClause, isNull);
  });

  test('GameState.acceptJobOffer switches clubs and resets confidence/board target', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final newTeamId = gameState.save!.league.teams.firstWhere((t) => t.id != 'user').id;
    gameState.save!.pendingJobOfferTeamId = newTeamId;
    gameState.save!.confidence = 10;

    final ok = await gameState.acceptJobOffer();

    expect(ok, isTrue);
    expect(gameState.save!.userTeamId, newTeamId);
    expect(gameState.save!.pendingJobOfferTeamId, isNull);
    expect(gameState.save!.confidence, 60);
  });

  test('GameState.declineJobOffer clears the pending offer without switching clubs', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    gameState.save!.pendingJobOfferTeamId = 'cpu0';

    await gameState.declineJobOffer();

    expect(gameState.save!.pendingJobOfferTeamId, isNull);
    expect(gameState.save!.userTeamId, 'user');
  });

  test('GameState.startNextSeason generates a batch of youth intake candidates within bounds', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');

    await gameState.startNextSeason();

    expect(gameState.pendingYouthIntake.length, inInclusiveRange(3, 5));
    expect(gameState.managerReputation, inInclusiveRange(0, 100));
  });

  test('GameState.keepYouthIntakePlayer moves a candidate into youth prospects', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    await gameState.startNextSeason();
    final candidate = gameState.pendingYouthIntake.first;

    final ok = await gameState.keepYouthIntakePlayer(candidate.id);

    expect(ok, isTrue);
    expect(gameState.save!.youthProspects.any((p) => p.id == candidate.id), isTrue);
    expect(gameState.pendingYouthIntake.any((p) => p.id == candidate.id), isFalse);
  });

  test('LoanEngine.weeklyRepaymentFor charges more in total for the longer, higher-interest term', () {
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

  test('GameState.takeLoan adds funds to the budget and refuses amounts above the borrowing limit', () async {
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

  test('GameState.maxLoanAmount shrinks by the outstanding debt of existing loans', () async {
    final gameState = GameState();
    await gameState.startNewGame('テストFC');
    final term = LoanEngine.terms.first;
    final beforeMax = gameState.maxLoanAmount;

    await gameState.takeLoan((beforeMax * 0.5).round(), term);

    expect(gameState.maxLoanAmount, lessThan(beforeMax));
  });

  test('GameState.playNextMatchday counts down the loan and clears it once the term ends', () async {
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
}
