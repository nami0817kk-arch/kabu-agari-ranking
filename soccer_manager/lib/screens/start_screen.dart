import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/league_theme.dart';
import '../state/game_state.dart';
import 'main_shell.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  final _controller = TextEditingController();
  LeagueTheme _theme = LeagueTheme.england;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = context.watch<GameState>();

    if (!gameState.initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sports_soccer, size: 72, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text('サッカー経営マネージャー', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'クラブを率いてリーグ優勝を目指そう',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (gameState.hasSave) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const MainShell()),
                      ),
                      child: Text('続きから (${gameState.save!.clubName})'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _confirmNewGame(context),
                      child: const Text('新しくクラブを作る'),
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'クラブ名',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('所属リーグ', style: Theme.of(context).textTheme.titleSmall),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: LeagueTheme.values
                        .map(
                          (theme) => ChoiceChip(
                            label: Text('${theme.label}（${theme.flavorLabel}）'),
                            selected: _theme == theme,
                            onSelected: (_) => setState(() => _theme = theme),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _createClub(context),
                      child: const Text('クラブ創設'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createClub(BuildContext context) async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    final gameState = context.read<GameState>();
    await gameState.startNewGame(name, theme: _theme);
    if (context.mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()));
    }
  }

  void _confirmNewGame(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新しいクラブを作りますか？'),
        content: const Text('既存のセーブデータは削除されます。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<GameState>().deleteSave();
            },
            child: const Text('削除して続ける'),
          ),
        ],
      ),
    );
  }
}
