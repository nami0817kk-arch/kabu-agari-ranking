import 'enum_json.dart';
import 'weather.dart';

enum MatchEventType { goal, chance, yellowCard, redCard }

class MatchEvent {
  final int minute;
  final String teamId;

  /// 得点者・警告/退場対象者・チャンスを迎えた選手名など、イベント種別に応じた選手名。
  final String? scorerName;

  /// scorerNameに対応する選手ID(得点イベントの場合、シーズン集計に使う)。
  final String? scorerId;
  final MatchEventType type;

  MatchEvent({
    required this.minute,
    required this.teamId,
    this.scorerName,
    this.scorerId,
    this.type = MatchEventType.goal,
  });

  Map<String, dynamic> toJson() => {
        'minute': minute,
        'teamId': teamId,
        'scorerName': scorerName,
        'scorerId': scorerId,
        'type': type.name,
      };

  factory MatchEvent.fromJson(Map<String, dynamic> json) => MatchEvent(
        minute: json['minute'] as int,
        teamId: json['teamId'] as String,
        scorerName: json['scorerName'] as String?,
        scorerId: json['scorerId'] as String?,
        type: enumFromName(MatchEventType.values, json['type'] as String?,
            MatchEventType.goal),
      );
}

class MatchResult {
  final int matchday;
  final String homeTeamId;
  final String awayTeamId;
  final int homeGoals;
  final int awayGoals;
  final List<MatchEvent> events;

  /// 出場した選手の試合内採点(1.0〜10.0)。選手ID→採点。
  final Map<String, double> playerRatings;

  /// この試合の天候。
  final Weather weather;

  MatchResult({
    required this.matchday,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.homeGoals,
    required this.awayGoals,
    required this.events,
    Map<String, double>? playerRatings,
    this.weather = Weather.clear,
  }) : playerRatings = playerRatings ?? {};

  /// この試合の最優秀選手(採点が最も高い選手)のID。採点データがなければnull。
  String? get manOfTheMatchId {
    if (playerRatings.isEmpty) return null;
    return playerRatings.entries
        .reduce((a, b) => b.value > a.value ? b : a)
        .key;
  }

  Map<String, dynamic> toJson() => {
        'matchday': matchday,
        'homeTeamId': homeTeamId,
        'awayTeamId': awayTeamId,
        'homeGoals': homeGoals,
        'awayGoals': awayGoals,
        'events': events.map((e) => e.toJson()).toList(),
        'playerRatings': playerRatings,
        'weather': weather.name,
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
        playerRatings: (json['playerRatings'] as Map?)?.map(
              (k, v) => MapEntry(k as String, (v as num).toDouble()),
            ) ??
            {},
        weather: enumFromName(
            Weather.values, json['weather'] as String?, Weather.clear),
      );
}
