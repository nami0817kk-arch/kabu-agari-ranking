enum TrainingFocus { attack, defense, fitness, rest }

extension TrainingFocusLabel on TrainingFocus {
  String get label {
    switch (this) {
      case TrainingFocus.attack:
        return '攻撃強化';
      case TrainingFocus.defense:
        return '守備強化';
      case TrainingFocus.fitness:
        return '体力強化';
      case TrainingFocus.rest:
        return '休養';
    }
  }

  String get description {
    switch (this) {
      case TrainingFocus.attack:
        return 'FW・MFの攻撃力と技術が伸びやすくなる。疲労はやや増加。';
      case TrainingFocus.defense:
        return 'DF・GKの守備力と技術が伸びやすくなる。疲労はやや増加。';
      case TrainingFocus.fitness:
        return '全選手のスタミナが伸びやすくなる。疲労は少し増加。';
      case TrainingFocus.rest:
        return '疲労を大きく回復し、士気も上がる。成長は控えめ。';
    }
  }
}
