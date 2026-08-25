import 'package:flutter/material.dart';
import '../models/player.dart';

/// ポジション大分類ごとの識別色（GK=黄, DEF=青, MID=緑, ATT=赤）。
/// スカッド・スタメン編成・移籍市場などで選手を素早く見分けられるようにする。
extension PositionGroupColor on PositionGroup {
  Color get color {
    switch (this) {
      case PositionGroup.gk:
        return Colors.amber.shade800;
      case PositionGroup.def:
        return Colors.blue.shade700;
      case PositionGroup.mid:
        return Colors.green.shade700;
      case PositionGroup.att:
        return Colors.red.shade700;
    }
  }
}

/// ポジション別カラーで彩色した円形アバター。
class PositionAvatar extends StatelessWidget {
  final Position position;
  final bool highlighted;

  const PositionAvatar({super.key, required this.position, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    final color = position.group.color;
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: highlighted ? 1 : 0.16),
      foregroundColor: highlighted ? Colors.white : color,
      child: Text(
        position.label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }
}
