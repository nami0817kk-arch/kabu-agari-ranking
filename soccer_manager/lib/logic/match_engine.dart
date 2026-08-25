import 'dart:math';
import '../models/attributes.dart';
import '../models/formation.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../models/match_result.dart';

/// 分単位区間([MatchEngine.simulateMinutes])1回分のスコア・イベント。
class HalfResult {
  final int homeGoals;
  final int awayGoals;
  final List<MatchEvent> events;

  const HalfResult({required this.homeGoals, required this.awayGoals, required this.events});
}

class MatchEngine {
  static final Random _rng = Random();

  static double _condition(Player p) => (1 - p.fatigue / 250) * (0.85 + p.morale / 500);

  /// 先発11人を解決する。未設定・不整合な場合は負傷者を除いた総合力上位11人で代用する。
  static List<Player> lineupOf(Team t) {
    if (t.startingXI.isNotEmpty) {
      final byId = {for (final p in t.players) p.id: p};
      final lineup = t.startingXI
          .map((id) => byId[id])
          .whereType<Player>()
          .where((p) => !p.isInjured && !p.isOnInternationalDuty && !p.isLoanedOut)
          .toList();
      if (lineup.length >= 7) return lineup;
    }
    final available =
        t.players.where((p) => !p.isInjured && !p.isOnInternationalDuty && !p.isLoanedOut).toList()
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
        .where((p) => p.position.group == PositionGroup.att || p.position.group == PositionGroup.mid)
        .toList();
    if (relevant.isEmpty) return 40;
    final total = relevant.fold<double>(
      0,
      (s, p) => s + p.attack * _condition(p) * _dutyAttackMultiplier(p.duty),
    );
    final lineFactor = 1 + (t.lineHeight - 50) / 400;
    final widthFactor = 1 + (t.width - 50) / 500;
    final tempoFactor = 1 + (t.tempo - 50) / 500;
    return (total / relevant.length) * t.formation.attackBias * lineFactor * widthFactor * tempoFactor;
  }

  static double _defensePower(Team t, List<Player> lineup) {
    final relevant = lineup
        .where((p) => p.position.group == PositionGroup.def || p.position.group == PositionGroup.gk)
        .toList();
    if (relevant.isEmpty) return 40;
    final total = relevant.fold<double>(
      0,
      (s, p) => s + p.defense * _condition(p) * _dutyDefenseMultiplier(p.duty),
    );
    final pressFactor = 1 + (t.pressing - 50) / 400;
    final lineRiskFactor = 1 + (50 - t.lineHeight) / 500;
    final widthRiskFactor = 1 - (t.width - 50) / 800;
    return (total / relevant.length) * t.formation.defenseBias * pressFactor * lineRiskFactor * widthRiskFactor;
  }

  static Player? _pickScorer(List<Player> lineup) {
    final candidates = lineup
        .where((p) => p.position.group == PositionGroup.att || p.position.group == PositionGroup.mid)
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
      final gain = (12 + _rng.nextInt(8)) * pressFatigueFactor * tempoFatigueFactor;
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

    final totalChances = ((9 + _rng.nextInt(8)) * span / 90).round().clamp(1, 20);
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
        events.add(MatchEvent(minute: minute, teamId: attackingTeam.id, scorerName: scorer?.name, scorerId: scorer?.id));
        if (isHomeChance) {
          homeGoals++;
        } else {
          awayGoals++;
        }
      } else if (_rng.nextDouble() < 0.45) {
        // 得点には至らなかった惜しいチャンスを実況として記録する。
        final shooter = _pickScorer(attackingLineup);
        events.add(MatchEvent(minute: minute, teamId: attackingTeam.id, scorerName: shooter?.name, type: MatchEventType.chance));
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
        type: isRed ? MatchEventType.redCard : MatchEventType.yellowCard,
      ));
    }

    events.sort((a, b) => a.minute.compareTo(b.minute));
    return HalfResult(homeGoals: homeGoals, awayGoals: awayGoals, events: events);
  }

  /// 試合終了後に一度だけ呼ぶ、疲労蓄積・負傷判定。
  static void applyPostMatchEffects({
    required Team home,
    required Team away,
    double homeInjuryFactor = 1.0,
    double awayInjuryFactor = 1.0,
  }) {
    final homeLineup = lineupOf(home);
    final awayLineup = lineupOf(away);
    _applyFatigue(home, homeLineup);
    _applyFatigue(away, awayLineup);
    _rollInjuries(homeLineup, homeInjuryFactor);
    _rollInjuries(awayLineup, awayInjuryFactor);
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
    final first = simulateMinutes(home: home, away: away, startMinute: 1, endMinute: 45);
    final second = simulateMinutes(home: home, away: away, startMinute: 46, endMinute: 90);
    applyPostMatchEffects(
      home: home,
      away: away,
      homeInjuryFactor: homeInjuryFactor,
      awayInjuryFactor: awayInjuryFactor,
    );

    return MatchResult(
      matchday: matchday,
      homeTeamId: home.id,
      awayTeamId: away.id,
      homeGoals: first.homeGoals + second.homeGoals,
      awayGoals: first.awayGoals + second.awayGoals,
      events: [...first.events, ...second.events],
    );
  }
}
