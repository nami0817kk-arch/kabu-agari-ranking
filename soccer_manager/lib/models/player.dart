import 'dart:math';

import 'attributes.dart';
import 'enum_json.dart';
import 'training_focus.dart';

/// Football Manager風の詳細ポジション（14種類）。
enum Position { gk, dr, dc, dl, wbr, wbl, dm, mr, mc, ml, amr, amc, aml, st }

/// 負傷の種類。種類ごとに典型的な療養期間が異なる。
enum InjuryType { bruise, muscle, ligament }

extension InjuryTypeInfo on InjuryType {
  String get label => switch (this) {
        InjuryType.bruise => '打撲',
        InjuryType.muscle => '肉離れ',
        InjuryType.ligament => '靭帯損傷',
      };

  /// 典型的な療養期間(週)の範囲。
  (int min, int max) get durationRange => switch (this) {
        InjuryType.bruise => (1, 2),
        InjuryType.muscle => (2, 5),
        InjuryType.ligament => (4, 10),
      };
}

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

/// 選手の戦術上のデューティ(役割の重心)。攻撃/守備の貢献度に補正がかかる。
enum PlayerDuty { defend, support, attack }

extension PlayerDutyInfo on PlayerDuty {
  String get label => switch (this) {
        PlayerDuty.defend => '守備的',
        PlayerDuty.support => 'バランス',
        PlayerDuty.attack => '攻撃的',
      };
}

/// 選手のプレースタイル(ロール)。デューティ(攻守の重心)とは別に、
/// どの能力値を活かしたプレーを得意とするかを表す。役割に適した能力値が
/// 高いほど攻撃/守備への貢献度にボーナスが、低いと逆にペナルティがかかる。
enum PlayerRole {
  standard,
  sweeperKeeper,
  ballPlayingDefender,
  stopper,
  playmaker,
  boxToBox,
  poacher,
  targetMan,
}

extension PlayerRoleInfo on PlayerRole {
  String get label => switch (this) {
        PlayerRole.standard => '標準',
        PlayerRole.sweeperKeeper => 'スイーパーキーパー',
        PlayerRole.ballPlayingDefender => 'ビルドアップCB',
        PlayerRole.stopper => 'ストッパー',
        PlayerRole.playmaker => 'プレーメイカー',
        PlayerRole.boxToBox => 'ボックストゥボックス',
        PlayerRole.poacher => 'ポーチャー',
        PlayerRole.targetMan => 'ターゲットマン',
      };

  String get description => switch (this) {
        PlayerRole.standard => '特定のプレースタイルを指定しない',
        PlayerRole.sweeperKeeper => 'キック・ハンドリングを活かしたビルドアップ参加型のGK',
        PlayerRole.ballPlayingDefender => 'パス・視野を活かして後方から組み立てるCB',
        PlayerRole.stopper => 'タックル・積極性を活かして潰しにかかるCB',
        PlayerRole.playmaker => 'パス・視野で崩しの起点となるMF',
        PlayerRole.boxToBox => 'スタミナ・運動量で攻守にわたって働くMF',
        PlayerRole.poacher => 'フィニッシュ・オフザボールで得点を狙うFW',
        PlayerRole.targetMan => 'ヘディング・強さを活かした起点となるFW',
      };

  /// このロールを選択できるポジション大分類(standardは全ポジション共通)。
  List<PositionGroup> get allowedGroups => switch (this) {
        PlayerRole.standard => PositionGroup.values,
        PlayerRole.sweeperKeeper => [PositionGroup.gk],
        PlayerRole.ballPlayingDefender || PlayerRole.stopper => [
            PositionGroup.def
          ],
        PlayerRole.playmaker || PlayerRole.boxToBox => [PositionGroup.mid],
        PlayerRole.poacher || PlayerRole.targetMan => [PositionGroup.att],
      };

  /// このロールの適性を判定する際に重視する能力値(2項目の平均で評価)。
  List<String> get keyAttributes => switch (this) {
        PlayerRole.standard => const [],
        PlayerRole.sweeperKeeper => const [
            AttributeKeys.kicking,
            AttributeKeys.commandOfArea,
          ],
        PlayerRole.ballPlayingDefender => const [
            AttributeKeys.passing,
            AttributeKeys.vision,
          ],
        PlayerRole.stopper => const [
            AttributeKeys.tackling,
            AttributeKeys.aggression,
          ],
        PlayerRole.playmaker => const [
            AttributeKeys.vision,
            AttributeKeys.passing,
          ],
        PlayerRole.boxToBox => const [
            AttributeKeys.stamina,
            AttributeKeys.workRate,
          ],
        PlayerRole.poacher => const [
            AttributeKeys.finishing,
            AttributeKeys.offTheBall,
          ],
        PlayerRole.targetMan => const [
            AttributeKeys.heading,
            AttributeKeys.strength,
          ],
      };
}

/// 選手の性格。不満度(happiness)の変動しやすさや移籍希望の出やすさに影響する。
enum PlayerPersonality {
  professional,
  balanced,
  ambitious,
  temperamental,
  loyal
}

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

  /// 現在負傷している場合の負傷の種類(負傷していない場合はnull)。
  InjuryType? injuryType;

  /// 過去に負ったことのある負傷の種類ごとの回数。再負傷のリスク判定に使う。
  Map<String, int> injuryHistoryCounts;

  /// 現在の累積警告数(退場したリセットされる)。[yellowCardSuspensionThreshold]枚
  /// 貯まると次節出場停止になり0にリセットされる。
  int yellowCards;

  /// 出場停止の残り試合数(0なら出場停止でない)。退場は即1試合、
  /// 警告累積は[yellowCardSuspensionThreshold]枚で1試合の出場停止。
  int suspendedMatches;

  /// 通算出場試合数・通算得点数(公式戦・カップ戦。親善試合は含まない)。
  int careerAppearances;
  int careerGoals;

  /// 個別のトレーニング方針。nullの場合はチームの既定方針に従う。
  TrainingFocus? individualFocus;

  /// 週俸（万円）
  int wage;

  /// 契約残り年数。0になると自由契約としてチームを去る(シーズン開始時に
  /// 1年ずつ消化する)。
  int contractYearsRemaining;

  /// 性格。不満度の変動しやすさ・移籍希望の出やすさに影響する。
  PlayerPersonality personality;

  /// 不満度（0-100）。低いほど移籍を希望しやすくなる。
  int happiness;

  /// 話し合い(reassure)の再実施までの残り週数。0なら実施可能。
  /// 連発による不満度管理の形骸化を防ぐためのクールダウン。
  int reassureCooldownWeeks;

  /// ローンでの加入かどうか。ローン選手は契約更新・放出の対象外で、
  /// [loanWeeksRemaining]が0になると自動的にチームを離れる。
  bool isLoan;

  /// ローン期間の残り週数（ローン選手でない場合は0）。
  int loanWeeksRemaining;

  /// ローン契約に買取オプションが付いている場合の買取金額(万円)。
  /// ローン期間中いつでもこの金額を支払えば恒久的に完全移籍へ切り替えられる。
  /// 買取オプションがない通常のローンの場合はnull。
  int? loanBuyOptionFee;

  /// リリース条項(解放金額、万円)。設定されている場合、他クラブがこの金額を
  /// 提示すると交渉なしで自動的に移籍が成立する。未設定はnull。
  int? releaseClause;

  /// 代表召集で一時離脱している残り週数(0なら招集されていない)。
  /// 招集中はスタメン・自動編成の対象外になる。
  int internationalDutyWeeksRemaining;

  /// 戦術上のデューティ(守備的/バランス/攻撃的)。試合エンジンの攻守貢献度に補正がかかる。
  PlayerDuty duty;

  /// 移籍リストに登録されているか。登録中は他クラブからのオファーが来やすくなる。
  bool isTransferListed;

  /// 他クラブへローン放出中かどうかの残り週数(0なら放出されていない)。
  /// 放出中はスタメン・自動編成の対象外で、週俸は放出先クラブが負担する。
  int loanedOutWeeksRemaining;
  String? loanedOutToClubName;

  /// 移籍市場にスカウティング候補として掲載されている選手の現所属クラブ名
  /// (表示専用。自クラブの選手・フリーエージェントにはnull)。
  String? originClubName;

  /// 出場手当(万円)。契約更新時に決定され、リーグ公式戦でスタメン出場するたびに支払われる。
  int appearanceFee;

  /// プレースタイル(ロール)。デューティとは別に、活躍する能力値の傾向を表す。
  PlayerRole role;

  /// 本職(主ポジション)以外のポジションで起用された際の慣れ度(0-100、
  /// Position.name → 慣れ度)。出場を重ねるごとに上昇し、攻撃/守備への
  /// ペナルティを徐々に軽減する。主ポジションは常に完全適性のため含まない。
  Map<String, int> positionFamiliarity;

  /// 直近の試合勘・コンディション(0-100)。出場を重ねると上昇し、
  /// ベンチ・怪我・出場停止が続くと緩やかに低下する。負傷から復帰した
  /// 直後は大きく下がる。試合エンジンのコンディション算出に用いる。
  int matchSharpness;

  /// メンター(指導役)に指名されたベテラン選手のID。若手選手の成長率に
  /// ボーナスを与える代わりに、メンター自身の士気も少し上がる。
  String? mentorId;

  /// ピンポイントで重点的に伸ばしたい能力値。設定するとチーム/個別の
  /// トレーニング方針とは別に、この1項目の成長確率が上乗せされる。
  String? drillAttributeKey;

  /// ポジションコンバート特訓(TrainingFocus.positionSwitch)で目標とする
  /// ポジション(Position.name)。設定した場合、生成時に偶然割り当てられた
  /// secondaryPositionsとは関係なく、このポジションの慣れ度を集中的に
  /// 伸ばす。慣れ度が上限(100)に達するとsecondaryPositionsへ自動的に
  /// 追加され、実際にそのポジションで起用できるようになる。
  String? trainingConvertTargetPosition;

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
    this.injuryType,
    Map<String, int>? injuryHistoryCounts,
    this.yellowCards = 0,
    this.suspendedMatches = 0,
    this.careerAppearances = 0,
    this.careerGoals = 0,
    this.individualFocus,
    this.wage = 20,
    this.contractYearsRemaining = 2,
    this.personality = PlayerPersonality.balanced,
    this.happiness = 70,
    this.reassureCooldownWeeks = 0,
    this.isLoan = false,
    this.loanWeeksRemaining = 0,
    this.loanBuyOptionFee,
    this.releaseClause,
    this.internationalDutyWeeksRemaining = 0,
    this.duty = PlayerDuty.support,
    this.isTransferListed = false,
    this.loanedOutWeeksRemaining = 0,
    this.loanedOutToClubName,
    this.originClubName,
    this.appearanceFee = 0,
    this.role = PlayerRole.standard,
    Map<String, int>? positionFamiliarity,
    this.matchSharpness = 80,
    this.mentorId,
    this.drillAttributeKey,
    this.trainingConvertTargetPosition,
  })  : secondaryPositions = secondaryPositions ?? [],
        attributes = attributes ?? {for (final k in AttributeKeys.all) k: 50},
        positionFamiliarity = positionFamiliarity ?? {},
        injuryHistoryCounts = injuryHistoryCounts ?? {};

  /// このポジション（主・副とも）を無理なくこなせるか。
  bool canPlay(Position pos) =>
      position == pos || secondaryPositions.contains(pos);

  /// 指定ポジションでの慣れ度(0-100)。主ポジションは常に100。
  int familiarityFor(Position pos) =>
      pos == position ? 100 : (positionFamiliarity[pos.name] ?? 0);

  /// 本職外のポジションで出場した際、慣れ度を積み増す(上限100)。
  void growFamiliarity(Position pos, {int amount = 3}) {
    if (pos == position) return;
    final current = positionFamiliarity[pos.name] ?? 0;
    positionFamiliarity[pos.name] = (current + amount).clamp(0, 100);
  }

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

  /// 攻撃力（シュート・崩し・オフザボールの複合値）。ひらめき(flair)は
  /// 意表を突く仕掛け、バランス(balance)は競り合い下でのドリブル/仕掛けの
  /// 質に寄与するため軽い重みで加える。
  int get attack => _weightedAverage({
        AttributeKeys.finishing: 3,
        AttributeKeys.longShots: 2,
        AttributeKeys.dribbling: 2,
        AttributeKeys.offTheBall: 2,
        AttributeKeys.composure: 1,
        AttributeKeys.pace: 1,
        AttributeKeys.flair: 1,
        AttributeKeys.balance: 1,
      });

  /// 守備力（対人・ポジショニングの複合値）。集中力(concentration)は
  /// 守備での注意散漫による失点を減らし、勇敢さ(bravery)は際どい競り合い・
  /// 最後の一枚での対応に寄与するため軽い重みで加える。
  int get defense => _weightedAverage({
        AttributeKeys.tackling: 3,
        AttributeKeys.marking: 3,
        AttributeKeys.positioning: 2,
        AttributeKeys.anticipation: 2,
        AttributeKeys.strength: 1,
        AttributeKeys.aggression: 1,
        AttributeKeys.concentration: 1,
        AttributeKeys.bravery: 1,
      });

  /// 技術（パス・ボールコントロールの複合値）。連係(teamwork)は周囲との
  /// コンビネーションプレーの質に寄与するため軽い重みで加える。
  int get technique => _weightedAverage({
        AttributeKeys.passing: 3,
        AttributeKeys.firstTouch: 2,
        AttributeKeys.vision: 2,
        AttributeKeys.technique: 2,
        AttributeKeys.crossing: 1,
        AttributeKeys.decisions: 1,
        AttributeKeys.teamwork: 1,
      });

  /// スタミナ（持久力・運動量の複合値）
  int get stamina => _weightedAverage({
        AttributeKeys.stamina: 3,
        AttributeKeys.naturalFitness: 2,
        AttributeKeys.workRate: 2,
        AttributeKeys.strength: 1,
        AttributeKeys.acceleration: 1,
      });

  /// ゴールキーピング(反応・ハイボール処理などの複合値)。GK以外にはあまり
  /// 意味を持たないが、GKの総合力・市場価値を正しく反映するために必要。
  int get goalkeeping => _weightedAverage({
        AttributeKeys.reflexes: 3,
        AttributeKeys.handling: 3,
        AttributeKeys.oneOnOnes: 2,
        AttributeKeys.aerialReach: 2,
        AttributeKeys.commandOfArea: 1,
        AttributeKeys.kicking: 1,
      });

  int get overall => position == Position.gk
      ? ((goalkeeping * 2 + defense + stamina) / 4).round()
      : ((attack + defense + technique + stamina) / 4).round();

  bool get isInjured => injuryWeeks > 0;

  bool get isSuspended => suspendedMatches > 0;

  bool get isOnInternationalDuty => internationalDutyWeeksRemaining > 0;

  /// 他クラブへローン放出中で、自クラブの試合には出場できない状態かどうか。
  bool get isLoanedOut => loanedOutWeeksRemaining > 0;

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
        'injuryType': injuryType?.name,
        'injuryHistoryCounts': injuryHistoryCounts,
        'yellowCards': yellowCards,
        'suspendedMatches': suspendedMatches,
        'careerAppearances': careerAppearances,
        'careerGoals': careerGoals,
        'individualFocus': individualFocus?.name,
        'wage': wage,
        'contractYearsRemaining': contractYearsRemaining,
        'personality': personality.name,
        'happiness': happiness,
        'reassureCooldownWeeks': reassureCooldownWeeks,
        'isLoan': isLoan,
        'loanWeeksRemaining': loanWeeksRemaining,
        'loanBuyOptionFee': loanBuyOptionFee,
        'releaseClause': releaseClause,
        'internationalDutyWeeksRemaining': internationalDutyWeeksRemaining,
        'duty': duty.name,
        'isTransferListed': isTransferListed,
        'loanedOutWeeksRemaining': loanedOutWeeksRemaining,
        'loanedOutToClubName': loanedOutToClubName,
        'originClubName': originClubName,
        'appearanceFee': appearanceFee,
        'role': role.name,
        'positionFamiliarity': positionFamiliarity,
        'matchSharpness': matchSharpness,
        'mentorId': mentorId,
        'drillAttributeKey': drillAttributeKey,
        'trainingConvertTargetPosition': trainingConvertTargetPosition,
      };

  factory Player.fromJson(Map<String, dynamic> json) {
    final rawAttributes = json['attributes'] as Map<String, dynamic>?;
    final attributes = rawAttributes != null
        ? {
            for (final k in AttributeKeys.all)
              k: (rawAttributes[k] as int?) ?? 50
          }
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
      injuryType: json['injuryType'] == null
          ? null
          : enumFromName(InjuryType.values, json['injuryType'] as String?,
              InjuryType.bruise),
      injuryHistoryCounts: (json['injuryHistoryCounts'] as Map?)?.map(
            (k, v) => MapEntry(k as String, v as int),
          ) ??
          {},
      yellowCards: json['yellowCards'] as int? ?? 0,
      suspendedMatches: json['suspendedMatches'] as int? ?? 0,
      careerAppearances: json['careerAppearances'] as int? ?? 0,
      careerGoals: json['careerGoals'] as int? ?? 0,
      individualFocus: json['individualFocus'] == null
          ? null
          : enumFromName(TrainingFocus.values,
              json['individualFocus'] as String?, TrainingFocus.rest),
      wage: json['wage'] as int? ?? 20,
      contractYearsRemaining: _migrateContractYears(json),
      personality: enumFromName(PlayerPersonality.values,
          json['personality'] as String?, PlayerPersonality.balanced),
      happiness: json['happiness'] as int? ?? 70,
      reassureCooldownWeeks: json['reassureCooldownWeeks'] as int? ?? 0,
      isLoan: json['isLoan'] as bool? ?? false,
      loanWeeksRemaining: json['loanWeeksRemaining'] as int? ?? 0,
      loanBuyOptionFee: json['loanBuyOptionFee'] as int?,
      releaseClause: json['releaseClause'] as int?,
      internationalDutyWeeksRemaining:
          json['internationalDutyWeeksRemaining'] as int? ?? 0,
      duty: enumFromName(
          PlayerDuty.values, json['duty'] as String?, PlayerDuty.support),
      isTransferListed: json['isTransferListed'] as bool? ?? false,
      loanedOutWeeksRemaining: json['loanedOutWeeksRemaining'] as int? ?? 0,
      loanedOutToClubName: json['loanedOutToClubName'] as String?,
      originClubName: json['originClubName'] as String?,
      appearanceFee: json['appearanceFee'] as int? ?? 0,
      role: enumFromName(
          PlayerRole.values, json['role'] as String?, PlayerRole.standard),
      positionFamiliarity: (json['positionFamiliarity'] as Map?)?.map(
            (k, v) => MapEntry(k as String, v as int),
          ) ??
          {},
      matchSharpness: json['matchSharpness'] as int? ?? 80,
      mentorId: json['mentorId'] as String?,
      drillAttributeKey: json['drillAttributeKey'] as String?,
      trainingConvertTargetPosition:
          json['trainingConvertTargetPosition'] as String?,
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

  /// 旧セーブ(契約を週数で管理していた版)からの移行用。新フィールドが
  /// あればそれを使い、なければ旧フィールドの週数を年数に丸めて引き継ぐ。
  static int _migrateContractYears(Map<String, dynamic> json) {
    final years = json['contractYearsRemaining'] as int?;
    if (years != null) return years;
    final legacyWeeks = json['contractWeeksRemaining'] as int?;
    if (legacyWeeks == null) return 2;
    if (legacyWeeks <= 0) return 0;
    return (legacyWeeks / 52).ceil().clamp(1, 10);
  }
}
