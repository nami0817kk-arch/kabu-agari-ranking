import 'dart:math';
import '../models/attributes.dart';
import '../models/formation.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../models/match_result.dart';

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
      (1 - p.fatigue / 250) * (0.85 + p.morale / 500);

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

  static double _attackPower(Team t, List<Player> lineup) {
    final relevant = lineup
        .where((p) =>
            p.position.group == PositionGroup.att ||
            p.position.group == PositionGroup.mid)
        .toList();
    if (relevant.isEmpty) return 40;
    final total = relevant.fold<double>(
      0,
      (s, p) => s + p.attack * _condition(p) * _dutyAttackMultiplier(p.duty),
    );
    final lineFactor = 1 + (t.lineHeight - 50) / 400;
    final widthFactor = 1 + (t.width - 50) / 500;
    final tempoFactor = 1 + (t.tempo - 50) / 500;
    return (total / relevant.length) *
        t.formation.attackBias *
        lineFactor *
        widthFactor *
        tempoFactor;
  }

  static double _defensePower(Team t, List<Player> lineup) {
    final relevant = lineup
        .where((p) =>
            p.position.group == PositionGroup.def ||
            p.position.group == PositionGroup.gk)
        .toList();
    if (relevant.isEmpty) return 40;
    final total = relevant.fold<double>(
      0,
      (s, p) => s + p.defense * _condition(p) * _dutyDefenseMultiplier(p.duty),
    );
    final pressFactor = 1 + (t.pressing - 50) / 400;
    final lineRiskFactor = 1 + (50 - t.lineHeight) / 500;
    final widthRiskFactor = 1 - (t.width - 50) / 800;
    return (total / relevant.length) *
        t.formation.defenseBias *
        pressFactor *
        lineRiskFactor *
        widthRiskFactor;
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

  static void _applyFatigue(Team t, List<Player> lineup) {
    final pressFatigueFactor = 1 + (t.pressing - 50) / 200;
    final tempoFatigueFactor = 1 + (t.tempo - 50) / 300;
    for (final p in lineup) {
      final gain =
          (12 + _rng.nextInt(8)) * pressFatigueFactor * tempoFatigueFactor;
      p.fatigue = (p.fatigue + gain.round()).clamp(0, 100);
    }
  }

  static void _rollInjuries(List<Player> lineup, double injuryFactor) {
    for (final p in lineup) {
      final chance = (0.03 + (p.fatigue / 100) * 0.05) * injuryFactor;
      if (_rng.nextDouble() < chance) {
        final weeks = (1 + _rng.nextInt(4)) * injuryFactor;
        p.injuryWeeks = weeks.round().clamp(1, 8);
      }
    }
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
  }) {
    final homeLineup = lineupOf(home);
    final awayLineup = lineupOf(away);

    final homeAttack = _attackPower(home, homeLineup) * 1.06;
    final awayAttack = _attackPower(away, awayLineup);
    final homeDefense = _defensePower(home, homeLineup);
    final awayDefense = _defensePower(away, awayLineup);

    final events = <MatchEvent>[];
    int homeGoals = 0;
    int awayGoals = 0;
    final span = endMinute - startMinute + 1;

    final totalChances =
        ((9 + _rng.nextInt(8)) * span / 90).round().clamp(1, 20);
    final minutesUsed = <int>{};
    for (int i = 0; i < totalChances; i++) {
      int minute = startMinute;
      var guard = 0;
      do {
        minute = startMinute + _rng.nextInt(span);
        guard++;
      } while (minutesUsed.contains(minute) && guard < 50);
      minutesUsed.add(minute);

      final homeShare = homeAttack / (homeAttack + awayAttack);
      final isHomeChance = _rng.nextDouble() < homeShare;
      final attackingLineup = isHomeChance ? homeLineup : awayLineup;
      final attackingTeam = isHomeChance ? home : away;
      final defendingDefense = isHomeChance ? awayDefense : homeDefense;
      final attackingPower = isHomeChance ? homeAttack : awayAttack;

      final diff = attackingPower - defendingDefense;
      final scoreProb = (0.30 + diff / 220).clamp(0.08, 0.65);
      if (_rng.nextDouble() < scoreProb) {
        final scorer = _pickScorer(attackingLineup);
        events.add(MatchEvent(
            minute: minute,
            teamId: attackingTeam.id,
            scorerName: scorer?.name,
            scorerId: scorer?.id));
        if (isHomeChance) {
          homeGoals++;
        } else {
          awayGoals++;
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
    }

    // カードイベント(警告・退場)を疑似的に生成する。
    final cardChances = ((1 + _rng.nextInt(4)) * span / 90).round().clamp(0, 6);
    for (int i = 0; i < cardChances; i++) {
      final minute = startMinute + _rng.nextInt(span);
      if (minutesUsed.contains(minute)) continue;
      minutesUsed.add(minute);
      final isHomeTeam = _rng.nextBool();
      final lineup = isHomeTeam ? homeLineup : awayLineup;
      final team = isHomeTeam ? home : away;
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
      // 警告・退場の累積処理は試合終了後にapplyPostMatchEffectsでまとめて行う
      // (出場停止の消化判定より後に反映しないと、今節退場した選手の出場停止が
      // 同じ試合の後処理で即座に解除されてしまうため)。
    }

    events.sort((a, b) => a.minute.compareTo(b.minute));
    return HalfResult(
        homeGoals: homeGoals, awayGoals: awayGoals, events: events);
  }

  /// 試合終了後に一度だけ呼ぶ、疲労蓄積・負傷判定・出場停止の消化と新規カードの反映。
  /// [events]はこの試合(前後半通し)で発生した全イベント。
  static void applyPostMatchEffects({
    required Team home,
    required Team away,
    double homeInjuryFactor = 1.0,
    double awayInjuryFactor = 1.0,
    List<MatchEvent> events = const [],
  }) {
    final homeLineup = lineupOf(home);
    final awayLineup = lineupOf(away);
    _applyFatigue(home, homeLineup);
    _applyFatigue(away, awayLineup);
    _rollInjuries(homeLineup, homeInjuryFactor);
    _rollInjuries(awayLineup, awayInjuryFactor);
    // 出場停止の消化は既存の出場停止(前節以前に受けたもの)にのみ適用し、
    // その後で今節に新たに受けたカードを反映する。
    _advanceSuspensions(home, homeLineup);
    _advanceSuspensions(away, awayLineup);
    _applyCardAccumulation(home, away, events);
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
  }) {
    final first =
        simulateMinutes(home: home, away: away, startMinute: 1, endMinute: 45);
    final second =
        simulateMinutes(home: home, away: away, startMinute: 46, endMinute: 90);
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
    );

    return MatchResult(
      matchday: matchday,
      homeTeamId: home.id,
      awayTeamId: away.id,
      homeGoals: homeGoals,
      awayGoals: awayGoals,
      events: allEvents,
      playerRatings: ratings,
    );
  }
}
