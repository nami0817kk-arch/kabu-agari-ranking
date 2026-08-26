import '../models/attributes.dart';

/// 用語集のカテゴリ。用語集画面でのグルーピング・絞り込みに用いる。
enum GlossaryCategory {
  attribute,
  composite,
  condition,
  contractTransfer,
  tactics,
  club,
}

extension GlossaryCategoryInfo on GlossaryCategory {
  String get label => switch (this) {
        GlossaryCategory.attribute => '選手能力値',
        GlossaryCategory.composite => '複合指標',
        GlossaryCategory.condition => 'コンディション・メンタル',
        GlossaryCategory.contractTransfer => '契約・移籍',
        GlossaryCategory.tactics => '戦術',
        GlossaryCategory.club => 'クラブ経営',
      };
}

/// 用語集の1項目。[term]は画面上の見出し、[description]は意味・仕様の説明文。
class GlossaryEntry {
  final String term;
  final GlossaryCategory category;
  final String description;

  const GlossaryEntry({
    required this.term,
    required this.category,
    required this.description,
  });
}

const Map<String, String> _attributeDescriptions = {
  AttributeKeys.corners: 'コーナーキックの精度。コーナー担当に指名された選手の値が高いほどチャンスの質が上がる。',
  AttributeKeys.crossing: 'サイドからのクロスの正確さ。攻撃力の複合値(技術)に反映される。',
  AttributeKeys.dribbling: 'ボールを持って相手を抜く能力。攻撃力の複合値に反映される。',
  AttributeKeys.finishing: 'シュートの決定力。攻撃力の複合値で最も重みが大きい項目。',
  AttributeKeys.firstTouch: 'ボールを受けた際の落ち着き。技術の複合値に反映される。',
  AttributeKeys.freeKick: '直接フリーキックの精度。FK担当に指名された選手の値が高いほどチャンスの質が上がる。',
  AttributeKeys.heading: '空中戦での競り合い・ヘディングシュートの精度。',
  AttributeKeys.longShots: '中距離・遠距離からのシュート精度。攻撃力の複合値に反映される。',
  AttributeKeys.longThrows: 'ロングスローインの飛距離・精度。',
  AttributeKeys.marking: '相手選手を捕まえる能力。守備力の複合値で最も重みが大きい項目。',
  AttributeKeys.passing: 'パスの正確さ。技術の複合値で最も重みが大きい項目。',
  AttributeKeys.penalties: 'PKの成功率。PK担当に指名された選手の値が高いほど成功率が上がる。',
  AttributeKeys.tackling: '相手からボールを奪う能力。守備力の複合値に反映される。',
  AttributeKeys.technique: 'ボールコントロール全般の巧みさ。技術の複合値に反映される。',
  AttributeKeys.aggression: '球際やプレスでの積極性。高いほど守備力にプラスだが、警告・退場のリスクも増える。',
  AttributeKeys.anticipation: '状況を先読みする力。守備力の複合値に反映される。',
  AttributeKeys.bravery: '危険な状況でも臆さずプレーする度胸。',
  AttributeKeys.composure: 'プレッシャー下での冷静さ。高いほど攻撃力にプラスで、警告のリスクを抑える。',
  AttributeKeys.concentration: '試合を通して集中力を維持する能力。',
  AttributeKeys.decisions: '状況判断の的確さ。技術の複合値に反映される。',
  AttributeKeys.determination: '逆境でも諦めない闘志。潜在能力に到達するための成長のしやすさに影響する。',
  AttributeKeys.flair: '独創的なプレーを生み出すひらめき。',
  AttributeKeys.leadership: 'チームを鼓舞する統率力。値が高い選手をキャプテンに指名すると効果的。',
  AttributeKeys.offTheBall: 'ボールを持たない時の動き出し。攻撃力の複合値に反映される。',
  AttributeKeys.positioning: '守備時の立ち位置の的確さ。守備力の複合値に反映される。',
  AttributeKeys.teamwork: '味方と連携してプレーする意識。',
  AttributeKeys.vision: '味方の動きを見通すパスセンス。技術の複合値に反映される。',
  AttributeKeys.workRate: '運動量・献身性。スタミナの複合値に反映される。',
  AttributeKeys.acceleration: '瞬間的な加速力。スタミナの複合値に反映される。',
  AttributeKeys.agility: '身のこなしの俊敏さ。',
  AttributeKeys.balance: '接触時にバランスを崩さない安定感。',
  AttributeKeys.jumpingReach: 'ジャンプの高さ・到達点。空中戦の強さに関わる。',
  AttributeKeys.naturalFitness: '生まれ持った体力の強さ。高いほど怪我をしにくく、トレーニングでの成長効率にも影響する。',
  AttributeKeys.pace: '走る速さ。攻撃力の複合値に反映される。',
  AttributeKeys.stamina: '試合を通して運動量を維持する持久力。スタミナの複合値で最も重みが大きい項目。',
  AttributeKeys.strength: 'フィジカルの強さ。守備力・スタミナ両方の複合値に反映される。',
  AttributeKeys.aerialReach: 'GKが飛び出して高いボールに対応する能力。',
  AttributeKeys.commandOfArea: 'GKがペナルティエリア内を統率する能力。',
  AttributeKeys.handling: 'GKがボールを確実にキャッチ・キープする能力。',
  AttributeKeys.kicking: 'GKのゴールキックやパントキックの精度。',
  AttributeKeys.oneOnOnes: 'GKが1対1の場面でシュートを防ぐ能力。',
  AttributeKeys.reflexes: 'GKの反射的な反応の速さ。',
};

final List<GlossaryEntry> glossaryEntries = [
  for (final key in AttributeKeys.all)
    GlossaryEntry(
      term: AttributeKeys.labelOf(key),
      category: GlossaryCategory.attribute,
      description: _attributeDescriptions[key] ?? '',
    ),
  const GlossaryEntry(
    term: '総合力',
    category: GlossaryCategory.composite,
    description: '選手全体の実力を1つの数値にまとめたもの。攻撃力・守備力・技術・スタミナなど能力値全体の平均から算出される。',
  ),
  const GlossaryEntry(
    term: '潜在能力',
    category: GlossaryCategory.composite,
    description:
        '選手が将来到達しうる総合力の上限。若い選手ほど現在の総合力との差(伸びしろ)が大きくなりやすく、ユース画面では「伸びしろ」でも並び替えできる。',
  ),
  const GlossaryEntry(
    term: '攻撃力',
    category: GlossaryCategory.composite,
    description:
        'フィニッシュ・ロングシュート・ドリブル・オフザボール・冷静さ・スピードの加重平均。試合シミュレーションのチーム攻撃力計算のベースになる。',
  ),
  const GlossaryEntry(
    term: '守備力',
    category: GlossaryCategory.composite,
    description:
        'タックル・マーキング・ポジショニング・予測・強さ・積極性の加重平均。試合シミュレーションのチーム守備力計算のベースになる。',
  ),
  const GlossaryEntry(
    term: '技術',
    category: GlossaryCategory.composite,
    description: 'パス・ファーストタッチ・視野・テクニック・クロス・判断力の加重平均。ボールを扱う巧みさの目安。',
  ),
  const GlossaryEntry(
    term: 'スタミナ(複合値)',
    category: GlossaryCategory.composite,
    description: 'スタミナ・基礎体力・労働量・強さ・加速力の加重平均。運動量が求められるポジションほど重要になる。',
  ),
  const GlossaryEntry(
    term: '疲労',
    category: GlossaryCategory.condition,
    description:
        '試合出場・厳しいプレッシングで蓄積し、休養やトレーニング施設で回復する。高いほど試合でのコンディション(パフォーマンス)が下がる。',
  ),
  const GlossaryEntry(
    term: '士気(モラール)',
    category: GlossaryCategory.condition,
    description: 'チームの勢い・選手の意気込みを表す値。高いほど試合でのコンディションが上がる。連勝や記者会見での受け答えで変動する。',
  ),
  const GlossaryEntry(
    term: 'マッチシャープネス',
    category: GlossaryCategory.condition,
    description:
        '直近の試合勘・実戦感覚。出場を重ねるほど上がり、ベンチ・怪我・出場停止が続くと緩やかに下がる。負傷から復帰した直後は大きく下がるため、復帰後しばらくは本来のコンディションを出しにくい。',
  ),
  const GlossaryEntry(
    term: 'コンディション',
    category: GlossaryCategory.condition,
    description:
        '試合中の実際のパフォーマンス補正。疲労・士気・マッチシャープネスの3要素から算出され、これらが高いほど攻撃力・守備力への影響が良くなる。',
  ),
  const GlossaryEntry(
    term: '不満度',
    category: GlossaryCategory.condition,
    description:
        '選手のクラブへの満足度(0-100)。低いほど移籍を希望しやすくなる。出場機会・週俸・チーム成績・性格によって変動し、性格ごとの閾値を下回ると移籍希望のフラグが立つ。',
  ),
  const GlossaryEntry(
    term: '性格',
    category: GlossaryCategory.condition,
    description:
        '選手の気質。不満度の変動しやすさ・移籍希望の出やすさに影響する(プロフェッショナル/バランス型/野心家/気分屋/忠誠心の強い選手)。',
  ),
  const GlossaryEntry(
    term: 'デューティ',
    category: GlossaryCategory.condition,
    description:
        '選手の戦術上の役割の重心(守備的/バランス/攻撃的)。攻撃的にするほど攻撃力に、守備的にするほど守備力にボーナスが付く代わりに、もう一方が手薄になる。',
  ),
  const GlossaryEntry(
    term: 'ロール(プレースタイル)',
    category: GlossaryCategory.condition,
    description:
        'どの能力値を活かしたプレーを得意とするかを表す設定(プレーメイカー・ポーチャーなど)。ロールが重視する能力値が高い選手に割り当てるとボーナスが、低い選手に割り当てるとペナルティが付く。',
  ),
  const GlossaryEntry(
    term: 'ポジション適性・慣れ',
    category: GlossaryCategory.condition,
    description:
        '本職(主ポジション)以外で起用した際の習熟度(0-100)。出場を重ねるほど上昇し、本来のポジションとのギャップによる攻撃力・守備力ペナルティを徐々に軽減する。',
  ),
  const GlossaryEntry(
    term: '週俸',
    category: GlossaryCategory.contractTransfer,
    description: '選手に毎週支払う給料(万円)。契約更新の交渉で決まり、性格ごとの賃金感応度によって要求額が変わる。',
  ),
  const GlossaryEntry(
    term: '契約残り週数',
    category: GlossaryCategory.contractTransfer,
    description: '現在の契約が満了するまでの週数。0になると自由契約としてチームを去るため、事前の契約更新が必要になる。',
  ),
  const GlossaryEntry(
    term: '想定移籍金',
    category: GlossaryCategory.contractTransfer,
    description: '年齢・現在の総合力・伸びしろから概算した市場価値(万円)。移籍交渉時のオファー額の目安になる。',
  ),
  const GlossaryEntry(
    term: 'リリース条項',
    category: GlossaryCategory.contractTransfer,
    description: '設定されている場合、他クラブがこの金額(万円)を提示すると交渉なしで自動的に移籍が成立する。',
  ),
  const GlossaryEntry(
    term: '出場手当',
    category: GlossaryCategory.contractTransfer,
    description: '契約更新時に決定される手当(万円)。リーグ公式戦でスタメン出場するたびに支払われる。',
  ),
  const GlossaryEntry(
    term: 'サインボーナス',
    category: GlossaryCategory.contractTransfer,
    description: '契約更新時に一時金として支払う金額。性格ごとの賃金感応度に応じて要求されやすさが変わる。',
  ),
  const GlossaryEntry(
    term: '監督への信頼度',
    category: GlossaryCategory.club,
    description: '理事会からの信頼度(0-100)。目標順位を下回る成績が続くと下がり、0になると解任される。',
  ),
  const GlossaryEntry(
    term: '監督としての評価',
    category: GlossaryCategory.club,
    description:
        '世間からの監督としての評価(0-100)。信頼度と異なり解任されてもクラブを移っても引き継がれ、他クラブからの就任オファーの受けやすさに影響する。',
  ),
  const GlossaryEntry(
    term: '理事会の目標順位',
    category: GlossaryCategory.club,
    description: 'シーズン開始時に理事会から示される目標順位(1が最高位)。これを下回る成績が続くと信頼度が低下する。',
  ),
  const GlossaryEntry(
    term: 'プレッシング',
    category: GlossaryCategory.tactics,
    description: '守備時の寄せの強度(0-100)。高いほど相手の攻撃力を抑えられるが、選手の疲労が増えやすくなる。',
  ),
  const GlossaryEntry(
    term: 'ラインの高さ',
    category: GlossaryCategory.tactics,
    description: '守備ラインの高さ(0-100)。高いほど攻撃力にプラスに働くが、裏を突かれるリスクが高まる。',
  ),
  const GlossaryEntry(
    term: '攻撃の幅',
    category: GlossaryCategory.tactics,
    description: 'サイドをどれだけ広く使うか(0-100)。高いほど攻撃力が上がるが、中央の守備が薄くなる。',
  ),
  const GlossaryEntry(
    term: 'テンポ',
    category: GlossaryCategory.tactics,
    description: 'プレーの速さ(0-100)。高いほど攻撃力が上がるが、疲労が溜まりやすくなる。',
  ),
];
