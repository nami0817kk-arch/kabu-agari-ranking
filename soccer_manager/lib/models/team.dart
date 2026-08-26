import 'formation.dart';
import 'player.dart';
import 'training_focus.dart';

class Team {
  final String id;
  String name;
  List<Player> players;
  final bool isUserTeam;
  Formation formation;

  /// 現在の先発11人（Player.id）。フォーメーションの人数配分と一致する。
  List<String> startingXI;

  /// 個別方針を設定していない選手に適用されるチーム既定のトレーニング方針。
  TrainingFocus defaultTrainingFocus;

  /// プレッシングの強度（0-100）。高いほど守備が強まるが疲労が増えやすい。
  int pressing;

  /// 守備ラインの高さ（0-100）。高いほど攻撃的だが裏を突かれやすい。
  int lineHeight;

  /// 攻撃の幅（0-100）。高いほどサイドを広く使い攻撃力が上がるが、中央の守備が薄くなる。
  int width;

  /// プレーのテンポ（0-100）。高いほど攻撃的だが疲労が溜まりやすい。
  int tempo;

  /// キャプテン・副キャプテンの選手ID(未指名の場合はnull)。
  String? captainId;
  String? viceCaptainId;

  /// セットプレー担当の選手ID(未指名の場合はnull)。指名されていれば
  /// 該当する場面で優先的にボールに関わる(PK・FKは優先的に打ち、
  /// CKはキッカーの精度がチャンスの質に反映される)。
  String? penaltyTakerId;
  String? freeKickTakerId;
  String? cornerTakerId;

  Team({
    required this.id,
    required this.name,
    required this.players,
    this.isUserTeam = false,
    this.formation = Formation.f442,
    List<String>? startingXI,
    this.defaultTrainingFocus = TrainingFocus.rest,
    this.pressing = 50,
    this.lineHeight = 50,
    this.width = 50,
    this.tempo = 50,
    this.captainId,
    this.viceCaptainId,
    this.penaltyTakerId,
    this.freeKickTakerId,
    this.cornerTakerId,
  }) : startingXI = startingXI ?? [];

  int get overallRating {
    if (players.isEmpty) return 0;
    final sum = players.fold<int>(0, (s, p) => s + p.overall);
    return (sum / players.length).round();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isUserTeam': isUserTeam,
        'formation': formation.name,
        'startingXI': startingXI,
        'defaultTrainingFocus': defaultTrainingFocus.name,
        'pressing': pressing,
        'lineHeight': lineHeight,
        'width': width,
        'tempo': tempo,
        'captainId': captainId,
        'viceCaptainId': viceCaptainId,
        'penaltyTakerId': penaltyTakerId,
        'freeKickTakerId': freeKickTakerId,
        'cornerTakerId': cornerTakerId,
        'players': players.map((p) => p.toJson()).toList(),
      };

  factory Team.fromJson(Map<String, dynamic> json) => Team(
        id: json['id'] as String,
        name: json['name'] as String,
        isUserTeam: json['isUserTeam'] as bool? ?? false,
        formation: _parseFormation(json['formation'] as String?),
        startingXI:
            (json['startingXI'] as List?)?.map((e) => e as String).toList() ??
                [],
        defaultTrainingFocus: json['defaultTrainingFocus'] == null
            ? TrainingFocus.rest
            : TrainingFocus.values
                .byName(json['defaultTrainingFocus'] as String),
        pressing: json['pressing'] as int? ?? 50,
        lineHeight: json['lineHeight'] as int? ?? 50,
        width: json['width'] as int? ?? 50,
        tempo: json['tempo'] as int? ?? 50,
        captainId: json['captainId'] as String?,
        viceCaptainId: json['viceCaptainId'] as String?,
        penaltyTakerId: json['penaltyTakerId'] as String?,
        freeKickTakerId: json['freeKickTakerId'] as String?,
        cornerTakerId: json['cornerTakerId'] as String?,
        players: (json['players'] as List)
            .map((e) => Player.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// 廃止されたフォーメーション名（旧f532など）のセーブでもクラッシュしないようにする。
  static Formation _parseFormation(String? name) {
    if (name == null) return Formation.f442;
    for (final f in Formation.values) {
      if (f.name == name) return f;
    }
    return Formation.f442;
  }
}
