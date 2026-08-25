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
        'players': players.map((p) => p.toJson()).toList(),
      };

  factory Team.fromJson(Map<String, dynamic> json) => Team(
        id: json['id'] as String,
        name: json['name'] as String,
        isUserTeam: json['isUserTeam'] as bool? ?? false,
        formation: json['formation'] == null
            ? Formation.f442
            : Formation.values.byName(json['formation'] as String),
        startingXI: (json['startingXI'] as List?)?.map((e) => e as String).toList() ?? [],
        defaultTrainingFocus: json['defaultTrainingFocus'] == null
            ? TrainingFocus.rest
            : TrainingFocus.values.byName(json['defaultTrainingFocus'] as String),
        pressing: json['pressing'] as int? ?? 50,
        lineHeight: json['lineHeight'] as int? ?? 50,
        players: (json['players'] as List)
            .map((e) => Player.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
