import 'dart:math';

class NamePool {
  static final Random _rng = Random();

  static const _surnames = [
    '佐藤', '鈴木', '高橋', '田中', '伊藤', '渡辺', '山本', '中村', '小林', '加藤',
    '吉田', '山田', '佐々木', '山口', '松本', '井上', '木村', '林', '斎藤', '清水',
    '森', '池田', '橋本', '阿部', '石川', '山下', '中島', '石井', '小川', '前田',
  ];

  static const _givenNames = [
    '翔太', '大輝', '蓮', '陽翔', '悠斗', '颯太', '大和', '健太', '直樹', '拓海',
    '智也', '亮太', '涼太', '康平', '大樹', '雄大', '誠', '秀樹', '一輝', '隼人',
    '航', '葵', '駿', '律', '湊', '悠真', '俊介', '和也', '龍之介', '直希',
  ];

  static const _clubWords = [
    '蒼海', '白鷺', '紅葉', '北斗', '旭丘', '月見坂', '常盤', '緑陰', '朝霧', '東雲',
    '青嵐', '丘陵', '潮風', '桜坂', '若鮎',
  ];

  static const _clubSuffixes = ['FC', 'SC', 'ユナイテッド', 'アスレチック', 'シティ'];

  static String randomPlayerName() {
    final s = _surnames[_rng.nextInt(_surnames.length)];
    final g = _givenNames[_rng.nextInt(_givenNames.length)];
    return '$s $g';
  }

  static List<String> clubNames(int count) {
    final combos = <String>{};
    while (combos.length < count) {
      final w = _clubWords[_rng.nextInt(_clubWords.length)];
      final suf = _clubSuffixes[_rng.nextInt(_clubSuffixes.length)];
      combos.add('$w$suf');
    }
    return combos.toList();
  }
}
