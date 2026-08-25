import '../models/player.dart';

enum Formation { f442, f433, f4231, f352 }

extension FormationInfo on Formation {
  String get label {
    switch (this) {
      case Formation.f442:
        return '4-4-2';
      case Formation.f433:
        return '4-3-3';
      case Formation.f4231:
        return '4-2-3-1';
      case Formation.f352:
        return '3-5-2';
    }
  }

  /// フォーメーションを構成する具体的な11ポジション。
  List<Position> get slots {
    switch (this) {
      case Formation.f442:
        return const [
          Position.gk,
          Position.dr, Position.dc, Position.dc, Position.dl,
          Position.mr, Position.mc, Position.mc, Position.ml,
          Position.st, Position.st,
        ];
      case Formation.f433:
        return const [
          Position.gk,
          Position.dr, Position.dc, Position.dc, Position.dl,
          Position.mc, Position.mc, Position.mc,
          Position.amr, Position.aml, Position.st,
        ];
      case Formation.f4231:
        return const [
          Position.gk,
          Position.dr, Position.dc, Position.dc, Position.dl,
          Position.dm, Position.dm,
          Position.amr, Position.amc, Position.aml,
          Position.st,
        ];
      case Formation.f352:
        return const [
          Position.gk,
          Position.dc, Position.dc, Position.dc,
          Position.wbr, Position.mc, Position.mc, Position.mc, Position.wbl,
          Position.st, Position.st,
        ];
    }
  }

  /// このフォーメーションで特定ポジションが必要な人数。
  int quotaFor(Position position) => slots.where((p) => p == position).length;

  double get attackBias {
    switch (this) {
      case Formation.f442:
        return 1.0;
      case Formation.f433:
        return 1.08;
      case Formation.f4231:
        return 0.98;
      case Formation.f352:
        return 1.05;
    }
  }

  double get defenseBias {
    switch (this) {
      case Formation.f442:
        return 1.0;
      case Formation.f433:
        return 0.94;
      case Formation.f4231:
        return 1.08;
      case Formation.f352:
        return 0.97;
    }
  }
}
