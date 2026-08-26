import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/attributes.dart';
import '../models/formation.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../logic/lineup_utils.dart';
import '../logic/rotation_engine.dart';
import '../services/feedback_service.dart';
import '../state/game_state.dart';
import '../theme/semantic_colors.dart';
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
          if (gameState.rotationSuggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _RotationSuggestionsCard(
                  suggestions: gameState.rotationSuggestions),
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
            child: _SetPieceTakersCard(team: team),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _TacticPresetsCard(team: team),
          ),
          const SizedBox(height: 8),
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
            child: _DepthChartSection(team: team),
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

/// 疲労が溜まったスタメンを、より疲労の少ないベンチ選手に入れ替える
/// ことを提案するカード。
class _RotationSuggestionsCard extends StatelessWidget {
  final List<RotationSuggestion> suggestions;
  const _RotationSuggestionsCard({required this.suggestions});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.battery_alert,
                    size: 18, color: Colors.orange.shade800),
                const SizedBox(width: 6),
                Text('疲労ローテーション提案',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: Colors.orange.shade900)),
              ],
            ),
            for (final s in suggestions)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${s.tiredPlayerName}(疲労${s.tiredFatigue}) → '
                        '${s.replacementName}(疲労${s.replacementFatigue})',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        FeedbackService.tap();
                        context.read<GameState>().swapStartingPlayer(
                            outPlayerId: s.tiredPlayerId,
                            inPlayerId: s.replacementId);
                      },
                      child: const Text('入れ替える'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// PK・直接FK・CKの担当選手を指名するカード。指名するとその場面で優先的に
/// 関わり、専門の能力値(PK・FK・CK)がチャンスの質に反映される。
class _SetPieceTakersCard extends StatelessWidget {
  final Team team;
  const _SetPieceTakersCard({required this.team});

  @override
  Widget build(BuildContext context) {
    final players = [...team.players]
      ..sort((a, b) => b.overall.compareTo(a.overall));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('セットプレー担当', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _TakerDropdown(
              label: 'PK',
              players: players,
              attributeKey: AttributeKeys.penalties,
              selectedId: team.penaltyTakerId,
              onChanged: (id) {
                FeedbackService.tap();
                context.read<GameState>().setPenaltyTaker(id);
              },
            ),
            _TakerDropdown(
              label: 'FK',
              players: players,
              attributeKey: AttributeKeys.freeKick,
              selectedId: team.freeKickTakerId,
              onChanged: (id) {
                FeedbackService.tap();
                context.read<GameState>().setFreeKickTaker(id);
              },
            ),
            _TakerDropdown(
              label: 'CK',
              players: players,
              attributeKey: AttributeKeys.corners,
              selectedId: team.cornerTakerId,
              onChanged: (id) {
                FeedbackService.tap();
                context.read<GameState>().setCornerTaker(id);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TakerDropdown extends StatelessWidget {
  final String label;
  final List<Player> players;
  final String attributeKey;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  const _TakerDropdown({
    required this.label,
    required this.players,
    required this.attributeKey,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 40, child: Text(label)),
        Expanded(
          child: DropdownButton<String?>(
            isExpanded: true,
            value: selectedId,
            hint: const Text('未指名'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('未指名')),
              for (final p in players)
                DropdownMenuItem<String?>(
                  value: p.id,
                  child: Text(
                      '${p.name}（$label ${p.attributeValue(attributeKey)}）',
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// 現在の戦術一式(フォーメーション・スライダー・セットプレー担当)を
/// 名前を付けて保存し、後から呼び出せるカード。
class _TacticPresetsCard extends StatelessWidget {
  final Team team;
  const _TacticPresetsCard({required this.team});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('戦術プリセット', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('現在の設定を保存'),
                  onPressed: () => _showSaveDialog(context),
                ),
              ],
            ),
            if (team.tacticPresets.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('保存済みのプリセットはありません',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final preset in team.tacticPresets)
                    InputChip(
                      label: Text('${preset.name}（${preset.formation.label}）'),
                      onPressed: () {
                        FeedbackService.tap();
                        context
                            .read<GameState>()
                            .applyTacticPreset(preset.name);
                      },
                      onDeleted: () {
                        FeedbackService.tap();
                        context
                            .read<GameState>()
                            .deleteTacticPreset(preset.name);
                      },
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSaveDialog(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('戦術プリセットを保存'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '名前(例: 守備固め)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !context.mounted) return;
    FeedbackService.tap();
    context.read<GameState>().saveTacticPreset(name);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「$name」を保存しました')),
      );
    }
  }
}

/// ポジションごとの控え順(デプスチャート)を一覧表示するセクション。
/// 各ポジションを主戦場とする選手を総合力順に並べ、出場できない状態の
/// 選手にはその理由を添える。
class _DepthChartSection extends StatelessWidget {
  final Team team;
  const _DepthChartSection({required this.team});

  @override
  Widget build(BuildContext context) {
    final byPosition = <Position, List<Player>>{};
    for (final p in team.players) {
      byPosition.putIfAbsent(p.position, () => []).add(p);
    }
    for (final list in byPosition.values) {
      list.sort((a, b) => b.overall.compareTo(a.overall));
    }

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text('デプスチャート(ポジション別控え順)',
            style: Theme.of(context).textTheme.titleSmall),
        children: [
          for (final pos in Position.values)
            if ((byPosition[pos] ?? []).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pos.fullLabel,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                    for (int i = 0; i < byPosition[pos]!.length; i++)
                      _DepthChartPlayerRow(
                          rank: i + 1, player: byPosition[pos]![i]),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _DepthChartPlayerRow extends StatelessWidget {
  final int rank;
  final Player player;
  const _DepthChartPlayerRow({required this.rank, required this.player});

  @override
  Widget build(BuildContext context) {
    final unavailable = player.isInjured
        ? '負傷中'
        : player.isSuspended
            ? '出場停止'
            : player.isOnInternationalDuty
                ? '代表招集中'
                : player.isLoanedOut
                    ? 'ローン中'
                    : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(
              width: 18,
              child: Text('$rank.', style: const TextStyle(fontSize: 12))),
          Expanded(
            child: Text('${player.name}（総合${player.overall}）',
                style: const TextStyle(fontSize: 12)),
          ),
          if (unavailable != null)
            Text(unavailable,
                style: TextStyle(
                    fontSize: 11, color: SemanticColors.negative(context))),
        ],
      ),
    );
  }
}

class _PitchView extends StatelessWidget {
  final Team team;
  final Formation formation;

  const _PitchView({required this.team, required this.formation});

  @override
  Widget build(BuildContext context) {
    final slots = formation.slots;
    final offsets = FormationLayout.offsetsFor(formation);
    final assignments = LineupUtils.resolveSlotAssignments(team);

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
        .where(
            (p) => !p.isInjured && !p.isOnInternationalDuty && !p.isSuspended)
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
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('ロール',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final role in PlayerRole.values.where((r) =>
                        r == PlayerRole.standard ||
                        r.allowedGroups.contains(current.position.group)))
                      ChoiceChip(
                        label: Text(role.label),
                        selected: current.role == role,
                        onSelected: (_) {
                          Navigator.pop(ctx);
                          FeedbackService.tap();
                          gameState.setPlayerRole(current.id, role);
                        },
                      ),
                  ],
                ),
              ),
              if (slotPosition != current.position)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    current.secondaryPositions.contains(slotPosition)
                        ? '本職外のポジションです(慣れ度 '
                            '${current.familiarityFor(slotPosition)}%。出場を重ねると上がります)'
                        : '本職から離れたポジションです(慣れ度 '
                            '${current.familiarityFor(slotPosition)}%。パフォーマンスが低下します)',
                    style: const TextStyle(fontSize: 12, color: Colors.orange),
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
    final outOfPosition = p != null && p.position != slotPosition;
    final roleSuffix =
        (p != null && p.role != PlayerRole.standard) ? '・${p.role.label}' : '';
    return Semantics(
      button: true,
      label: p == null
          ? '${slotPosition.fullLabel}: 空き枠'
          : '${slotPosition.fullLabel}: ${p.name}（${p.duty.label}$roleSuffix）'
              '${outOfPosition ? '。本職外(慣れ度${p.familiarityFor(slotPosition)}%)' : ''}',
      child: GestureDetector(
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
                        message: '${p.duty.label}$roleSuffix',
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
                  if (outOfPosition)
                    Positioned(
                      left: -2,
                      top: -2,
                      child: Tooltip(
                        message: '本職外(慣れ度${p.familiarityFor(slotPosition)}%)',
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.orange.shade700,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          child: const Icon(Icons.priority_high,
                              size: 8, color: Colors.white),
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
    final canAdd = !p.isInjured &&
        !p.isOnInternationalDuty &&
        !p.isSuspended &&
        currentInPosition < quota;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: ListTile(
        leading: PlayerFaceAvatar(playerId: p.id, position: p.position),
        title: Text(p.name),
        subtitle: Text(
          p.isInjured
              ? '負傷中（あと${p.injuryWeeks}週）'
              : p.isSuspended
                  ? '出場停止（あと${p.suspendedMatches}試合）'
                  : p.isOnInternationalDuty
                      ? '代表召集中（あと${p.internationalDutyWeeksRemaining}週）'
                      : '${p.age}歳 / 総合 ${p.overall}'
                          '${p.secondaryPositions.isEmpty ? '' : ' / 対応: ${p.secondaryPositions.map((s) => s.label).join(', ')}'}',
          style: (p.isInjured || p.isOnInternationalDuty || p.isSuspended)
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
