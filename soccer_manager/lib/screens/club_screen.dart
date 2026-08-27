import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/club_infrastructure.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../widgets/quick_access_drawer.dart';
import '../widgets/responsive_body.dart';

class ClubScreen extends StatelessWidget {
  const ClubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final save = gameState.save!;
    final infra = save.infrastructure;
    final totalLevels = [
      ...StaffRole.values.map(infra.staffLevel),
      ...FacilityType.values.map(infra.facilityLevel)
    ].fold<int>(0, (s, l) => s + l);
    final maxTotalLevels =
        (StaffRole.values.length + FacilityType.values.length) *
            ClubInfrastructure.maxLevel;

    return Scaffold(
      appBar: AppBar(title: const Text('クラブ施設・スタッフ')),
      drawer: const QuickAccessDrawer(),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('資金: ${save.budget}万円',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text('スタッフ週俸合計: ${infra.totalStaffWeeklyWage}万円',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: totalLevels / maxTotalLevels,
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('充実度 $totalLevels/$maxTotalLevels',
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('スタッフ', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final role in StaffRole.values)
              _UpgradeCard(
                title: role.label,
                description: role.description,
                level: infra.staffLevel(role),
                cost: gameState.staffUpgradeCostFor(role),
                costLabel: '雇用費',
                extraLabel:
                    '週俸 ${ClubInfrastructure.staffWeeklyWage(infra.staffLevel(role))}万円',
                canAfford: save.budget >= gameState.staffUpgradeCostFor(role),
                onUpgrade: () => gameState.upgradeStaff(role),
              ),
            const Divider(height: 32),
            Text('施設', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final type in FacilityType.values)
              _UpgradeCard(
                title: type.label,
                description: type.description,
                level: infra.facilityLevel(type),
                cost: gameState.facilityUpgradeCostFor(type),
                costLabel: '建設費',
                extraLabel: type == FacilityType.stadium
                    ? '収容人数 ${ClubInfrastructure.stadiumCapacity(infra.facilityLevel(type))}人'
                        ' (平均動員目安 ${gameState.expectedAttendance}人)'
                    : null,
                canAfford:
                    save.budget >= gameState.facilityUpgradeCostFor(type),
                onUpgrade: () => gameState.upgradeFacility(type),
              ),
          ],
        ),
      ),
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  final String title;
  final String description;
  final int level;
  final int cost;
  final String costLabel;
  final String? extraLabel;
  final bool canAfford;
  final Future<bool> Function() onUpgrade;

  const _UpgradeCard({
    required this.title,
    required this.description,
    required this.level,
    required this.cost,
    required this.costLabel,
    this.extraLabel,
    required this.canAfford,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    const maxLevel = ClubInfrastructure.maxLevel;
    final isMax = level >= maxLevel;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                Row(
                  children: List.generate(
                    maxLevel,
                    (i) => Icon(
                      i < level ? Icons.star : Icons.star_border,
                      size: 16,
                      color: Colors.amber,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(description,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            if (extraLabel != null) ...[
              const SizedBox(height: 2),
              Text(extraLabel!,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: isMax || !canAfford
                    ? null
                    : () async {
                        final ok = await onUpgrade();
                        ok
                            ? FeedbackService.success()
                            : FeedbackService.error();
                      },
                child: Text(isMax ? '最大レベル' : '$costLabel $cost万円でアップグレード'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
