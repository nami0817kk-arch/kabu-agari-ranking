import '../models/league.dart';

/// カレンダー表示用の1日分の情報。
class CalendarDayInfo {
  final DateTime date;
  final bool isLeagueMatchDay;
  final bool isHomeMatch;
  final String? opponentName;
  final int? matchday;
  final bool isTrainingFocusDay;
  final bool isToday;

  const CalendarDayInfo({
    required this.date,
    this.isLeagueMatchDay = false,
    this.isHomeMatch = false,
    this.opponentName,
    this.matchday,
    this.isTrainingFocusDay = false,
    this.isToday = false,
  });
}

/// シーズン内の節・親善試合に実際の暦日を与え、カレンダー画面向けに
/// 日ごとの予定(試合日/重点練習日)を計算する。ゲームは節(週)単位で
/// 進行するため、この日付はあくまで表示用であり、セーブデータへの
/// 永続化は不要(シーズン番号から常に同じ日付を再計算できる)。
class CalendarEngine {
  /// 指定シーズンの開幕節(第1節)の実日付。常に土曜日になるよう調整する。
  static DateTime seasonAnchor(int season) {
    final d = DateTime(2024 + (season - 1), 8, 1);
    final diff = (DateTime.saturday - d.weekday) % 7;
    return d.add(Duration(days: diff));
  }

  /// 指定シーズン・節の実日付(常に土曜日)。
  static DateTime dateForMatchday(int season, int matchday) =>
      seasonAnchor(season).add(Duration(days: (matchday - 1) * 7));

  /// プレシーズン親善試合の推定日付。開幕の週から遡って1週間隔で並べる。
  static DateTime dateForFriendly(int season, int index, int count) =>
      seasonAnchor(season).subtract(Duration(days: (count - index) * 7));

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static const _weekdayLabels = ['月', '火', '水', '木', '金', '土', '日'];

  /// DateTime.weekday(1=月〜7=日)に対応する日本語の曜日1文字。
  static String weekdayLabel(int weekday) => _weekdayLabels[weekday - 1];

  /// [from]〜[to](両端含む)の各日について、自クラブのリーグ戦がある日は
  /// 対戦相手情報を、それ以外は重点練習日かどうかを付与して返す。
  static List<CalendarDayInfo> buildRange({
    required DateTime from,
    required DateTime to,
    required League league,
    required String userTeamId,
    required int trainingDayOfWeek,
    required DateTime today,
  }) {
    final matchesByDate = <DateTime, Fixture>{};
    for (final f in league.fixtures) {
      if (f.homeTeamId != userTeamId && f.awayTeamId != userTeamId) continue;
      matchesByDate[dateOnly(dateForMatchday(league.season, f.matchday))] = f;
    }

    final days = <CalendarDayInfo>[];
    var cursor = dateOnly(from);
    final end = dateOnly(to);
    final todayOnly = dateOnly(today);
    while (!cursor.isAfter(end)) {
      final fixture = matchesByDate[cursor];
      final isToday = cursor == todayOnly;
      if (fixture != null) {
        final isHome = fixture.homeTeamId == userTeamId;
        final opponentId = isHome ? fixture.awayTeamId : fixture.homeTeamId;
        String? opponentName;
        for (final t in league.teams) {
          if (t.id == opponentId) {
            opponentName = t.name;
            break;
          }
        }
        days.add(CalendarDayInfo(
          date: cursor,
          isLeagueMatchDay: true,
          isHomeMatch: isHome,
          opponentName: opponentName,
          matchday: fixture.matchday,
          isToday: isToday,
        ));
      } else {
        days.add(CalendarDayInfo(
          date: cursor,
          isTrainingFocusDay: cursor.weekday == trainingDayOfWeek,
          isToday: isToday,
        ));
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return days;
  }
}
