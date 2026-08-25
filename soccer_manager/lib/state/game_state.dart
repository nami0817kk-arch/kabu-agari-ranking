import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bank_loan.dart';
import '../models/club_infrastructure.dart';
import '../models/cup.dart';
import '../models/formation.dart';
import '../models/incoming_offer.dart';
import '../models/installment.dart';
import '../models/league_theme.dart';
import '../models/player.dart';
import '../models/save_game.dart';
import '../models/sponsor.dart';
import '../models/team.dart';
import '../models/league.dart';
import '../models/match_result.dart';
import '../logic/board_engine.dart';
import '../logic/contract_engine.dart';
import '../logic/cup_engine.dart';
import '../logic/happiness_engine.dart';
import '../logic/loan_engine.dart';
import '../logic/player_generator.dart';
import '../logic/fixture_generator.dart';
import '../logic/lineup_utils.dart';
import '../logic/match_engine.dart';
import '../logic/scouting_engine.dart';
import '../logic/sponsor_engine.dart';
import '../logic/training_engine.dart';
import '../logic/transfer_market.dart';
import '../data/name_pool.dart';

const int maxSquadSize = 26;
const int minSquadSize = 12;

/// 1リーグあたりの参加クラブ数(自クラブ含む)。実際の主要リーグに近い規模とする。
const int teamsPerLeague = 20;

class GameState extends ChangeNotifier {
  static const _prefsKey = 'soccer_manager_save_v1';

  SaveGame? _save;
  bool initialized = false;
  List<Player> transferMarket = [];

  /// スカウトが見つけてきた、獲得可能な候補選手一覧(閲覧専用・未確定)。
  List<Player> scoutCandidates = [];

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
      _refreshScoutCandidates();
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

  Future<void> startNewGame(String clubName, {LeagueTheme theme = LeagueTheme.england}) async {
    final userTeam = PlayerGenerator.generateSquad(
      id: 'user',
      name: clubName,
      strengthTier: 60,
      isUserTeam: true,
    );
    const cpuCount = teamsPerLeague - 1;
    final cpuNames = NamePool.themedClubNames(theme, cpuCount);
    final cpuTeams = <Team>[];
    final rng = Random();
    for (int i = 0; i < cpuCount; i++) {
      final tier = 40 + rng.nextInt(35);
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
      leagueName: theme.label,
      boardTargetRank: BoardEngine.estimateTargetRank(league, 'user'),
      cups: [
        CupEngine.createKnockout(
          type: CupType.domestic,
          name: '国内カップ',
          teamIds: teams.map((t) => t.id).toList(),
        ),
      ],
      pendingSponsorOffers: SponsorEngine.generateOffers(userTeam.overallRating),
      friendlies: _generateFriendlies(teams, 'user'),
    );
    transferMarket = TransferMarket.generate();
    _refreshScoutCandidates();
    lastContractExpirations = [];
    notifyListeners();
    await _persist();
  }

  /// シーズン開幕前の親善試合を2試合分生成する(ランダムな相手と)。
  List<Fixture> _generateFriendlies(List<Team> teams, String userTeamId) {
    final opponents = teams.where((t) => t.id != userTeamId).toList()..shuffle(Random());
    final count = min(2, opponents.length);
    return List.generate(
      count,
      (i) => Fixture(matchday: 0, homeTeamId: userTeamId, awayTeamId: opponents[i].id),
    );
  }

  Future<void> deleteSave() async {
    _save = null;
    transferMarket = [];
    scoutCandidates = [];
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

  /// スタメンの特定選手を別の選手と入れ替える(戦術画面のピッチタップ操作用)。
  /// クォータ判定は行わず、指定された選手をそのまま入れ替える。
  void swapStartingPlayer({String? outPlayerId, required String inPlayerId}) {
    if (_save == null) return;
    final team = userTeam;
    if (outPlayerId != null) team.startingXI.remove(outPlayerId);
    if (!team.startingXI.contains(inPlayerId)) team.startingXI.add(inPlayerId);
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
    if (player.isLoan) return false; // ローン選手は他クラブの所有物のため放出できない
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
    if (player.isLoan) return false; // ローン選手には通常の契約更新は適用されない
    final cost = ContractEngine.renewalCost(player);
    if (_save!.budget < cost) return false;
    _save!.budget -= cost;
    ContractEngine.renewContract(player);
    notifyListeners();
    await _persist();
    return true;
  }

  /// 選手と話し合い、不満度を引き上げる。既に十分満足している場合は失敗する。
  Future<bool> reassurePlayer(String playerId) async {
    if (_save == null) return false;
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    final ok = HappinessEngine.reassure(player);
    if (ok) {
      notifyListeners();
      await _persist();
    }
    return ok;
  }

  /// 分割払い(頭金3割 + 残額を4週で均等払い)で移籍市場の選手を獲得する。
  Future<bool> buyPlayerOnInstallments(String playerId) async {
    if (_save == null) return false;
    final idx = transferMarket.indexWhere((p) => p.id == playerId);
    if (idx < 0) return false;
    if (userTeam.players.length >= maxSquadSize) return false;
    final player = transferMarket[idx];
    final total = player.marketValue;
    final downPayment = (total * 0.3).round();
    if (_save!.budget < downPayment) return false;

    _save!.budget -= downPayment;
    const weeks = 4;
    final remaining = total - downPayment;
    _save!.pendingInstallments.add(Installment(
      description: '${player.name} 分割払い残金',
      weeklyAmount: (remaining / weeks).ceil(),
      weeksRemaining: weeks,
    ));
    userTeam.players.add(player);
    transferMarket.removeAt(idx);
    notifyListeners();
    await _persist();
    return true;
  }

  /// ローン(期限付き移籍)で移籍市場の選手を獲得する。頭金は移籍金の2割、
  /// 週俸は6割に軽減される代わりに20週で自動的にチームを離れる。
  static const int loanFeeRatioPercent = 20;
  static const int loanDurationWeeks = 20;

  Future<bool> signLoanPlayer(String playerId) async {
    if (_save == null) return false;
    final idx = transferMarket.indexWhere((p) => p.id == playerId);
    if (idx < 0) return false;
    if (userTeam.players.length >= maxSquadSize) return false;
    final player = transferMarket[idx];
    final fee = (player.marketValue * loanFeeRatioPercent / 100).round();
    if (_save!.budget < fee) return false;

    _save!.budget -= fee;
    player.isLoan = true;
    player.loanWeeksRemaining = loanDurationWeeks;
    player.wage = (player.wage * 0.6).round().clamp(1, 999);
    userTeam.players.add(player);
    transferMarket.removeAt(idx);
    notifyListeners();
    await _persist();
    return true;
  }

  /// 契約中のスポンサーがなければ、次に選べる候補を返す(既に選択済みならnull)。
  List<SponsorDeal> get pendingSponsorOffers => _save?.pendingSponsorOffers ?? [];

  Future<bool> chooseSponsor(int offerIndex) async {
    if (_save == null) return false;
    if (offerIndex < 0 || offerIndex >= _save!.pendingSponsorOffers.length) return false;
    _save!.sponsorDeal = _save!.pendingSponsorOffers[offerIndex];
    _save!.pendingSponsorOffers = [];
    notifyListeners();
    await _persist();
    return true;
  }

  int get scoutCost => ScoutingEngine.scoutCostFor(_save!.infrastructure.staffLevel(StaffRole.scout));

  int get maxYouthProspects =>
      ScoutingEngine.maxProspectsFor(_save!.infrastructure.facilityLevel(FacilityType.youthFacility));

  /// スカウト網が一度に見つけてくる候補選手の人数(スカウトのレベルが高いほど広がる)。
  int get scoutCandidateCount =>
      ScoutingEngine.scoutCandidateCountFor(_save!.infrastructure.staffLevel(StaffRole.scout));

  void _refreshScoutCandidates() {
    if (_save == null) {
      scoutCandidates = [];
      return;
    }
    final scoutLevel = _save!.infrastructure.staffLevel(StaffRole.scout);
    final count = ScoutingEngine.scoutCandidateCountFor(scoutLevel);
    scoutCandidates = List.generate(
      count,
      (_) => ScoutingEngine.generateScoutedProspect(scoutLevel: scoutLevel),
    );
  }

  /// スカウト網を無償で更新し、候補選手の顔ぶれを一新する。
  Future<void> refreshScoutCandidates() async {
    if (_save == null) return;
    _refreshScoutCandidates();
    notifyListeners();
  }

  /// 候補選手一覧から1人選んでスカウト費用を払い、ユース昇格候補として迎える。
  Future<bool> scoutProspect(String candidateId) async {
    if (_save == null) return false;
    final idx = scoutCandidates.indexWhere((p) => p.id == candidateId);
    if (idx < 0) return false;
    final infra = _save!.infrastructure;
    final cost = ScoutingEngine.scoutCostFor(infra.staffLevel(StaffRole.scout));
    final maxP = ScoutingEngine.maxProspectsFor(infra.facilityLevel(FacilityType.youthFacility));
    if (_save!.budget < cost) return false;
    if (_save!.youthProspects.length >= maxP) return false;
    _save!.budget -= cost;
    final signed = scoutCandidates.removeAt(idx);
    _save!.youthProspects.add(signed);
    final scoutLevel = infra.staffLevel(StaffRole.scout);
    scoutCandidates.add(ScoutingEngine.generateScoutedProspect(scoutLevel: scoutLevel));
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

  /// シーズン終了時に一括生成された、選抜待ちのユースインテーク候補。
  List<Player> get pendingYouthIntake => _save?.pendingYouthIntake ?? [];

  /// ユースインテーク候補をユース昇格候補として引き取る(枠が一杯なら失敗)。
  Future<bool> keepYouthIntakePlayer(String playerId) async {
    if (_save == null) return false;
    if (_save!.youthProspects.length >= maxYouthProspects) return false;
    final idx = _save!.pendingYouthIntake.indexWhere((p) => p.id == playerId);
    if (idx < 0) return false;
    final player = _save!.pendingYouthIntake.removeAt(idx);
    _save!.youthProspects.add(player);
    notifyListeners();
    await _persist();
    return true;
  }

  /// ユースインテーク候補を解雇する。
  Future<void> releaseYouthIntakePlayer(String playerId) async {
    if (_save == null) return;
    _save!.pendingYouthIntake.removeWhere((p) => p.id == playerId);
    notifyListeners();
    await _persist();
  }

  /// 選手のリリース条項(解放金額)を設定・解除する。nullで解除。
  Future<void> setReleaseClause(String playerId, int? amount) async {
    if (_save == null) return;
    final player = userTeam.players.firstWhere((p) => p.id == playerId);
    player.releaseClause = amount;
    notifyListeners();
    await _persist();
  }

  /// プレシーズン親善試合(1試合分)を消化する。順位やカップ戦には影響しない。
  Future<MatchResult?> playFriendly(int index) async {
    if (_save == null) return null;
    if (index < 0 || index >= _save!.friendlies.length) return null;
    final f = _save!.friendlies[index];
    if (f.result != null) return null;
    final league = _save!.league;
    final home = league.teams.firstWhere((t) => t.id == f.homeTeamId);
    final away = league.teams.firstWhere((t) => t.id == f.awayTeamId);
    // MatchEngine.simulate()は内部でapplyPostMatchEffects()を呼び疲労蓄積・
    // 負傷判定を行ってしまうため、プレシーズン親善試合では使わない。前半・後半を
    // simulateMinutesで直接シミュレートし、疲労・負傷への影響を与えないようにする。
    final first = MatchEngine.simulateMinutes(home: home, away: away, startMinute: 1, endMinute: 45);
    final second = MatchEngine.simulateMinutes(home: home, away: away, startMinute: 46, endMinute: 90);
    final result = MatchResult(
      matchday: 0,
      homeTeamId: home.id,
      awayTeamId: away.id,
      homeGoals: first.homeGoals + second.homeGoals,
      awayGoals: first.awayGoals + second.awayGoals,
      events: [...first.events, ...second.events],
    );
    f.result = result;
    // 実戦感覚を養う程度の軽い士気向上(疲労・負傷への影響は与えない)。
    for (final p in MatchEngine.lineupOf(userTeam)) {
      p.morale = (p.morale + 3).clamp(0, 100);
    }
    notifyListeners();
    await _persist();
    return result;
  }

  /// 他クラブから届いている、自クラブ選手への移籍オファー。
  List<IncomingOffer> get incomingOffers => _save?.incomingOffers ?? [];

  Future<bool> acceptIncomingOffer(String offerId) async {
    if (_save == null) return false;
    final idx = _save!.incomingOffers.indexWhere((o) => o.id == offerId);
    if (idx < 0) return false;
    final offer = _save!.incomingOffers[idx];
    final team = userTeam;
    // 対象選手が既にチームを離れている場合(他クラブへの就任・別オファーの
    // 承諾などで既に放出済み)は、対価を得ずにオファーだけを破棄する。
    if (!team.players.any((p) => p.id == offer.playerId)) {
      _save!.incomingOffers.removeAt(idx);
      notifyListeners();
      await _persist();
      return false;
    }
    if (team.players.length <= minSquadSize) return false;
    _save!.incomingOffers.removeAt(idx);
    team.players.removeWhere((p) => p.id == offer.playerId);
    final wasStarter = team.startingXI.remove(offer.playerId);
    if (wasStarter) {
      LineupUtils.autoFill(team);
    }
    _save!.budget += offer.amount;
    notifyListeners();
    await _persist();
    return true;
  }

  Future<void> declineIncomingOffer(String offerId) async {
    if (_save == null) return;
    _save!.incomingOffers.removeWhere((o) => o.id == offerId);
    notifyListeners();
    await _persist();
  }

  int _incomingOfferSeq = 0;

  /// 移籍オファーの週次処理: 期限切れの削除、新規オファーの抽選発生、
  /// リリース条項の自動成立を行う。売却済み選手の名前を返す(UI通知用)。
  static final Random _offerRng = Random();

  List<String> _advanceIncomingOffers() {
    final autoSold = <String>[];
    for (final o in List<IncomingOffer>.from(_save!.incomingOffers)) {
      o.weeksRemaining -= 1;
      if (o.weeksRemaining <= 0) {
        _save!.incomingOffers.remove(o);
      }
    }

    final team = userTeam;
    if (team.players.length > minSquadSize + 2 &&
        _save!.incomingOffers.length < 3 &&
        _offerRng.nextDouble() < 0.12) {
      final eligible = team.players
          .where((p) => !p.isLoan && !_save!.incomingOffers.any((o) => o.playerId == p.id))
          .toList();
      if (eligible.isNotEmpty) {
        final weights = eligible.map((p) => (p.overall - 30).clamp(1, 99)).toList();
        final totalWeight = weights.fold<int>(0, (s, w) => s + w);
        var r = _offerRng.nextInt(totalWeight);
        var chosen = eligible.last;
        for (int i = 0; i < eligible.length; i++) {
          if (r < weights[i]) {
            chosen = eligible[i];
            break;
          }
          r -= weights[i];
        }

        final buyerCandidates = _save!.league.teams.where((t) => t.id != _save!.userTeamId).toList();
        final buyer = buyerCandidates[_offerRng.nextInt(buyerCandidates.length)];

        if (chosen.releaseClause != null) {
          // リリース条項がある場合は交渉なしで即成立する。
          final amount = chosen.releaseClause!;
          team.players.removeWhere((p) => p.id == chosen.id);
          final wasStarter = team.startingXI.remove(chosen.id);
          if (wasStarter) {
            // スタメンが抜けた穴を自動で埋める(次の試合が即座に行われるため、
            // ユーザーが手動で編成を直す猶予がない)。
            LineupUtils.autoFill(team);
          }
          _save!.budget += amount;
          autoSold.add(chosen.name);
        } else {
          final amount = (chosen.marketValue * (0.9 + _offerRng.nextDouble() * 0.4)).round();
          _save!.incomingOffers.add(IncomingOffer(
            id: 'offer${_incomingOfferSeq++}',
            playerId: chosen.id,
            playerName: chosen.name,
            buyerClubName: buyer.name,
            amount: amount,
          ));
        }
      }
    }
    return autoSold;
  }

  /// 直近のplayNextMatchdayでリリース条項により自動売却された選手名。
  List<String> lastReleaseClauseSales = [];

  /// 監督としての世間の評価(0-100)。
  int get managerReputation => _save?.managerReputation ?? 50;

  /// 他クラブから監督就任オファーが届いている場合、そのクラブ。
  Team? get pendingJobOfferTeam {
    final teamId = _save?.pendingJobOfferTeamId;
    if (teamId == null) return null;
    return _save!.league.teams.firstWhere((t) => t.id == teamId);
  }

  Future<bool> acceptJobOffer() async {
    if (_save == null || _save!.pendingJobOfferTeamId == null) return false;
    final newTeamId = _save!.pendingJobOfferTeamId!;
    _save!.userTeamId = newTeamId;
    _save!.pendingJobOfferTeamId = null;
    _save!.confidence = 60;
    _save!.boardTargetRank = BoardEngine.estimateTargetRank(_save!.league, newTeamId);
    notifyListeners();
    await _persist();
    return true;
  }

  Future<void> declineJobOffer() async {
    if (_save == null) return;
    _save!.pendingJobOfferTeamId = null;
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
    if (teamId != _save!.userTeamId) return base;

    final stadiumLevel = _save!.infrastructure.facilityLevel(FacilityType.stadium);
    // 観客動員は監督への信頼度と現在の順位に連動する(強豪・高信頼ほど満員に近づく)。
    final attendanceFactor =
        (0.7 + _save!.confidence / 250 + (teamCount - rank) / teamCount * 0.3).clamp(0.6, 1.4);
    final matchdayIncome = ((base + (stadiumLevel - 1) * 80) * attendanceFactor).round();
    final sponsorIncome = _save!.sponsorDeal?.weeklyIncome ?? 0;
    return matchdayIncome + sponsorIncome;
  }

  int get weeklyWageBill => ContractEngine.weeklyWageBill(userTeam) + _save!.infrastructure.totalStaffWeeklyWage;

  /// 銀行から借り入れている融資一覧。
  List<BankLoan> get bankLoans => _save?.bankLoans ?? [];

  /// 融資の残り返済総額(元本+利息のうち未払い分)。
  int get outstandingLoanDebt => bankLoans.fold<int>(0, (s, l) => s + l.totalRemaining);

  /// 現在追加で借り入れ可能な上限額。スタジアムの規模と監督としての評価が高いほど拡大する。
  int get maxLoanAmount => LoanEngine.maxBorrowable(
        stadiumLevel: _save!.infrastructure.facilityLevel(FacilityType.stadium),
        reputation: _save!.managerReputation,
        outstandingDebt: outstandingLoanDebt,
      );

  int _loanSeq = 0;

  /// 銀行融資を申し込む。頭金なしで即座に資金を得られる代わりに、指定した返済プランで
  /// 毎週の返済が発生する。
  Future<bool> takeLoan(int amount, LoanTerm term) async {
    if (_save == null || amount <= 0) return false;
    if (amount > maxLoanAmount) return false;
    final weekly = LoanEngine.weeklyRepaymentFor(amount, term);
    _save!.bankLoans.add(BankLoan(
      id: 'loan${_loanSeq++}',
      principal: amount,
      weeklyRepayment: weekly,
      termWeeks: term.weeks,
      weeksRemaining: term.weeks,
    ));
    _save!.budget += amount;
    notifyListeners();
    await _persist();
    return true;
  }

  /// フィジオのレベルに応じた負傷の発生率・療養期間の軽減係数(1.0で軽減なし)。
  double get _userInjuryFactor =>
      (1 - (_save!.infrastructure.staffLevel(StaffRole.physio) - 1) * 0.15).clamp(0.4, 1.0);

  double _injuryFactorFor(String teamId) => teamId == _save!.userTeamId ? _userInjuryFactor : 1.0;

  // ---- ハーフタイム対応の試合進行(自クラブの試合のみ) ----
  Fixture? _liveFixture;
  HalfResult? _liveFirstHalf;
  int _liveSubstitutionsUsed = 0;
  static const int maxSubstitutionsPerMatch = 3;

  /// 自クラブの試合が前半終了・ハーフタイム待ちの状態かどうか。
  bool get isHalfTime => _liveFixture != null && _liveFirstHalf != null;

  Fixture? get liveFixture => _liveFixture;
  HalfResult? get liveFirstHalf => _liveFirstHalf;

  int get substitutionsUsed => _liveSubstitutionsUsed;
  bool get canMakeSubstitution => _liveSubstitutionsUsed < maxSubstitutionsPerMatch;

  /// ハーフタイムの交代操作。通常のswapStartingPlayerに交代枠の消費を加える。
  bool makeHalfTimeSubstitution({required String outPlayerId, required String inPlayerId}) {
    if (!canMakeSubstitution) return false;
    swapStartingPlayer(outPlayerId: outPlayerId, inPlayerId: inPlayerId);
    _liveSubstitutionsUsed++;
    notifyListeners();
    return true;
  }

  /// 次の節を進行する。CPU同士の試合は即座に消化するが、自クラブの試合は
  /// 前半のみをシミュレートしてハーフタイム状態にする(交代・戦術変更後、
  /// [playSecondHalf]で後半を消化する)。前半の結果を返す。
  Future<HalfResult?> playNextMatchday() async {
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

    // ユーザークラブのみ契約消化・契約切れ(ローン満了含む)を処理する（CPUクラブは対象外）
    final expired = ContractEngine.advanceWeek(userTeam);
    lastContractExpirations = expired.map((p) => p.name).toList();

    // 選手の不満度を更新する。
    final preMatchRank = league.sortedStandings.indexWhere((r) => r.teamId == _save!.userTeamId) + 1;
    HappinessEngine.applyWeekly(userTeam, leagueRank: preMatchRank, boardTargetRank: _save!.boardTargetRank);

    // スポンサー契約の消化・分割払いの引き落とし。
    if (_save!.sponsorDeal != null) {
      _save!.sponsorDeal!.weeksRemaining -= 1;
      if (_save!.sponsorDeal!.weeksRemaining <= 0) {
        _save!.sponsorDeal = null;
      }
    }
    if (_save!.sponsorDeal == null && _save!.pendingSponsorOffers.isEmpty) {
      _save!.pendingSponsorOffers = SponsorEngine.generateOffers(userTeam.overallRating);
    }
    for (final inst in List<Installment>.from(_save!.pendingInstallments)) {
      _save!.budget -= inst.weeklyAmount;
      inst.weeksRemaining -= 1;
      if (inst.weeksRemaining <= 0) {
        _save!.pendingInstallments.remove(inst);
      }
    }

    // 融資の週次返済。
    for (final loan in List<BankLoan>.from(_save!.bankLoans)) {
      _save!.budget -= loan.weeklyRepayment;
      loan.weeksRemaining -= 1;
      if (loan.weeksRemaining <= 0) {
        _save!.bankLoans.remove(loan);
      }
    }

    // 移籍オファーの週次処理(期限切れ削除・新規発生・リリース条項の自動成立)。
    lastReleaseClauseSales = _advanceIncomingOffers();

    final md = next.matchday;
    Fixture? userFixture;
    HalfResult? userFirstHalf;
    for (final f in league.fixturesForMatchday(md)) {
      final home = league.teams.firstWhere((t) => t.id == f.homeTeamId);
      final away = league.teams.firstWhere((t) => t.id == f.awayTeamId);
      final isUserFixture = f.homeTeamId == _save!.userTeamId || f.awayTeamId == _save!.userTeamId;
      if (isUserFixture) {
        userFixture = f;
        userFirstHalf = MatchEngine.simulateMinutes(home: home, away: away, startMinute: 1, endMinute: 45);
      } else {
        f.result = MatchEngine.simulate(home: home, away: away, matchday: md);
      }
    }

    _save!.budget += weeklyIncomeFor(_save!.userTeamId);
    _save!.budget -= weeklyWageBill;
    transferMarket = TransferMarket.generate();
    _refreshScoutCandidates();

    if (userFixture != null && userFirstHalf != null) {
      _liveFixture = userFixture;
      _liveFirstHalf = userFirstHalf;
      _liveSubstitutionsUsed = 0;
    }

    notifyListeners();
    await _persist();
    return userFirstHalf;
  }

  /// ハーフタイムでの交代・戦術変更を反映して後半を消化し、試合を確定する。
  Future<MatchResult?> playSecondHalf() async {
    if (_save == null || _liveFixture == null || _liveFirstHalf == null) return null;
    final league = _save!.league;
    final f = _liveFixture!;
    final home = league.teams.firstWhere((t) => t.id == f.homeTeamId);
    final away = league.teams.firstWhere((t) => t.id == f.awayTeamId);

    final second = MatchEngine.simulateMinutes(home: home, away: away, startMinute: 46, endMinute: 90);
    MatchEngine.applyPostMatchEffects(
      home: home,
      away: away,
      homeInjuryFactor: _injuryFactorFor(home.id),
      awayInjuryFactor: _injuryFactorFor(away.id),
    );

    final merged = MatchResult(
      matchday: f.matchday,
      homeTeamId: f.homeTeamId,
      awayTeamId: f.awayTeamId,
      homeGoals: _liveFirstHalf!.homeGoals + second.homeGoals,
      awayGoals: _liveFirstHalf!.awayGoals + second.awayGoals,
      events: [..._liveFirstHalf!.events, ...second.events],
    );
    f.result = merged;

    final delta = BoardEngine.confidenceDeltaForMatch(merged, _save!.userTeamId);
    _save!.confidence = (_save!.confidence + delta).clamp(0, 100);

    _liveFixture = null;
    _liveFirstHalf = null;
    _liveSubstitutionsUsed = 0;

    notifyListeners();
    await _persist();
    return merged;
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
    // ユースインテーク: 複数候補を一括生成し、選抜はユーザーに委ねる。
    final intakeCount = 3 + Random().nextInt(3);
    _save!.pendingYouthIntake = List.generate(
      intakeCount,
      (_) => ScoutingEngine.generateAcademyGraduate(youthCoachLevel: infra.staffLevel(StaffRole.youthCoach)),
    );

    // 監督としての世間の評価を更新する(目標達成なら上昇、大きく未達なら下降)。
    if (finalRank <= _save!.boardTargetRank) {
      _save!.managerReputation = (_save!.managerReputation + 8).clamp(0, 100);
    } else if (finalRank > _save!.boardTargetRank + 2) {
      _save!.managerReputation = (_save!.managerReputation - 5).clamp(0, 100);
    }
    // 評価が高く好成績を残すと、他クラブから監督就任オファーが届くことがある。
    if (_save!.pendingJobOfferTeamId == null &&
        _save!.managerReputation >= 55 &&
        finalRank <= (league.teams.length / 2).ceil()) {
      final candidates = league.teams
          .where((t) => t.id != _save!.userTeamId && t.overallRating > userTeam.overallRating)
          .toList()
        ..sort((a, b) => b.overallRating.compareTo(a.overallRating));
      if (candidates.isNotEmpty && Random().nextDouble() < 0.25) {
        _save!.pendingJobOfferTeamId = candidates.first.id;
      }
    }

    final newFixtures = FixtureGenerator.generateDoubleRoundRobin(league.teams);
    _save!.league = League(teams: league.teams, fixtures: newFixtures, season: league.season + 1);
    _save!.boardTargetRank = BoardEngine.estimateTargetRank(_save!.league, _save!.userTeamId);
    transferMarket = TransferMarket.generate();
    _refreshScoutCandidates();

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
    _save!.friendlies = _generateFriendlies(league.teams, _save!.userTeamId);

    notifyListeners();
    await _persist();
  }
}
