import 'dart:math';
import '../models/attributes.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../models/training_focus.dart';

export '../models/training_focus.dart';

class TrainingEngine {
  static final Random _rng = Random();

  /// メンターとして有効に扱える最低年齢。
  static const int minMentorAge = 28;

  /// チームの全選手にトレーニングを適用する。個別方針が設定されている選手は
  /// それを優先し、未設定の選手はチームの既定方針に従う。
  /// [headCoachLevel]は成長効率、[trainingGroundLevel]は成長効率と疲労回復を高める。
  /// [injuryFactor]はフィジオのレベルに応じた練習中の負傷リスク軽減係数。
  static void applyWeeklyTraining(
    Team team, {
    int headCoachLevel = 1,
    int trainingGroundLevel = 1,
    double injuryFactor = 1.0,
  }) {
    final growthMultiplier =
        1 + (headCoachLevel - 1) * 0.15 + (trainingGroundLevel - 1) * 0.08;
    final fatigueRecoveryBonus = (trainingGroundLevel - 1) * 3;
    final byId = {for (final p in team.players) p.id: p};
    final mentorIdsUsed = <String>{};

    for (final p in team.players) {
      final focus = p.individualFocus ?? team.defaultTrainingFocus;
      // ローン放出中の選手は貸出先で練習しているため、自クラブの施設・
      // スタッフによる成長ボーナスは適用しない。
      final isLoanedOut = p.isLoanedOut;
      final effectiveGrowthMultiplier = isLoanedOut ? 1.0 : growthMultiplier;
      final effectiveFatigueRecoveryBonus =
          isLoanedOut ? 0 : fatigueRecoveryBonus;

      final mentor = p.mentorId == null ? null : byId[p.mentorId];
      final validMentor =
          (mentor != null && mentor.id != p.id && mentor.age >= minMentorAge)
              ? mentor
              : null;
      if (validMentor != null) mentorIdsUsed.add(validMentor.id);

      _applyToPlayer(
        p,
        focus,
        effectiveGrowthMultiplier,
        effectiveFatigueRecoveryBonus,
        team.trainingIntensity,
        injuryFactor,
        validMentor != null,
      );
    }

    // 有効なメンターは指導のやりがいから士気が少し上がる。
    for (final id in mentorIdsUsed) {
      final mentor = byId[id];
      if (mentor != null) {
        mentor.happiness = (mentor.happiness + 1).clamp(0, 100);
      }
    }
  }

  static void _applyToPlayer(
    Player p,
    TrainingFocus focus,
    double growthMultiplier,
    int fatigueRecoveryBonus,
    TrainingIntensity intensity,
    double injuryFactor,
    bool hasMentor,
  ) {
    final intensityFactor = intensity.factor;
    final mentorBonus = hasMentor ? 1.2 : 1.0;
    final effectiveGrowth = growthMultiplier * intensityFactor * mentorBonus;

    switch (focus) {
      case TrainingFocus.attack:
        final primary = (p.position.group == PositionGroup.att ||
                p.position.group == PositionGroup.mid)
            ? 0.5
            : 0.15;
        for (final k in [
          AttributeKeys.finishing,
          AttributeKeys.longShots,
          AttributeKeys.dribbling,
          AttributeKeys.offTheBall,
        ]) {
          _grow(p, k, primary * effectiveGrowth);
        }
        for (final k in [
          AttributeKeys.passing,
          AttributeKeys.firstTouch,
          AttributeKeys.technique
        ]) {
          _grow(p, k, 0.25 * effectiveGrowth);
        }
        p.fatigue = (p.fatigue + (12 * intensityFactor).round()).clamp(0, 100);
        break;
      case TrainingFocus.defense:
        final primary = (p.position.group == PositionGroup.def ||
                p.position.group == PositionGroup.gk)
            ? 0.5
            : 0.15;
        for (final k in [
          AttributeKeys.tackling,
          AttributeKeys.marking,
          AttributeKeys.positioning,
          AttributeKeys.anticipation,
        ]) {
          _grow(p, k, primary * effectiveGrowth);
        }
        for (final k in [
          AttributeKeys.passing,
          AttributeKeys.firstTouch,
          AttributeKeys.technique
        ]) {
          _grow(p, k, 0.2 * effectiveGrowth);
        }
        p.fatigue = (p.fatigue + (12 * intensityFactor).round()).clamp(0, 100);
        break;
      case TrainingFocus.fitness:
        for (final k in [
          AttributeKeys.stamina,
          AttributeKeys.naturalFitness,
          AttributeKeys.acceleration,
          AttributeKeys.strength,
        ]) {
          _grow(p, k, 0.45 * effectiveGrowth);
        }
        p.fatigue = (p.fatigue + (6 * intensityFactor).round()).clamp(0, 100);
        break;
      case TrainingFocus.positionSwitch:
        for (final pos in p.secondaryPositions) {
          if (_rng.nextDouble() < (0.5 * effectiveGrowth).clamp(0, 1)) {
            p.growFamiliarity(pos, amount: 2);
          }
        }
        p.fatigue = (p.fatigue + (8 * intensityFactor).round()).clamp(0, 100);
        break;
      case TrainingFocus.rest:
        p.fatigue = (p.fatigue - 30 - fatigueRecoveryBonus).clamp(0, 100);
        p.morale = (p.morale + 8).clamp(0, 100);
        break;
    }

    // ピンポイント特訓ドリル: フォーカスとは無関係に指定した1属性を追加で伸ばす。
    if (p.drillAttributeKey != null) {
      _grow(p, p.drillAttributeKey!, 0.35 * growthMultiplier * intensityFactor);
    }

    p.fatigue = (p.fatigue - 5 - fatigueRecoveryBonus ~/ 2).clamp(0, 100);

    if (focus != TrainingFocus.rest) {
      _rollTrainingInjury(p, intensityFactor, injuryFactor);
    }

    if (p.age >= 31 && _rng.nextDouble() < 0.1) {
      _decline(p);
    }
  }

  /// 高強度の練習メニューによる軽度の負傷判定。基礎体力(naturalFitness)が
  /// 高い選手ほど負傷しにくい。試合中の負傷より短期で済む(1〜2週)。
  static void _rollTrainingInjury(
      Player p, double intensityFactor, double injuryFactor) {
    final naturalFitnessFactor =
        (1 - (p.attributeValue(AttributeKeys.naturalFitness) - 50) / 200)
            .clamp(0.5, 1.5);
    final chance = (0.01 + p.fatigue / 100 * 0.015) *
        intensityFactor *
        naturalFitnessFactor *
        injuryFactor;
    if (_rng.nextDouble() < chance) {
      p.injuryWeeks = (p.injuryWeeks + 1 + _rng.nextInt(2)).clamp(1, 3);
    }
  }

  /// 出場経験を通じたメンタル系能力の成長。試合に出場した選手に対して
  /// [MatchEngine.applyPostMatchEffects]から呼ばれ、判断力・冷静さ・視野・
  /// 予測・リーダーシップのいずれか1項目をわずかな確率で伸ばす。
  static const List<String> matchExperienceGrowthKeys = [
    AttributeKeys.composure,
    AttributeKeys.decisions,
    AttributeKeys.vision,
    AttributeKeys.anticipation,
    AttributeKeys.leadership,
  ];

  static void growFromMatchExperience(Player p) {
    final key = matchExperienceGrowthKeys[
        _rng.nextInt(matchExperienceGrowthKeys.length)];
    _grow(p, key, 0.06);
  }

  static void _grow(Player p, String key, double chance) {
    var c = chance;
    if (p.age > 30) c *= 0.4;
    // 闘志(determination)が高い選手ほど伸びやすく、低い選手は伸びにくい。
    c *= 0.7 + p.attributeValue(AttributeKeys.determination) / 165;
    // 出場機会が乏しく実戦感覚(マッチシャープネス)が低い選手は伸び悩む。
    if (p.matchSharpness < 40) c *= 0.7;
    if (_rng.nextDouble() > c) return;
    final current = p.attributeValue(key);
    if (current >= p.potential) return;
    p.setAttributeValue(key, (current + 1).clamp(1, p.potential));
  }

  static void _decline(Player p) {
    final candidates = _declineCandidates(p);
    final key = candidates[_rng.nextInt(candidates.length)];
    final current = p.attributeValue(key);
    p.setAttributeValue(key, (current - 1).clamp(20, 99));
  }

  /// ポジションごとに衰えやすい能力値グループを重み付けした候補リストを返す。
  /// GKはGK系・フィジカル系、それ以外はフィジカル系(スピード・跳躍力等)が
  /// 優先的に(重複を増やして)選ばれやすくなる。
  static List<String> _declineCandidates(Player p) {
    const physicalHeavy = [
      AttributeKeys.pace,
      AttributeKeys.acceleration,
      AttributeKeys.agility,
      AttributeKeys.jumpingReach,
      AttributeKeys.stamina,
    ];
    if (p.position.group == PositionGroup.gk) {
      return [
        ...AttributeKeys.all,
        ...AttributeKeys.goalkeeping,
        ...AttributeKeys.goalkeeping,
        ...physicalHeavy,
      ];
    }
    return [...AttributeKeys.all, ...physicalHeavy, ...physicalHeavy];
  }
}
