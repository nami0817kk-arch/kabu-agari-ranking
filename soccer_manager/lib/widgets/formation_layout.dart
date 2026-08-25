import 'package:flutter/material.dart';
import '../models/formation.dart';

/// フォーメーションごとの選手配置座標(正規化: x=0左タッチライン〜1右タッチライン、
/// y=0自陣ゴール〜1相手ゴール)。[Formation.slots]と同じ並び順。
class FormationLayout {
  static const Map<Formation, List<Offset>> _layouts = {
    Formation.f442: [
      Offset(0.5, 0.06), // GK
      Offset(0.85, 0.22), Offset(0.62, 0.18), Offset(0.38, 0.18), Offset(0.15, 0.22), // DR DC DC DL
      Offset(0.85, 0.55), Offset(0.62, 0.5), Offset(0.38, 0.5), Offset(0.15, 0.55), // MR MC MC ML
      Offset(0.62, 0.85), Offset(0.38, 0.85), // ST ST
    ],
    Formation.f433: [
      Offset(0.5, 0.06),
      Offset(0.85, 0.22), Offset(0.62, 0.18), Offset(0.38, 0.18), Offset(0.15, 0.22),
      Offset(0.5, 0.42), Offset(0.7, 0.55), Offset(0.3, 0.55),
      Offset(0.8, 0.78), Offset(0.2, 0.78), Offset(0.5, 0.88),
    ],
    Formation.f4231: [
      Offset(0.5, 0.06),
      Offset(0.85, 0.22), Offset(0.62, 0.18), Offset(0.38, 0.18), Offset(0.15, 0.22),
      Offset(0.62, 0.4), Offset(0.38, 0.4),
      Offset(0.8, 0.65), Offset(0.5, 0.6), Offset(0.2, 0.65),
      Offset(0.5, 0.88),
    ],
    Formation.f352: [
      Offset(0.5, 0.06),
      Offset(0.7, 0.18), Offset(0.5, 0.14), Offset(0.3, 0.18),
      Offset(0.88, 0.48), Offset(0.65, 0.5), Offset(0.5, 0.42), Offset(0.35, 0.5), Offset(0.12, 0.48),
      Offset(0.62, 0.85), Offset(0.38, 0.85),
    ],
  };

  static List<Offset> offsetsFor(Formation formation) => _layouts[formation]!;
}
