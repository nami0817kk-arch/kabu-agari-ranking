import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/formation.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../widgets/formation_layout.dart';
import '../widgets/player_face_avatar.dart';

class LineupScreen extends StatelessWidget {
  const LineupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final team = gameState.userTeam;
    final formation = team.formation;
    final bench = team.players
        .where((p) => !team.startingXI.contains(p.id))
        .toList()
      ..sort((a, b) => a.position.index.compareTo(b.position.index));

    return Scaffold(
      appBar: AppBar(title: const Text('スタメン・戦術')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Text('フォーメーション: '),
                const SizedBox(width: 8),
                DropdownButton<Formation>(
                  value: formation,
                  items: Formation.values
                      .map((f) =>
                          DropdownMenuItem(value: f, child: Text(f.label)))
                      .toList(),
                  onChanged: (f) {
                    if (f != null) {
                      FeedbackService.tap();
                      context.read<GameState>().setFormation(f);
                    }
                  },
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text('攻撃 x${formation.attackBias.toStringAsFixed(2)}'),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
                Chip(
                  label:
                      Text('守備 x${formation.defenseBias.toStringAsFixed(2)}'),
                  visualDensity: VisualDensity.compact,
                ),
                const Spacer(),
                Text('${team.startingXI.length}/11'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 90, child: Text('プレッシング')),
                        Expanded(
                          child: Slider(
                            value: team.pressing.toDouble(),
                            min: 0,
                            max: 100,
                            divisions: 10,
                            label: '${team.pressing}',
                            onChanged: (v) => context
                                .read<GameState>()
                                .setPressing(v.round()),
                          ),
                        ),
                        SizedBox(width: 32, child: Text('${team.pressing}')),
                      ],
                    ),
                    Row(
                      children: [
                        const SizedBox(width: 90, child: Text('ライン高さ')),
                        Expanded(
                          child: Slider(
                            value: team.lineHeight.toDouble(),
                            min: 0,
                            max: 100,
                            divisions: 10,
                            label: '${team.lineHeight}',
                            onChanged: (v) => context
                                .read<GameState>()
                                .setLineHeight(v.round()),
                          ),
                        ),
                        SizedBox(width: 32, child: Text('${team.lineHeight}')),
                      ],
                    ),
                    Row(
                      children: [
                        const SizedBox(width: 90, child: Text('攻撃の幅')),
                        Expanded(
                          child: Slider(
                            value: team.width.toDouble(),
                            min: 0,
                            max: 100,
                            divisions: 10,
                            label: '${team.width}',
                            onChanged: (v) =>
                                context.read<GameState>().setWidth(v.round()),
                          ),
                        ),
                        SizedBox(width: 32, child: Text('${team.width}')),
                      ],
                    ),
                    Row(
                      children: [
                        const SizedBox(width: 90, child: Text('テンポ')),
                        Expanded(
                          child: Slider(
                            value: team.tempo.toDouble(),
                            min: 0,
                            max: 100,
                            divisions: 10,
                            label: '${team.tempo}',
                            onChanged: (v) =>
                                context.read<GameState>().setTempo(v.round()),
                          ),
                        ),
                        SizedBox(width: 32, child: Text('${team.tempo}')),
                      ],
                    ),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'プレッシングは守備を高めるが疲労が増えやすい。ラインを上げると攻撃的になるが裏を突かれやすい。\n'
                        '幅を広げると攻撃力が増すが中央の守備が薄くなる。テンポを上げると攻撃的だが疲労が増えやすい。',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                OutlinedButton(
                  onPressed: () {
                    FeedbackService.tap();
                    context.read<GameState>().autoFillStartingXI();
                  },
                  child: const Text('自動編成'),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('選手をタップして入れ替え',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AspectRatio(
              aspectRatio: 0.72,
              child: _PitchView(team: team, formation: formation),
            ),
          ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('ベンチ', style: Theme.of(context).textTheme.titleSmall),
          ),
          for (final p in bench) _BenchTile(playerId: p.id),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// スタメン11人をフォーメーションのスロット順に割り当てる。
/// 完全一致がいない枠(グループ代用など)は残りの先発から総合力順に補う。
List<Player?> _resolveSlotAssignments(Team team, Formation formation) {
  final byId = {for (final p in team.players) p.id: p};
  final startingPlayers =
      team.startingXI.map((id) => byId[id]).whereType<Player>().toList();

  final remainingByPosition = <Position, List<Player>>{};
  for (final p in startingPlayers) {
    remainingByPosition.putIfAbsent(p.position, () => []).add(p);
  }
  for (final list in remainingByPosition.values) {
    list.sort((a, b) => b.overall.compareTo(a.overall));
  }

  final slots = formation.slots;
  final assignments = <Player?>[];
  for (final slotPos in slots) {
    final list = remainingByPosition[slotPos];
    if (list != null && list.isNotEmpty) {
      assignments.add(list.removeAt(0));
    } else {
      assignments.add(null);
    }
  }

  final leftovers = remainingByPosition.values.expand((l) => l).toList()
    ..sort((a, b) => b.overall.compareTo(a.overall));
  for (int i = 0; i < assignments.length; i++) {
    if (assignments[i] == null && leftovers.isNotEmpty) {
      assignments[i] = leftovers.removeAt(0);
    }
  }
  return assignments;
}

class _PitchView extends StatelessWidget {
  final Team team;
  final Formation formation;

  const _PitchView({required this.team, required this.formation});

  @override
  Widget build(BuildContext context) {
    final slots = formation.slots;
    final offsets = FormationLayout.offsetsFor(formation);
    final assignments = _resolveSlotAssignments(team, formation);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return CustomPaint(
            painter: _PitchPainter(),
            child: Stack(
              children: [
                for (int i = 0; i < slots.length; i++)
                  Positioned(
                    left: (offsets[i].dx * w - 26).clamp(0, w - 52),
                    top: (offsets[i].dy * h - 26).clamp(0, h - 52),
                    child: _SlotChip(
                      slotPosition: slots[i],
                      player: assignments[i],
                      onTap: () =>
                          _showSlotSheet(context, slots[i], assignments[i]),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSlotSheet(
      BuildContext context, Position slotPosition, Player? current) {
    final gameState = context.read<GameState>();
    final candidates = team.players
        .where((p) => !p.isInjured && !p.isOnInternationalDuty)
        .where((p) => p.id != current?.id)
        .where((p) =>
            p.position == slotPosition ||
            p.secondaryPositions.contains(slotPosition) ||
            p.position.group == slotPosition.group)
        .toList()
      ..sort((a, b) => b.overall.compareTo(a.overall));

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('${slotPosition.fullLabel}(${slotPosition.label})に配置',
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
            if (current != null) ...[
              ListTile(
                leading: const Icon(Icons.remove_circle_outline,
                    color: Colors.redAccent),
                title: const Text('この枠を空ける'),
                onTap: () {
                  Navigator.pop(ctx);
                  FeedbackService.tap();
                  gameState.toggleStartingPlayer(current.id);
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final duty in PlayerDuty.values)
                      ChoiceChip(
                        label: Text(duty.label),
                        selected: current.duty == duty,
                        onSelected: (_) {
                          Navigator.pop(ctx);
                          FeedbackService.tap();
                          gameState.setPlayerDuty(current.id, duty);
                        },
                      ),
                  ],
                ),
              ),
              const Divider(),
            ],
            for (final p in candidates)
              ListTile(
                leading: PlayerFaceAvatar(playerId: p.id, position: p.position),
                title: Text(p.name),
                subtitle: Text('${p.position.label} / 総合 ${p.overall}'),
                onTap: () {
                  Navigator.pop(ctx);
                  FeedbackService.tap();
                  gameState.swapStartingPlayer(
                      outPlayerId: current?.id, inPlayerId: p.id);
                },
              ),
            if (candidates.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('交代できる選手がいません'),
              ),
          ],
        ),
      ),
    );
  }
}

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF2E7D32);
    canvas.drawRect(Offset.zero & size, bg);

    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(Rect.fromLTWH(4, 4, size.width - 8, size.height - 8), line);
    canvas.drawLine(Offset(4, size.height / 2),
        Offset(size.width - 4, size.height / 2), line);
    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2), size.width * 0.16, line);

    final boxW = size.width * 0.55;
    final boxH = size.height * 0.12;
    canvas.drawRect(
        Rect.fromLTWH(size.width / 2 - boxW / 2, 4, boxW, boxH), line);
    canvas.drawRect(
      Rect.fromLTWH(
          size.width / 2 - boxW / 2, size.height - 4 - boxH, boxW, boxH),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Color _dutyColor(PlayerDuty duty) => switch (duty) {
      PlayerDuty.defend => Colors.blue.shade300,
      PlayerDuty.support => Colors.grey.shade400,
      PlayerDuty.attack => Colors.orange.shade400,
    };

class _SlotChip extends StatelessWidget {
  final Position slotPosition;
  final Player? player;
  final VoidCallback onTap;

  const _SlotChip(
      {required this.slotPosition, required this.player, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = player;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 52,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                p == null
                    ? CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white.withValues(alpha: 0.3),
                        child: Text(slotPosition.label,
                            style: const TextStyle(
                                fontSize: 10, color: Colors.white)),
                      )
                    : PlayerFaceAvatar(
                        playerId: p.id,
                        position: p.position,
                        size: 36,
                        highlighted: true),
                if (p != null)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Tooltip(
                      message: p.duty.label,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _dutyColor(p.duty),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                p == null ? '空き' : p.name.split(' ').last,
                style: const TextStyle(fontSize: 10, color: Colors.white),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenchTile extends StatelessWidget {
  final String playerId;

  const _BenchTile({required this.playerId});

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();
    final team = gameState.userTeam;
    final p = team.players.firstWhere((pl) => pl.id == playerId);
    final quota = team.formation.quotaFor(p.position);
    final currentInPosition = team.startingXI
        .map((id) => team.players.firstWhere((pl) => pl.id == id))
        .where((pl) => pl.position == p.position)
        .length;
    final canAdd =
        !p.isInjured && !p.isOnInternationalDuty && currentInPosition < quota;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: ListTile(
        leading: PlayerFaceAvatar(playerId: p.id, position: p.position),
        title: Text(p.name),
        subtitle: Text(
          p.isInjured
              ? '負傷中（あと${p.injuryWeeks}週）'
              : p.isOnInternationalDuty
                  ? '代表召集中（あと${p.internationalDutyWeeksRemaining}週）'
                  : '${p.age}歳 / 総合 ${p.overall}'
                      '${p.secondaryPositions.isEmpty ? '' : ' / 対応: ${p.secondaryPositions.map((s) => s.label).join(', ')}'}',
          style: (p.isInjured || p.isOnInternationalDuty)
              ? const TextStyle(color: Colors.redAccent)
              : null,
        ),
        trailing: OutlinedButton(
          onPressed: canAdd
              ? () {
                  FeedbackService.tap();
                  context.read<GameState>().toggleStartingPlayer(p.id);
                }
              : null,
          child: const Text('スタメンへ'),
        ),
      ),
    );
  }
}
