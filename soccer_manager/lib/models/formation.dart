import '../models/player.dart';

enum Formation { f442, f433, f352, f532 }

extension FormationInfo on Formation {
  String get label {
    switch (this) {
      case Formation.f442:
        return '4-4-2';
      case Formation.f433:
        return '4-3-3';
      case Formation.f352:
        return '3-5-2';
      case Formation.f532:
        return '5-3-2';
    }
  }

  int get df {
    switch (this) {
      case Formation.f442:
        return 4;
      case Formation.f433:
        return 4;
      case Formation.f352:
        return 3;
      case Formation.f532:
        return 5;
    }
  }

  int get mf {
    switch (this) {
      case Formation.f442:
        return 4;
      case Formation.f433:
        return 3;
      case Formation.f352:
        return 5;
      case Formation.f532:
        return 3;
    }
  }

  int get fw {
    switch (this) {
      case Formation.f442:
        return 2;
      case Formation.f433:
        return 3;
      case Formation.f352:
        return 2;
      case Formation.f532:
        return 2;
    }
  }

  int quotaFor(Position position) {
    switch (position) {
      case Position.gk:
        return 1;
      case Position.df:
        return df;
      case Position.mf:
        return mf;
      case Position.fw:
        return fw;
    }
  }

  double get attackBias {
    switch (this) {
      case Formation.f442:
        return 1.0;
      case Formation.f433:
        return 1.08;
      case Formation.f352:
        return 1.04;
      case Formation.f532:
        return 0.90;
    }
  }

  double get defenseBias {
    switch (this) {
      case Formation.f442:
        return 1.0;
      case Formation.f433:
        return 0.94;
      case Formation.f352:
        return 0.96;
      case Formation.f532:
        return 1.10;
    }
  }
}
