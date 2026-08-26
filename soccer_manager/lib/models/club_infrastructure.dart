enum StaffRole { headCoach, scout, physio, youthCoach }

extension StaffRoleInfo on StaffRole {
  String get label => switch (this) {
        StaffRole.headCoach => 'ヘッドコーチ',
        StaffRole.scout => 'スカウト',
        StaffRole.physio => 'フィジオ',
        StaffRole.youthCoach => 'ユースコーチ',
      };

  String get description => switch (this) {
        StaffRole.headCoach => 'トレーニングの成長効率を高める',
        StaffRole.scout => 'スカウト選手の質を高め、費用を抑える',
        StaffRole.physio => '負傷の発生率と療養期間を減らす',
        StaffRole.youthCoach => 'アカデミー昇格候補の質を高める',
      };
}

enum FacilityType { trainingGround, stadium, youthFacility }

extension FacilityTypeInfo on FacilityType {
  String get label => switch (this) {
        FacilityType.trainingGround => 'トレーニング施設',
        FacilityType.stadium => 'スタジアム',
        FacilityType.youthFacility => 'ユース施設',
      };

  String get description => switch (this) {
        FacilityType.trainingGround => '選手の成長速度と疲労回復を高める',
        FacilityType.stadium => '試合ごとの観客収入を増やす',
        FacilityType.youthFacility => 'ユース昇格候補の受け入れ枠を増やす',
      };
}

/// クラブのスタッフ・施設レベル（1-5）。ユーザークラブにのみ適用される。
class ClubInfrastructure {
  static const int maxLevel = 5;

  final Map<StaffRole, int> staffLevels;
  final Map<FacilityType, int> facilityLevels;

  ClubInfrastructure({
    Map<StaffRole, int>? staffLevels,
    Map<FacilityType, int>? facilityLevels,
  })  : staffLevels = staffLevels ?? {for (final r in StaffRole.values) r: 1},
        facilityLevels =
            facilityLevels ?? {for (final f in FacilityType.values) f: 1};

  int staffLevel(StaffRole role) => staffLevels[role] ?? 1;
  int facilityLevel(FacilityType type) => facilityLevels[type] ?? 1;

  static int staffUpgradeCost(int currentLevel) => 250 * currentLevel;
  static int staffWeeklyWage(int level) => level * 20;
  static int facilityUpgradeCost(int currentLevel) =>
      500 * currentLevel * currentLevel;

  /// スタジアムのレベルに応じた収容人数。
  static int stadiumCapacity(int level) => 12000 + (level - 1) * 6000;

  int get totalStaffWeeklyWage =>
      staffLevels.values.fold<int>(0, (s, lvl) => s + staffWeeklyWage(lvl));

  bool upgradeStaff(StaffRole role) {
    final lvl = staffLevel(role);
    if (lvl >= maxLevel) return false;
    staffLevels[role] = lvl + 1;
    return true;
  }

  bool upgradeFacility(FacilityType type) {
    final lvl = facilityLevel(type);
    if (lvl >= maxLevel) return false;
    facilityLevels[type] = lvl + 1;
    return true;
  }

  Map<String, dynamic> toJson() => {
        'staffLevels': staffLevels.map((k, v) => MapEntry(k.name, v)),
        'facilityLevels': facilityLevels.map((k, v) => MapEntry(k.name, v)),
      };

  factory ClubInfrastructure.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ClubInfrastructure();
    final staffJson = json['staffLevels'] as Map<String, dynamic>?;
    final facilityJson = json['facilityLevels'] as Map<String, dynamic>?;
    return ClubInfrastructure(
      staffLevels: {
        for (final r in StaffRole.values) r: (staffJson?[r.name] as int?) ?? 1,
      },
      facilityLevels: {
        for (final f in FacilityType.values)
          f: (facilityJson?[f.name] as int?) ?? 1,
      },
    );
  }
}
