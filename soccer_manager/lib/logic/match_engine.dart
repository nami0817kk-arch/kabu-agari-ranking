import 'dart:math';
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
    final relevant =
        lineup.where((p) => p.position == Position.fw || p.position == Position.mf).toList();
    if (relevant.isEmpty) return 40;
    final total = relevant.fold<double>(0, (s, p) => s + p.attack * _condition(p));
    return (total / relevant.length) * t.formation.attackBias;
  }

  static double _defensePower(Team t, List<Player> lineup) {
    final relevant =
        lineup.where((p) => p.position == Position.df || p.position == Position.gk).toList();
    if (relevant.isEmpty) return 40;
    final total = relevant.fold<double>(0, (s, p) => s + p.defense * _condition(p));
    return (total / relevant.length) * t.formation.defenseBias;
  }

  static Player? _pickScorer(List<Player> lineup) {
    final candidates =
        lineup.where((p) => p.position == Position.fw || p.position == Position.mf).toList();
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

  static void _rollInjuries(List<Player> lineup) {
    for (final p in lineup) {
      final chance = 0.03 + (p.fatigue / 100) * 0.05;
      if (_rng.nextDouble() < chance) {
        p.injuryWeeks = 1 + _rng.nextInt(4);
      }
    }
  }

  static MatchResult simulate({required Team home, required Team away, required int matchday}) {
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
      }
    }
    events.sort((a, b) => a.minute.compareTo(b.minute));

    for (final p in [...homeLineup, ...awayLineup]) {
      p.fatigue = (p.fatigue + 12 + _rng.nextInt(8)).clamp(0, 100);
    }
    _rollInjuries(homeLineup);
    _rollInjuries(awayLineup);

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
