import 'dart:math';
import '../models/player.dart';
import '../models/team.dart';
import '../models/match_result.dart';

class MatchEngine {
  static final Random _rng = Random();

  static double _condition(Player p) => (1 - p.fatigue / 250) * (0.85 + p.morale / 500);

  static double _attackPower(Team t) {
    final relevant =
        t.players.where((p) => p.position == Position.fw || p.position == Position.mf).toList();
    if (relevant.isEmpty) return 50;
    final total = relevant.fold<double>(0, (s, p) => s + p.attack * _condition(p));
    return total / relevant.length;
  }

  static double _defensePower(Team t) {
    final relevant =
        t.players.where((p) => p.position == Position.df || p.position == Position.gk).toList();
    if (relevant.isEmpty) return 50;
    final total = relevant.fold<double>(0, (s, p) => s + p.defense * _condition(p));
    return total / relevant.length;
  }

  static Player? _pickScorer(Team t) {
    final candidates =
        t.players.where((p) => p.position == Position.fw || p.position == Position.mf).toList();
    if (candidates.isEmpty) return t.players.isNotEmpty ? t.players.first : null;
    final total = candidates.fold<int>(0, (s, p) => s + p.attack);
    if (total <= 0) return candidates[_rng.nextInt(candidates.length)];
    int r = _rng.nextInt(total);
    for (final p in candidates) {
      if (r < p.attack) return p;
      r -= p.attack;
    }
    return candidates.last;
  }

  static MatchResult simulate({required Team home, required Team away, required int matchday}) {
    final homeAttack = _attackPower(home) * 1.06;
    final awayAttack = _attackPower(away);
    final homeDefense = _defensePower(home);
    final awayDefense = _defensePower(away);

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
      final attackingTeam = isHomeChance ? home : away;
      final defendingDefense = isHomeChance ? awayDefense : homeDefense;
      final attackingPower = isHomeChance ? homeAttack : awayAttack;

      final diff = attackingPower - defendingDefense;
      final scoreProb = (0.30 + diff / 220).clamp(0.08, 0.65);
      if (_rng.nextDouble() < scoreProb) {
        final scorer = _pickScorer(attackingTeam);
        events.add(MatchEvent(minute: minute, teamId: attackingTeam.id, scorerName: scorer?.name));
        if (isHomeChance) {
          homeGoals++;
        } else {
          awayGoals++;
        }
      }
    }
    events.sort((a, b) => a.minute.compareTo(b.minute));

    for (final p in [...home.players, ...away.players]) {
      p.fatigue = (p.fatigue + 12 + _rng.nextInt(8)).clamp(0, 100);
    }

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
