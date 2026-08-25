import 'dart:math';
import '../models/attributes.dart';
import '../models/formation.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../models/match_result.dart';

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
          .where((p) => !p.isInjured)
          .toList();
      if (lineup.length >= 7) return lineup;
    }
    final available = t.players.where((p) => !p.isInjured).toList()
      ..sort((a, b) => b.overall.compareTo(a.overall));
    return available.take(11).toList();
  }

  static double _attackPower(Team t, List<Player> lineup) {
    final relevant = lineup
        .where((p) => p.position.group == PositionGroup.att || p.position.group == PositionGroup.mid)
        .toList();
    if (relevant.isEmpty) return 40;
    final total = relevant.fold<double>(0, (s, p) => s + p.attack * _condition(p));
    final lineFactor = 1 + (t.lineHeight - 50) / 400;
    return (total / relevant.length) * t.formation.attackBias * lineFactor;
  }

  static double _defensePower(Team t, List<Player> lineup) {
    final relevant = lineup
        .where((p) => p.position.group == PositionGroup.def || p.position.group == PositionGroup.gk)
        .toList();
    if (relevant.isEmpty) return 40;
    final total = relevant.fold<double>(0, (s, p) => s + p.defense * _condition(p));
    final pressFactor = 1 + (t.pressing - 50) / 400;
    final lineRiskFactor = 1 + (50 - t.lineHeight) / 500;
    return (total / relevant.length) * t.formation.defenseBias * pressFactor * lineRiskFactor;
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
    for (final p in lineup) {
      final gain = (12 + _rng.nextInt(8)) * pressFatigueFactor;
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

  static MatchResult simulate({
    required Team home,
    required Team away,
    required int matchday,
    double homeInjuryFactor = 1.0,
    double awayInjuryFactor = 1.0,
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

    final totalChances = 9 + _rng.nextInt(8);
    final minutesUsed = <int>{};
    for (int i = 0; i < totalChances; i++) {
      int minute;
      do {
        minute = 1 + _rng.nextInt(90);
      } while (minutesUsed.contains(minute));
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
        events.add(MatchEvent(minute: minute, teamId: attackingTeam.id, scorerName: scorer?.name));
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
    final cardChances = 1 + _rng.nextInt(4);
    for (int i = 0; i < cardChances; i++) {
      final minute = 1 + _rng.nextInt(90);
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

    _applyFatigue(home, homeLineup);
    _applyFatigue(away, awayLineup);
    _rollInjuries(homeLineup, homeInjuryFactor);
    _rollInjuries(awayLineup, awayInjuryFactor);

    return MatchResult(
      matchday: matchday,
      homeTeamId: home.id,
      awayTeamId: away.id,
      homeGoals: homeGoals,
      awayGoals: awayGoals,
      events: events,
    );
  }
}
