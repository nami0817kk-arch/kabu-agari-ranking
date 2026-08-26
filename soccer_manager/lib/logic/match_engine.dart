import 'dart:math';
import '../models/attributes.dart';
import '../models/formation.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../models/match_result.dart';
import '../models/weather.dart';
import 'lineup_utils.dart';
import 'training_engine.dart';

/// この枚数の警告が貯まると次節出場停止になる(退場は即1試合出場停止)。
const int yellowCardSuspensionThreshold = 5;

/// 分単位区間([MatchEngine.simulateMinutes])1回分のスコア・イベント。
class HalfResult {
  final int homeGoals;
  final int awayGoals;
  final List<MatchEvent> events;

  const HalfResult(
      {required this.homeGoals, required this.awayGoals, required this.events});
}

class MatchEngine {
  static final Random _rng = Random();

  static double _condition(Player p) =>
      (1 - p.fatigue / 250) *
      (0.85 + p.morale / 500) *
      (0.8 + p.matchSharpness / 500);

  /// 先発11人を解決する。未設定・不整合な場合は負傷者を除いた総合力上位11人で代用する。
  static List<Player> lineupOf(Team t) {
    if (t.startingXI.isNotEmpty) {
      final byId = {for (final p in t.players) p.id: p};
      final lineup = t.startingXI
          .map((id) => byId[id])
          .whereType<Player>()
          .where((p) =>
              !p.isInjured &&
              !p.isOnInternationalDuty &&
              !p.isLoanedOut &&
              !p.isSuspended)
          .toList();
      if (lineup.length >= 7) return lineup;
    }
    final available = t.players
        .where((p) =>
            !p.isInjured &&
            !p.isOnInternationalDuty &&
            !p.isLoanedOut &&
            !p.isSuspended)
        .toList()
      ..sort((a, b) => b.overall.compareTo(a.overall));
    return available.take(11).toList();
  }

  /// スカウティングレポート・マンマーク指令の対象となる「キープレイヤー」
  /// (出場想定メンバーの中で最も総合力が高い選手)を1人特定する。
  static Player? identifyKeyPlayer(List<Player> lineup) {
    Player? keyPlayer;
    for (final p in lineup) {
      if (keyPlayer == null || p.overall > keyPlayer.overall) keyPlayer = p;
    }
    return keyPlayer;
  }

  /// デューティ(攻撃的/バランス/守備的)による攻撃貢献度の補正。
  static double _dutyAttackMultiplier(PlayerDuty duty) => switch (duty) {
        PlayerDuty.attack => 1.15,
        PlayerDuty.support => 1.0,
        PlayerDuty.defend => 0.85,
      };

  /// デューティによる守備貢献度の補正(攻撃的デューティは守備が手薄になる)。
  static double _dutyDefenseMultiplier(PlayerDuty duty) => switch (duty) {
        PlayerDuty.defend => 1.15,
        PlayerDuty.support => 1.0,
        PlayerDuty.attack => 0.85,
      };

  /// ロールに応じた貢献度補正。ロールが重視する能力値の平均が選手本来の
  /// 攻撃力/守備力より高ければボーナス、低ければペナルティになる
  /// (=適性の合わないロールを割り当てると損をする)。
  static double roleMultiplier(Player p, {required bool forAttack}) {
    final keyAttributes = p.role.keyAttributes;
    if (keyAttributes.isEmpty) return 1.0;
    final base = forAttack ? p.attack : p.defense;
    final roleRating =
        keyAttributes.fold<int>(0, (s, k) => s + p.attributeValue(k)) /
            keyAttributes.length;
    return (1 + (roleRating - base) / 150).clamp(0.85, 1.2);
  }

  /// 本職以外のポジションで起用された際の貢献度ペナルティ。副ポジションと
  /// して登録済みなら軽微(慣れが増すほど解消)、それ以外(同グループの
  /// 代役)はより大きなペナルティになる。
  static double positionFitMultiplier(Player p, Position assignedSlot) {
    if (assignedSlot == p.position) return 1.0;
    final familiarity = p.familiarityFor(assignedSlot) / 100;
    if (p.secondaryPositions.contains(assignedSlot)) {
      return 0.90 + 0.10 * familiarity;
    }
    return 0.75 + 0.15 * familiarity;
  }

  static double _attackPower(Team t, List<Player> lineup,
      {String? suppressedId}) {
    final relevant = lineup
        .where((p) =>
            p.position.group == PositionGroup.att ||
            p.position.group == PositionGroup.mid)
        .toList();
    if (relevant.isEmpty) return 40;
    final slotById = LineupUtils.assignedSlotByPlayerId(t);
    final total = relevant.fold<double>(
      0,
      (s, p) =>
          s +
          p.attack *
              _condition(p) *
              _dutyAttackMultiplier(p.duty) *
              roleMultiplier(p, forAttack: true) *
              positionFitMultiplier(p, slotById[p.id] ?? p.position) *
              (p.id == suppressedId ? 0.8 : 1.0),
    );
    final lineFactor = 1 + (t.lineHeight - 50) / 400;
    final widthFactor = 1 + (t.width - 50) / 500;
    final tempoFactor = 1 + (t.tempo - 50) / 500;
    final result = (total / relevant.length) *
        t.formation.attackBias *
        lineFactor *
        widthFactor *
        tempoFactor;
    return t.timeWastingMode ? result * 0.92 : result;
  }

  static double _defensePower(Team t, List<Player> lineup) {
    final relevant = lineup
        .where((p) =>
            p.position.group == PositionGroup.def ||
            p.position.group == PositionGroup.gk)
        .toList();
    if (relevant.isEmpty) return 40;
    final slotById = LineupUtils.assignedSlotByPlayerId(t);
    final total = relevant.fold<double>(
      0,
      (s, p) =>
          s +
          p.defense *
              _condition(p) *
              _dutyDefenseMultiplier(p.duty) *
              roleMultiplier(p, forAttack: false) *
              positionFitMultiplier(p, slotById[p.id] ?? p.position),
    );
    final pressFactor = 1 + (t.pressing - 50) / 400;
    final lineRiskFactor = 1 + (50 - t.lineHeight) / 500;
    final widthRiskFactor = 1 - (t.width - 50) / 800;
    final result = (total / relevant.length) *
        t.formation.defenseBias *
        pressFactor *
        lineRiskFactor *
        widthRiskFactor;
    return t.timeWastingMode ? result * 1.08 : result;
  }

  /// [markingTeam]がマンマーク役を出場させている場合、[targetLineup]の
  /// キープレイヤーのIDを返す(攻撃力算出時にそのプレイヤーの貢献を抑える)。
  static String? markedTargetId(
      Team markingTeam, List<Player> markingLineup, List<Player> targetLineup) {
    final markerId = markingTeam.manMarkerId;
    if (markerId == null) return null;
    final markerActive = markingLineup.any((p) => p.id == markerId);
    if (!markerActive) return null;
    return identifyKeyPlayer(targetLineup)?.id;
  }

  static Player? _pickScorer(List<Player> lineup) {
    final candidates = lineup
        .where((p) =>
            p.position.group == PositionGroup.att ||
            p.position.group == PositionGroup.mid)
        .toList();
    if (candidates.isEmpty) return lineup.isNotEmpty ? lineup.first : null;
    final total = candidates.fold<int>(0, (s, p) => s + p.attack);
    if (total <= 0) return candidates[_rng.nextInt(candidates.length)];
    int r = _rng.nextInt(total);
    for (final p in candidates) {
      if (r < p.attack) return p;
      r -= p.attack;
    }
    return candidates.last;
  }

  /// セットプレー担当に指名された選手を出場中のメンバーから探す。
  /// 指名なし、または指名選手が出場していない(負傷・出場停止など)場合はnull。
  static Player? _pickSetPieceTaker(String? takerId, List<Player> lineup) {
    if (takerId == null) return null;
    for (final p in lineup) {
      if (p.id == takerId) return p;
    }
    return null;
  }

  static void _applyFatigue(Team t, List<Player> lineup,
      {double weatherFactor = 1.0, double intensity = 1.0}) {
    final pressFatigueFactor = 1 + (t.pressing - 50) / 200;
    final tempoFatigueFactor = 1 + (t.tempo - 50) / 300;
    final timeWastingFactor = t.timeWastingMode ? 0.85 : 1.0;
    for (final p in lineup) {
      final gain = (12 + _rng.nextInt(8)) *
          pressFatigueFactor *
          tempoFatigueFactor *
          weatherFactor *
          timeWastingFactor *
          intensity;
      p.fatigue = (p.fatigue + gain.round()).clamp(0, 100);
    }
  }

  /// 前半終了時点(ハーフタイム)で、そこまでの運動量に応じた疲労を先に
  /// 反映する。従来は試合終了後にまとめて疲労を加算していたため、後半の
  /// シミュレーションが前半の運動量を全く考慮しないという問題があった。
  /// ここで前半分(intensity 0.5)を反映し、残り半分は
  /// [applyPostMatchEffects]で後半終了時にまとめて反映する。
  static void applyHalfTimeFatigue({
    required Team home,
    required Team away,
    Weather weather = Weather.clear,
  }) {
    final homeLineup = lineupOf(home);
    final awayLineup = lineupOf(away);
    _applyFatigue(home, homeLineup,
        weatherFactor: weather.fatigueMultiplier, intensity: 0.5);
    _applyFatigue(away, awayLineup,
        weatherFactor: weather.fatigueMultiplier, intensity: 0.5);
  }

  /// 本職外のスロットで出場した選手のポジション慣れ度を積み増す。
  static void _growPositionFamiliarity(Team t, List<Player> lineup) {
    final slotById = LineupUtils.assignedSlotByPlayerId(t);
    for (final p in lineup) {
      final slot = slotById[p.id];
      if (slot == null) continue;
      p.growFamiliarity(slot);
    }
  }

  /// 出場した選手はマッチシャープネスが上昇し、出場しなかった選手は
  /// 緩やかに低下する(下限あり)。
  static void _updateMatchSharpness(Team t, List<Player> lineup) {
    final lineupIds = lineup.map((p) => p.id).toSet();
    for (final p in t.players) {
      if (lineupIds.contains(p.id)) {
        p.matchSharpness = (p.matchSharpness + 6).clamp(0, 100);
      } else {
        p.matchSharpness = (p.matchSharpness - 3).clamp(30, 100);
      }
    }
  }

  static void _rollInjuries(List<Player> lineup, double injuryFactor) {
    for (final p in lineup) {
      // 基礎体力(naturalFitness)が高い選手ほど負傷しにくい。
      final naturalFitnessFactor =
          (1 - (p.attributeValue(AttributeKeys.naturalFitness) - 50) / 200)
              .clamp(0.5, 1.5);
      final chance = (0.03 + (p.fatigue / 100) * 0.05) *
          injuryFactor *
          naturalFitnessFactor;
      if (_rng.nextDouble() < chance) {
        final type = _rollInjuryType(p);
        final range = type.durationRange;
        final weeks =
            (range.$1 + _rng.nextInt(range.$2 - range.$1 + 1)) * injuryFactor;
        p.injuryWeeks = weeks.round().clamp(1, range.$2);
        p.injuryType = type;
        p.injuryHistoryCounts[type.name] =
            (p.injuryHistoryCounts[type.name] ?? 0) + 1;
      }
    }
  }

  /// 負傷の種類を重み付き抽選で決める。同じ種類を過去に負ったことが
  /// あると再発しやすい(重みが増す)。
  static InjuryType _rollInjuryType(Player p) {
    final weights = <InjuryType, double>{
      InjuryType.bruise: 3.0,
      InjuryType.muscle: 2.0,
      InjuryType.ligament: 1.0,
    };
    for (final type in InjuryType.values) {
      final history = p.injuryHistoryCounts[type.name] ?? 0;
      if (history > 0) weights[type] = weights[type]! * (1 + 0.3 * history);
    }
    final total = weights.values.fold<double>(0, (s, w) => s + w);
    var r = _rng.nextDouble() * total;
    for (final entry in weights.entries) {
      if (r < entry.value) return entry.key;
      r -= entry.value;
    }
    return InjuryType.bruise;
  }

  static Player? _pickCardTarget(List<Player> lineup) {
    final candidates =
        lineup.where((p) => p.position.group != PositionGroup.gk).toList();
    if (candidates.isEmpty) return null;
    final weights = candidates
        .map((p) =>
            1 +
            p.attributeValue(AttributeKeys.aggression) ~/ 10 +
            (100 - p.attributeValue(AttributeKeys.composure)) ~/ 25)
        .toList();
    final total = weights.fold<int>(0, (s, w) => s + w);
    if (total <= 0) return candidates[_rng.nextInt(candidates.length)];
    int r = _rng.nextInt(total);
    for (int i = 0; i < candidates.length; i++) {
      if (r < weights[i]) return candidates[i];
      r -= weights[i];
    }
    return candidates.last;
  }

  /// [startMinute]〜[endMinute](両端含む)の区間だけをシミュレートする。
  /// ハーフタイムでの交代・戦術変更を反映できるよう、前半・後半を別々に
  /// 呼び出せるようにするための下位レベルAPI。疲労・負傷はここでは
  /// 適用しない([applyPostMatchEffects]を試合終了後に別途呼ぶこと)。
  static HalfResult simulateMinutes({
    required Team home,
    required Team away,
    required int startMinute,
    required int endMinute,
    Weather weather = Weather.clear,
    double homeAdvantageFactor = 1.06,
  }) {
    final homeLineup = lineupOf(home);
    final awayLineup = lineupOf(away);

    final homeMarkedId = markedTargetId(away, awayLineup, homeLineup);
    final awayMarkedId = markedTargetId(home, homeLineup, awayLineup);

    final homeAttackBase =
        _attackPower(home, homeLineup, suppressedId: homeMarkedId) *
            homeAdvantageFactor *
            weather.attackMultiplier;
    final awayAttackBase =
        _attackPower(away, awayLineup, suppressedId: awayMarkedId) *
            weather.attackMultiplier;
    final homeDefenseBase =
        _defensePower(home, homeLineup) * weather.defenseMultiplier;
    final awayDefenseBase =
        _defensePower(away, awayLineup) * weather.defenseMultiplier;

    final events = <MatchEvent>[];
    int homeGoals = 0;
    int awayGoals = 0;
    final span = endMinute - startMinute + 1;
    final minutesUsed = <int>{};

    // カードイベント(警告・退場)を先に生成し、退場が発生した分数を記録する。
    // ゴールチャンスの評価時にこの分数以降は数的不利として攻守力を下げる。
    int? homeRedMinute;
    int? awayRedMinute;
    final cardChances = ((1 + _rng.nextInt(4)) * span / 90).round().clamp(0, 6);
    for (int i = 0; i < cardChances; i++) {
      final minute = startMinute + _rng.nextInt(span);
      if (minutesUsed.contains(minute)) continue;
      minutesUsed.add(minute);
      final isHomeTeam = _rng.nextBool();
      final lineup = isHomeTeam ? homeLineup : awayLineup;
      final team = isHomeTeam ? home : away;
      // キャプテンが出場しているチームは規律が保たれ、カードをやや受けにくい。
      if (team.captainId != null &&
          lineup.any((p) => p.id == team.captainId) &&
          _rng.nextDouble() < 0.25) {
        continue;
      }
      final target = _pickCardTarget(lineup);
      if (target == null) continue;
      final isRed = _rng.nextDouble() < 0.08;
      events.add(MatchEvent(
        minute: minute,
        teamId: team.id,
        scorerName: target.name,
        scorerId: target.id,
        type: isRed ? MatchEventType.redCard : MatchEventType.yellowCard,
      ));
      if (isRed) {
        if (isHomeTeam) {
          homeRedMinute =
              homeRedMinute == null ? minute : min(homeRedMinute, minute);
        } else {
          awayRedMinute =
              awayRedMinute == null ? minute : min(awayRedMinute, minute);
        }
      }
      // 警告・退場の累積処理は試合終了後にapplyPostMatchEffectsでまとめて行う
      // (出場停止の消化判定より後に反映しないと、今節退場した選手の出場停止が
      // 同じ試合の後処理で即座に解除されてしまうため)。
    }

    // ゴールチャンスは時系列(分)順に評価し、退場による数的不利と
    // 直近の得点による「勢い」を反映する。
    final totalChances =
        ((9 + _rng.nextInt(8)) * span / 90 * weather.chanceCountMultiplier)
            .round()
            .clamp(1, 20);
    final chanceMinutes = <int>[];
    for (int i = 0; i < totalChances; i++) {
      int minute = startMinute;
      var guard = 0;
      do {
        minute = startMinute + _rng.nextInt(span);
        guard++;
      } while (minutesUsed.contains(minute) && guard < 50);
      minutesUsed.add(minute);
      chanceMinutes.add(minute);
    }
    chanceMinutes.sort();

    double homeMomentum = 0;
    double awayMomentum = 0;
    for (final minute in chanceMinutes) {
      final homeRedActive = homeRedMinute != null && minute > homeRedMinute;
      final awayRedActive = awayRedMinute != null && minute > awayRedMinute;
      final homeAttack = homeAttackBase * (homeRedActive ? 0.85 : 1.0);
      final awayAttack = awayAttackBase * (awayRedActive ? 0.85 : 1.0);
      final homeDefense = homeDefenseBase * (homeRedActive ? 0.82 : 1.0);
      final awayDefense = awayDefenseBase * (awayRedActive ? 0.82 : 1.0);

      final homeShare = homeAttack / (homeAttack + awayAttack);
      final isHomeChance = _rng.nextDouble() < homeShare;
      final attackingLineup = isHomeChance ? homeLineup : awayLineup;
      final defendingLineup = isHomeChance ? awayLineup : homeLineup;
      final attackingTeam = isHomeChance ? home : away;
      final defendingTeam = isHomeChance ? away : home;
      final defendingDefense = isHomeChance ? awayDefense : homeDefense;
      final attackingPower = isHomeChance ? homeAttack : awayAttack;
      final momentum = isHomeChance ? homeMomentum : awayMomentum;

      final diff = attackingPower - defendingDefense;
      var scoreProb = (0.30 + diff / 220 + momentum).clamp(0.05, 0.75);
      Player? scorer;
      if (_rng.nextDouble() < 0.25) {
        // セットプレー(PK・直接FK・CK)由来のチャンス。担当に指名された選手が
        // いれば優先的に関わり、専門の能力値でチャンスの質が変わる。
        final subRoll = _rng.nextDouble();
        if (subRoll < 0.15) {
          scorer = _pickSetPieceTaker(
                  attackingTeam.penaltyTakerId, attackingLineup) ??
              _pickScorer(attackingLineup);
          final penaltyAttr =
              scorer?.attributeValue(AttributeKeys.penalties) ?? 50;
          scoreProb = (0.55 + (penaltyAttr - 50) / 200).clamp(0.5, 0.9);
        } else if (subRoll < 0.55) {
          scorer = _pickSetPieceTaker(
                  attackingTeam.freeKickTakerId, attackingLineup) ??
              _pickScorer(attackingLineup);
          final freeKickAttr =
              scorer?.attributeValue(AttributeKeys.freeKick) ?? 50;
          scoreProb = (0.18 + (freeKickAttr - 50) / 300).clamp(0.05, 0.35);
          scoreProb =
              applySetPieceDefense(scoreProb, defendingTeam, defendingLineup);
        } else {
          scorer = _pickScorer(attackingLineup);
          final cornerTaker =
              _pickSetPieceTaker(attackingTeam.cornerTakerId, attackingLineup);
          if (cornerTaker != null) {
            final cornersAttr =
                cornerTaker.attributeValue(AttributeKeys.corners);
            scoreProb =
                (scoreProb * (1 + (cornersAttr - 50) / 200)).clamp(0.05, 0.75);
          }
          scoreProb =
              applySetPieceDefense(scoreProb, defendingTeam, defendingLineup);
        }
      } else {
        scorer = _pickScorer(attackingLineup);
      }
      if (_rng.nextDouble() < scoreProb) {
        events.add(MatchEvent(
            minute: minute,
            teamId: attackingTeam.id,
            scorerName: scorer?.name,
            scorerId: scorer?.id));
        if (isHomeChance) {
          homeGoals++;
          homeMomentum = (homeMomentum + 0.05).clamp(-0.08, 0.08);
          awayMomentum = (awayMomentum - 0.02).clamp(-0.08, 0.08);
        } else {
          awayGoals++;
          awayMomentum = (awayMomentum + 0.05).clamp(-0.08, 0.08);
          homeMomentum = (homeMomentum - 0.02).clamp(-0.08, 0.08);
        }
      } else if (_rng.nextDouble() < 0.45) {
        // 得点には至らなかった惜しいチャンスを実況として記録する。
        final shooter = _pickScorer(attackingLineup);
        events.add(MatchEvent(
            minute: minute,
            teamId: attackingTeam.id,
            scorerName: shooter?.name,
            scorerId: shooter?.id,
            type: MatchEventType.chance));
      }
      homeMomentum *= 0.9;
      awayMomentum *= 0.9;
    }

    events.sort((a, b) => a.minute.compareTo(b.minute));
    return HalfResult(
        homeGoals: homeGoals, awayGoals: awayGoals, events: events);
  }

  /// 相手が守備セットプレー担当を指名して出場させている場合、その選手の
  /// ヘディング・ジャンプ力に応じてセットプレー由来のチャンスの質を下げる。
  static double applySetPieceDefense(
      double scoreProb, Team defendingTeam, List<Player> defendingLineup) {
    final defender =
        _pickSetPieceTaker(defendingTeam.setPieceDefenderId, defendingLineup);
    if (defender == null) return scoreProb;
    final defSkill = (defender.attributeValue(AttributeKeys.heading) +
            defender.attributeValue(AttributeKeys.jumpingReach)) /
        2;
    return (scoreProb * (1 - (defSkill - 50) / 250)).clamp(0.05, 0.9);
  }

  /// 試合終了後に一度だけ呼ぶ、疲労蓄積・負傷判定・出場停止の消化と新規カードの反映。
  /// [events]はこの試合(前後半通し)で発生した全イベント。
  static void applyPostMatchEffects({
    required Team home,
    required Team away,
    double homeInjuryFactor = 1.0,
    double awayInjuryFactor = 1.0,
    List<MatchEvent> events = const [],
    Weather weather = Weather.clear,
  }) {
    final homeLineup = lineupOf(home);
    final awayLineup = lineupOf(away);
    // 前半分の疲労は既にapplyHalfTimeFatigueで反映済みのため、ここでは
    // 後半分(intensity 0.5)のみを加算する。
    _applyFatigue(home, homeLineup,
        weatherFactor: weather.fatigueMultiplier, intensity: 0.5);
    _applyFatigue(away, awayLineup,
        weatherFactor: weather.fatigueMultiplier, intensity: 0.5);
    _rollInjuries(homeLineup, homeInjuryFactor);
    _rollInjuries(awayLineup, awayInjuryFactor);
    _growPositionFamiliarity(home, homeLineup);
    _growPositionFamiliarity(away, awayLineup);
    _updateMatchSharpness(home, homeLineup);
    _updateMatchSharpness(away, awayLineup);
    for (final p in [...homeLineup, ...awayLineup]) {
      TrainingEngine.growFromMatchExperience(p);
    }
    // 出場停止の消化は既存の出場停止(前節以前に受けたもの)にのみ適用し、
    // その後で今節に新たに受けたカードを反映する。
    _advanceSuspensions(home, homeLineup);
    _advanceSuspensions(away, awayLineup);
    _applyCardAccumulation(home, away, events);
    _applyCareerStats(homeLineup, awayLineup, events);
  }

  /// 出場選手の通算出場数・通算得点数を加算する(親善試合はこの関数を
  /// 呼ばないため対象外)。
  static void _applyCareerStats(List<Player> homeLineup,
      List<Player> awayLineup, List<MatchEvent> events) {
    final lineupIds = <String, Player>{
      for (final p in [...homeLineup, ...awayLineup]) p.id: p,
    };
    for (final p in lineupIds.values) {
      p.careerAppearances += 1;
    }
    for (final e in events) {
      if (e.type != MatchEventType.goal) continue;
      lineupIds[e.scorerId]?.careerGoals += 1;
    }
  }

  /// 出場停止選手のうち、今節の対象外だった(実際に1試合を消化した)選手だけ
  /// 出場停止試合数を1減らす。今節新たに出場停止となった選手(今節は出場して
  /// カードを受けた側)は対象外で、次節から出場停止が適用される。
  static void _advanceSuspensions(Team t, List<Player> lineup) {
    final lineupIds = lineup.map((p) => p.id).toSet();
    for (final p in t.players) {
      if (p.suspendedMatches > 0 && !lineupIds.contains(p.id)) {
        p.suspendedMatches -= 1;
      }
    }
  }

  /// 今節発生した警告・退場イベントを選手の累積数に反映する。
  static void _applyCardAccumulation(
      Team home, Team away, List<MatchEvent> events) {
    final byId = {
      for (final p in [...home.players, ...away.players]) p.id: p,
    };
    for (final e in events) {
      if (e.type != MatchEventType.yellowCard &&
          e.type != MatchEventType.redCard) {
        continue;
      }
      final target = byId[e.scorerId];
      if (target == null) continue;
      if (e.type == MatchEventType.redCard) {
        target.suspendedMatches += 1;
      } else {
        target.yellowCards += 1;
        if (target.yellowCards >= yellowCardSuspensionThreshold) {
          target.yellowCards = 0;
          target.suspendedMatches += 1;
        }
      }
    }
  }

  /// 出場した選手の試合内採点(1.0〜10.0)を算出する。基準点6.0から、得点・
  /// 決定機創出でプラス、警告・退場でマイナス、所属チームの勝敗で補正する。
  static Map<String, double> computePlayerRatings({
    required Team home,
    required Team away,
    required List<MatchEvent> events,
    required int homeGoals,
    required int awayGoals,
  }) {
    final homeLineup = lineupOf(home);
    final awayLineup = lineupOf(away);
    final ratings = <String, double>{};
    for (final p in [...homeLineup, ...awayLineup]) {
      ratings[p.id] = 6.0;
    }

    for (final e in events) {
      final id = e.scorerId;
      if (id == null || !ratings.containsKey(id)) continue;
      switch (e.type) {
        case MatchEventType.goal:
          ratings[id] = ratings[id]! + 1.0;
          break;
        case MatchEventType.chance:
          ratings[id] = ratings[id]! + 0.3;
          break;
        case MatchEventType.yellowCard:
          ratings[id] = ratings[id]! - 0.5;
          break;
        case MatchEventType.redCard:
          ratings[id] = ratings[id]! - 1.5;
          break;
      }
    }

    final resultBonus = homeGoals > awayGoals
        ? 0.4
        : homeGoals < awayGoals
            ? -0.4
            : 0.0;
    for (final p in homeLineup) {
      ratings[p.id] = ratings[p.id]! + resultBonus;
    }
    for (final p in awayLineup) {
      ratings[p.id] = ratings[p.id]! - resultBonus;
    }

    return ratings
        .map((id, r) => MapEntry(id, (r.clamp(1.0, 10.0) * 2).round() / 2));
  }

  /// 前半・後半をまとめて一括シミュレートする(CPU同士の試合・カップ戦など、
  /// ハーフタイム操作が不要な場合に使う)。
  static MatchResult simulate({
    required Team home,
    required Team away,
    required int matchday,
    double homeInjuryFactor = 1.0,
    double awayInjuryFactor = 1.0,
    Weather weather = Weather.clear,
    double homeAdvantageFactor = 1.06,
  }) {
    final first = simulateMinutes(
        home: home,
        away: away,
        startMinute: 1,
        endMinute: 45,
        weather: weather,
        homeAdvantageFactor: homeAdvantageFactor);
    applyHalfTimeFatigue(home: home, away: away, weather: weather);
    final second = simulateMinutes(
        home: home,
        away: away,
        startMinute: 46,
        endMinute: 90,
        weather: weather,
        homeAdvantageFactor: homeAdvantageFactor);
    final allEvents = [...first.events, ...second.events];
    final homeGoals = first.homeGoals + second.homeGoals;
    final awayGoals = first.awayGoals + second.awayGoals;
    // 採点は今節の出場停止・負傷が反映される前(=今節の出場者がまだ
    // lineupOfに残っている状態)で算出する必要があるため、
    // applyPostMatchEffectsより先に計算する。
    final ratings = computePlayerRatings(
      home: home,
      away: away,
      events: allEvents,
      homeGoals: homeGoals,
      awayGoals: awayGoals,
    );
    applyPostMatchEffects(
      home: home,
      away: away,
      homeInjuryFactor: homeInjuryFactor,
      awayInjuryFactor: awayInjuryFactor,
      events: allEvents,
      weather: weather,
    );

    return MatchResult(
      matchday: matchday,
      homeTeamId: home.id,
      awayTeamId: away.id,
      homeGoals: homeGoals,
      awayGoals: awayGoals,
      events: allEvents,
      playerRatings: ratings,
      weather: weather,
    );
  }
}
