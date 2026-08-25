/// 分割払いで獲得した選手の残金支払い予定。
class Installment {
  String description;
  int weeklyAmount;
  int weeksRemaining;

  Installment({
    required this.description,
    required this.weeklyAmount,
    required this.weeksRemaining,
  });

  Map<String, dynamic> toJson() => {
        'description': description,
        'weeklyAmount': weeklyAmount,
        'weeksRemaining': weeksRemaining,
      };

  factory Installment.fromJson(Map<String, dynamic> json) => Installment(
        description: json['description'] as String,
        weeklyAmount: json['weeklyAmount'] as int,
        weeksRemaining: json['weeksRemaining'] as int,
      );
}
