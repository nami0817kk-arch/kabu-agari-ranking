/// スポンサー契約。週間収入と引き換えに一定期間クラブに紐づく。
class SponsorDeal {
  String name;
  int weeklyIncome;
  int weeksRemaining;

  SponsorDeal({
    required this.name,
    required this.weeklyIncome,
    required this.weeksRemaining,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'weeklyIncome': weeklyIncome,
        'weeksRemaining': weeksRemaining,
      };

  factory SponsorDeal.fromJson(Map<String, dynamic> json) => SponsorDeal(
        name: json['name'] as String,
        weeklyIncome: json['weeklyIncome'] as int,
        weeksRemaining: json['weeksRemaining'] as int,
      );
}
