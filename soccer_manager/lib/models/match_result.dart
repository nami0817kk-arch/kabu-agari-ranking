enum MatchEventType { goal, chance, yellowCard, redCard }

class MatchEvent {
  final int minute;
  final String teamId;

  /// 得点者・警告/退場対象者・チャンスを迎えた選手名など、イベント種別に応じた選手名。
  final String? scorerName;
  final MatchEventType type;

  MatchEvent({
    required this.minute,
    required this.teamId,
    this.scorerName,
    this.type = MatchEventType.goal,
  });

  Map<String, dynamic> toJson() => {
        'minute': minute,
        'teamId': teamId,
        'scorerName': scorerName,
        'type': type.name,
      };

  factory MatchEvent.fromJson(Map<String, dynamic> json) => MatchEvent(
        minute: json['minute'] as int,
        teamId: json['teamId'] as String,
        scorerName: json['scorerName'] as String?,
        type: MatchEventType.values.byName(json['type'] as String? ?? 'goal'),
      );
}

class MatchResult {
  final int matchday;
  final String homeTeamId;
  final String awayTeamId;
  final int homeGoals;
  final int awayGoals;
  final List<MatchEvent> events;

  MatchResult({
    required this.matchday,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.homeGoals,
    required this.awayGoals,
    required this.events,
  });

  Map<String, dynamic> toJson() => {
        'matchday': matchday,
        'homeTeamId': homeTeamId,
        'awayTeamId': awayTeamId,
        'homeGoals': homeGoals,
        'awayGoals': awayGoals,
        'events': events.map((e) => e.toJson()).toList(),
      };

  factory MatchResult.fromJson(Map<String, dynamic> json) => MatchResult(
        matchday: json['matchday'] as int,
        homeTeamId: json['homeTeamId'] as String,
        awayTeamId: json['awayTeamId'] as String,
        homeGoals: json['homeGoals'] as int,
        awayGoals: json['awayGoals'] as int,
        events: (json['events'] as List)
            .map((e) => MatchEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
