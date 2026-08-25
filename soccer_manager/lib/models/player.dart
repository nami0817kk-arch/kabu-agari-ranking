import 'dart:math';

import 'attributes.dart';
import 'training_focus.dart';

/// Football Manager風の詳細ポジション（14種類）。
enum Position { gk, dr, dc, dl, wbr, wbl, dm, mr, mc, ml, amr, amc, aml, st }

/// 大分類（GK/DEF/MID/ATT）。試合シミュレーションの攻撃力・守備力算出や
/// トレーニング成長率の判定など、粗い分類で十分な処理に用いる。
enum PositionGroup { gk, def, mid, att }

extension PositionLabel on Position {
  String get label {
    switch (this) {
      case Position.gk:
        return 'GK';
      case Position.dr:
        return 'DR';
      case Position.dc:
        return 'DC';
      case Position.dl:
        return 'DL';
      case Position.wbr:
        return 'WBR';
      case Position.wbl:
        return 'WBL';
      case Position.dm:
        return 'DM';
      case Position.mr:
        return 'MR';
      case Position.mc:
        return 'MC';
      case Position.ml:
        return 'ML';
      case Position.amr:
        return 'AMR';
      case Position.amc:
        return 'AMC';
      case Position.aml:
        return 'AML';
      case Position.st:
        return 'ST';
    }
  }

  /// 日本語での正式名称。
  String get fullLabel {
    switch (this) {
      case Position.gk:
        return 'ゴールキーパー';
      case Position.dr:
        return '右サイドバック';
      case Position.dc:
        return 'センターバック';
      case Position.dl:
        return '左サイドバック';
      case Position.wbr:
        return '右ウイングバック';
      case Position.wbl:
        return '左ウイングバック';
      case Position.dm:
        return '守備的MF';
      case Position.mr:
        return '右MF';
      case Position.mc:
        return 'センターMF';
      case Position.ml:
        return '左MF';
      case Position.amr:
        return '右トップ下';
      case Position.amc:
        return 'トップ下';
      case Position.aml:
        return '左トップ下';
      case Position.st:
        return 'ストライカー';
    }
  }

  PositionGroup get group {
    switch (this) {
      case Position.gk:
        return PositionGroup.gk;
      case Position.dr:
      case Position.dc:
      case Position.dl:
      case Position.wbr:
      case Position.wbl:
        return PositionGroup.def;
      case Position.dm:
      case Position.mr:
      case Position.mc:
      case Position.ml:
        return PositionGroup.mid;
      case Position.amr:
      case Position.amc:
      case Position.aml:
      case Position.st:
        return PositionGroup.att;
    }
  }
}

/// 選手の性格。不満度(happiness)の変動しやすさや移籍希望の出やすさに影響する。
enum PlayerPersonality { professional, balanced, ambitious, temperamental, loyal }

extension PlayerPersonalityInfo on PlayerPersonality {
  String get label {
    switch (this) {
      case PlayerPersonality.professional:
        return 'プロフェッショナル';
      case PlayerPersonality.balanced:
        return 'バランス型';
      case PlayerPersonality.ambitious:
        return '野心家';
      case PlayerPersonality.temperamental:
        return '気分屋';
      case PlayerPersonality.loyal:
        return '忠誠心の強い選手';
    }
  }

  String get description {
    switch (this) {
      case PlayerPersonality.professional:
        return '不満が溜まりにくく、安定した意欲を保つ';
      case PlayerPersonality.balanced:
        return '標準的な反応を示す';
      case PlayerPersonality.ambitious:
        return 'ベンチや低成績にすぐ不満を抱く';
      case PlayerPersonality.temperamental:
        return '状況次第で気分が大きく変動する';
      case PlayerPersonality.loyal:
        return '多少の不満があってもクラブに留まりやすい';
    }
  }

  double get benchSensitivity {
    switch (this) {
      case PlayerPersonality.professional:
        return 0.6;
      case PlayerPersonality.balanced:
        return 1.0;
      case PlayerPersonality.ambitious:
        return 1.5;
      case PlayerPersonality.temperamental:
        return 1.3;
      case PlayerPersonality.loyal:
        return 0.8;
    }
  }

  double get wageSensitivity {
    switch (this) {
      case PlayerPersonality.professional:
        return 0.7;
      case PlayerPersonality.balanced:
        return 1.0;
      case PlayerPersonality.ambitious:
        return 1.3;
      case PlayerPersonality.temperamental:
        return 1.2;
      case PlayerPersonality.loyal:
        return 0.7;
    }
  }

  double get resultSensitivity {
    switch (this) {
      case PlayerPersonality.professional:
        return 0.7;
      case PlayerPersonality.balanced:
        return 1.0;
      case PlayerPersonality.ambitious:
        return 1.4;
      case PlayerPersonality.temperamental:
        return 1.2;
      case PlayerPersonality.loyal:
        return 0.8;
    }
  }

  /// 不満度がこの値を下回ると移籍を希望し始める。
  int get transferRequestThreshold {
    switch (this) {
      case PlayerPersonality.loyal:
        return 10;
      case PlayerPersonality.professional:
        return 15;
      case PlayerPersonality.balanced:
        return 20;
      case PlayerPersonality.temperamental:
        return 25;
      case PlayerPersonality.ambitious:
        return 30;
    }
  }
}

/// 旧バージョン（gk/df/mf/fwの4区分）のセーブデータからポジション名を解決する。
Position parsePosition(String raw) {
  switch (raw) {
    case 'df':
      return Position.dc;
    case 'mf':
      return Position.mc;
    case 'fw':
      return Position.st;
    default:
      try {
        return Position.values.byName(raw);
      } catch (_) {
        return Position.mc;
      }
  }
}

class Player {
  final String id;
  String name;
  int age;
  Position position;

  /// 主ポジションほどではないが無理なくこなせるポジション（0〜2個程度）。
  List<Position> secondaryPositions;

  /// 技術・メンタル・フィジカル・GKの詳細能力値（[AttributeKeys.all]の42項目、1-99）。
  Map<String, int> attributes;

  int potential;
  int fatigue;
  int morale;
  int injuryWeeks;

  /// 個別のトレーニング方針。nullの場合はチームの既定方針に従う。
  TrainingFocus? individualFocus;

  /// 週俸（万円）
  int wage;

  /// 契約残り週数。0になると自由契約としてチームを去る。
  int contractWeeksRemaining;

  /// 性格。不満度の変動しやすさ・移籍希望の出やすさに影響する。
  PlayerPersonality personality;

  /// 不満度（0-100）。低いほど移籍を希望しやすくなる。
  int happiness;

  /// ローンでの加入かどうか。ローン選手は契約更新・放出の対象外で、
  /// [loanWeeksRemaining]が0になると自動的にチームを離れる。
  bool isLoan;

  /// ローン期間の残り週数（ローン選手でない場合は0）。
  int loanWeeksRemaining;

  /// リリース条項(解放金額、万円)。設定されている場合、他クラブがこの金額を
  /// 提示すると交渉なしで自動的に移籍が成立する。未設定はnull。
  int? releaseClause;

  Player({
    required this.id,
    required this.name,
    required this.age,
    required this.position,
    required this.potential,
    List<Position>? secondaryPositions,
    Map<String, int>? attributes,
    this.fatigue = 0,
    this.morale = 75,
    this.injuryWeeks = 0,
    this.individualFocus,
    this.wage = 20,
    this.contractWeeksRemaining = 20,
    this.personality = PlayerPersonality.balanced,
    this.happiness = 70,
    this.isLoan = false,
    this.loanWeeksRemaining = 0,
    this.releaseClause,
  })  : secondaryPositions = secondaryPositions ?? [],
        attributes = attributes ?? {for (final k in AttributeKeys.all) k: 50};

  /// このポジション（主・副とも）を無理なくこなせるか。
  bool canPlay(Position pos) => position == pos || secondaryPositions.contains(pos);

  /// 不満度が性格ごとの閾値を下回り、移籍を希望しているかどうか。
  bool get wantsTransfer => happiness < personality.transferRequestThreshold;

  int attributeValue(String key) => attributes[key] ?? 50;

  void setAttributeValue(String key, int value) {
    attributes[key] = value.clamp(1, 99);
  }

  int _weightedAverage(Map<String, int> weights) {
    var total = 0;
    var weightSum = 0;
    weights.forEach((key, weight) {
      total += attributeValue(key) * weight;
      weightSum += weight;
    });
    if (weightSum == 0) return 50;
    return (total / weightSum).round();
  }

  /// 攻撃力（シュート・崩し・オフザボールの複合値）
  int get attack => _weightedAverage({
        AttributeKeys.finishing: 3,
        AttributeKeys.longShots: 2,
        AttributeKeys.dribbling: 2,
        AttributeKeys.offTheBall: 2,
        AttributeKeys.composure: 1,
        AttributeKeys.pace: 1,
      });

  /// 守備力（対人・ポジショニングの複合値）
  int get defense => _weightedAverage({
        AttributeKeys.tackling: 3,
        AttributeKeys.marking: 3,
        AttributeKeys.positioning: 2,
        AttributeKeys.anticipation: 2,
        AttributeKeys.strength: 1,
        AttributeKeys.aggression: 1,
      });

  /// 技術（パス・ボールコントロールの複合値）
  int get technique => _weightedAverage({
        AttributeKeys.passing: 3,
        AttributeKeys.firstTouch: 2,
        AttributeKeys.vision: 2,
        AttributeKeys.technique: 2,
        AttributeKeys.crossing: 1,
        AttributeKeys.decisions: 1,
      });

  /// スタミナ（持久力・運動量の複合値）
  int get stamina => _weightedAverage({
        AttributeKeys.stamina: 3,
        AttributeKeys.naturalFitness: 2,
        AttributeKeys.workRate: 2,
        AttributeKeys.strength: 1,
        AttributeKeys.acceleration: 1,
      });

  int get overall => ((attack + defense + technique + stamina) / 4).round();

  bool get isInjured => injuryWeeks > 0;

  /// 想定移籍金（万円）。年齢・現在能力・伸びしろから概算する。
  int get marketValue {
    final ovr = (overall - 40).clamp(0, 60);
    final base = pow(ovr, 1.8) * 3;
    final potentialBonus = (potential - overall).clamp(0, 40) * 15;
    double ageFactor;
    if (age <= 21) {
      ageFactor = 1.4;
    } else if (age <= 27) {
      ageFactor = 1.1;
    } else if (age <= 30) {
      ageFactor = 0.8;
    } else {
      ageFactor = 0.4;
    }
    final value = (base + potentialBonus) * ageFactor;
    return value.round().clamp(50, 20000);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'age': age,
        'position': position.name,
        'secondaryPositions': secondaryPositions.map((p) => p.name).toList(),
        'attributes': attributes,
        'potential': potential,
        'fatigue': fatigue,
        'morale': morale,
        'injuryWeeks': injuryWeeks,
        'individualFocus': individualFocus?.name,
        'wage': wage,
        'contractWeeksRemaining': contractWeeksRemaining,
        'personality': personality.name,
        'happiness': happiness,
        'isLoan': isLoan,
        'loanWeeksRemaining': loanWeeksRemaining,
        'releaseClause': releaseClause,
      };

  factory Player.fromJson(Map<String, dynamic> json) {
    final rawAttributes = json['attributes'] as Map<String, dynamic>?;
    final attributes = rawAttributes != null
        ? {for (final k in AttributeKeys.all) k: (rawAttributes[k] as int?) ?? 50}
        : _migrateLegacyAttributes(json);

    return Player(
      id: json['id'] as String,
      name: json['name'] as String,
      age: json['age'] as int,
      position: parsePosition(json['position'] as String),
      secondaryPositions: (json['secondaryPositions'] as List?)
              ?.map((e) => parsePosition(e as String))
              .toList() ??
          [],
      attributes: attributes,
      potential: json['potential'] as int,
      fatigue: json['fatigue'] as int? ?? 0,
      morale: json['morale'] as int? ?? 75,
      injuryWeeks: json['injuryWeeks'] as int? ?? 0,
      individualFocus: json['individualFocus'] == null
          ? null
          : TrainingFocus.values.byName(json['individualFocus'] as String),
      wage: json['wage'] as int? ?? 20,
      contractWeeksRemaining: json['contractWeeksRemaining'] as int? ?? 20,
      personality: json['personality'] == null
          ? PlayerPersonality.balanced
          : PlayerPersonality.values.byName(json['personality'] as String),
      happiness: json['happiness'] as int? ?? 70,
      isLoan: json['isLoan'] as bool? ?? false,
      loanWeeksRemaining: json['loanWeeksRemaining'] as int? ?? 0,
      releaseClause: json['releaseClause'] as int?,
    );
  }

  /// 旧セーブ（attack/defense/technique/staminaの4値のみ）からの移行用。
  /// 該当する系統の詳細項目にそれぞれの値を割り当て、それ以外は50で埋める。
  static Map<String, int> _migrateLegacyAttributes(Map<String, dynamic> json) {
    final legacyAttack = json['attack'] as int? ?? 50;
    final legacyDefense = json['defense'] as int? ?? 50;
    final legacyTechnique = json['technique'] as int? ?? 50;
    final legacyStamina = json['stamina'] as int? ?? 50;

    final map = {for (final k in AttributeKeys.all) k: 50};
    for (final k in [
      AttributeKeys.finishing,
      AttributeKeys.longShots,
      AttributeKeys.dribbling,
      AttributeKeys.offTheBall,
    ]) {
      map[k] = legacyAttack;
    }
    for (final k in [
      AttributeKeys.tackling,
      AttributeKeys.marking,
      AttributeKeys.positioning,
      AttributeKeys.anticipation,
    ]) {
      map[k] = legacyDefense;
    }
    for (final k in [
      AttributeKeys.passing,
      AttributeKeys.firstTouch,
      AttributeKeys.vision,
      AttributeKeys.technique,
    ]) {
      map[k] = legacyTechnique;
    }
    for (final k in [
      AttributeKeys.stamina,
      AttributeKeys.naturalFitness,
      AttributeKeys.workRate,
    ]) {
      map[k] = legacyStamina;
    }
    return map;
  }
}
