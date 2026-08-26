import 'team.dart';
import 'match_result.dart';
import 'weather.dart';

class Fixture {
  final int matchday;
  final String homeTeamId;
  final String awayTeamId;
  MatchResult? result;

  /// この試合の天候。試合開始時に決定される(未開催の場合はnull)。
  Weather? weather;

  Fixture({
    required this.matchday,
    required this.homeTeamId,
    required this.awayTeamId,
    this.result,
    this.weather,
  });

  Map<String, dynamic> toJson() => {
        'matchday': matchday,
        'homeTeamId': homeTeamId,
        'awayTeamId': awayTeamId,
        'result': result?.toJson(),
        'weather': weather?.name,
      };

  factory Fixture.fromJson(Map<String, dynamic> json) => Fixture(
        matchday: json['matchday'] as int,
        homeTeamId: json['homeTeamId'] as String,
        awayTeamId: json['awayTeamId'] as String,
        result: json['result'] == null
            ? null
            : MatchResult.fromJson(json['result'] as Map<String, dynamic>),
        weather: json['weather'] == null
            ? null
            : Weather.values.byName(json['weather'] as String),
      );
}

class StandingRow {
  final String teamId;
  int played = 0;
  int won = 0;
  int draw = 0;
  int lost = 0;
  int goalsFor = 0;
  int goalsAgainst = 0;

  StandingRow({required this.teamId});

  int get points => won * 3 + draw;
  int get goalDiff => goalsFor - goalsAgainst;
}

class League {
  List<Team> teams;
  List<Fixture> fixtures;
  int season;

  League({required this.teams, required this.fixtures, this.season = 1});

  Fixture? get nextUnplayedFixture {
    final unplayed = fixtures.where((f) => f.result == null).toList();
    if (unplayed.isEmpty) return null;
    unplayed.sort((a, b) => a.matchday.compareTo(b.matchday));
    return unplayed.first;
  }

  bool get isSeasonComplete => fixtures.every((f) => f.result != null);

  /// 指定チームが直近にプレーした(結果が確定している)試合を返す。まだ1試合も
  /// 消化していない場合はnull。
  Fixture? lastPlayedFixtureFor(String teamId) {
    final played = fixtures
        .where((f) =>
            f.result != null &&
            (f.homeTeamId == teamId || f.awayTeamId == teamId))
        .toList();
    if (played.isEmpty) return null;
    played.sort((a, b) => b.matchday.compareTo(a.matchday));
    return played.first;
  }

  List<Fixture> fixturesForMatchday(int md) =>
      fixtures.where((f) => f.matchday == md).toList();

  Map<String, StandingRow> computeStandings() {
    final map = {for (final t in teams) t.id: StandingRow(teamId: t.id)};
    for (final f in fixtures) {
      final r = f.result;
      if (r == null) continue;
      final home = map[f.homeTeamId]!;
      final away = map[f.awayTeamId]!;
      home.played++;
      away.played++;
      home.goalsFor += r.homeGoals;
      home.goalsAgainst += r.awayGoals;
      away.goalsFor += r.awayGoals;
      away.goalsAgainst += r.homeGoals;
      if (r.homeGoals > r.awayGoals) {
        home.won++;
        away.lost++;
      } else if (r.homeGoals < r.awayGoals) {
        away.won++;
        home.lost++;
      } else {
        home.draw++;
        away.draw++;
      }
    }
    return map;
  }

  List<StandingRow> get sortedStandings {
    final rows = computeStandings().values.toList();
    rows.sort((a, b) {
      final p = b.points.compareTo(a.points);
      if (p != 0) return p;
      final gd = b.goalDiff.compareTo(a.goalDiff);
      if (gd != 0) return gd;
      return b.goalsFor.compareTo(a.goalsFor);
    });
    return rows;
  }

  Map<String, dynamic> toJson() => {
        'teams': teams.map((t) => t.toJson()).toList(),
        'fixtures': fixtures.map((f) => f.toJson()).toList(),
        'season': season,
      };

  factory League.fromJson(Map<String, dynamic> json) => League(
        teams: (json['teams'] as List)
            .map((e) => Team.fromJson(e as Map<String, dynamic>))
            .toList(),
        fixtures: (json['fixtures'] as List)
            .map((e) => Fixture.fromJson(e as Map<String, dynamic>))
            .toList(),
        season: json['season'] as int? ?? 1,
      );
}
