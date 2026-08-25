import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/game_state.dart';
import '../state/settings_controller.dart';
import 'onboarding_screen.dart';
import 'start_screen.dart';

/// 表示・操作設定とセーブデータ管理をまとめた画面。
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('表示', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _ThemeModeTile(
                  label: '端末の設定に合わせる',
                  mode: ThemeMode.system,
                  current: settings.themeMode,
                  onSelect: settings.setThemeMode,
                ),
                _ThemeModeTile(
                  label: 'ライトモード',
                  mode: ThemeMode.light,
                  current: settings.themeMode,
                  onSelect: settings.setThemeMode,
                ),
                _ThemeModeTile(
                  label: 'ダークモード',
                  mode: ThemeMode.dark,
                  current: settings.themeMode,
                  onSelect: settings.setThemeMode,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('文字サイズ'),
                      Text('${(settings.textScale * 100).round()}%'),
                    ],
                  ),
                  Slider(
                    value: settings.textScale,
                    min: SettingsController.minTextScale,
                    max: SettingsController.maxTextScale,
                    divisions: 9,
                    onChanged: (v) => settings.setTextScale(v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('サウンド・触覚', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('効果音'),
                  subtitle: const Text('得点・試合結果などで再生します'),
                  value: settings.soundEnabled,
                  onChanged: (v) => settings.setSoundEnabled(v),
                ),
                SwitchListTile(
                  title: const Text('触覚フィードバック'),
                  subtitle: const Text('ボタン操作や試合の展開に合わせて振動します'),
                  value: settings.hapticsEnabled,
                  onChanged: (v) => settings.setHapticsEnabled(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('ヘルプ', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.school_outlined),
              title: const Text('チュートリアルをもう一度見る'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OnboardingScreen(
                      onDone: () => Navigator.of(context).pop()),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('セーブデータ', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.copy_all_outlined),
                  title: const Text('セーブデータをコピー(バックアップ)'),
                  subtitle: const Text('クリップボードにJSON形式で書き出します'),
                  onTap: () => _exportSave(context),
                ),
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('セーブデータを復元'),
                  subtitle: const Text('コピーしたJSONを貼り付けて復元します'),
                  onTap: () => _importSave(context),
                ),
                ListTile(
                  leading:
                      const Icon(Icons.delete_forever, color: Colors.redAccent),
                  title: const Text('セーブデータを削除',
                      style: TextStyle(color: Colors.redAccent)),
                  subtitle: const Text('最初からやり直します。この操作は取り消せません'),
                  onTap: () => _confirmDelete(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportSave(BuildContext context) async {
    final gameState = context.read<GameState>();
    final json = gameState.exportSaveJson();
    if (json == null) return;
    await Clipboard.setData(ClipboardData(text: json));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('セーブデータをクリップボードにコピーしました')),
      );
    }
  }

  void _importSave(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('セーブデータを復元'),
        content: TextField(
          controller: controller,
          maxLines: 6,
          decoration: const InputDecoration(
              hintText: 'コピーしたJSONを貼り付けてください', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () async {
              final gameState = ctx.read<GameState>();
              final ok = await gameState.importSaveJson(controller.text.trim());
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(ok ? '復元しました' : '復元に失敗しました(形式を確認してください)')),
                );
              }
            },
            child: const Text('復元する'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('セーブデータを削除しますか？'),
        content: const Text('この操作は取り消せません。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          TextButton(
            onPressed: () async {
              final gameState = ctx.read<GameState>();
              await gameState.deleteSave();
              if (ctx.mounted) {
                Navigator.of(ctx).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const StartScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('削除する'),
          ),
        ],
      ),
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  final String label;
  final ThemeMode mode;
  final ThemeMode current;
  final ValueChanged<ThemeMode> onSelect;

  const _ThemeModeTile({
    required this.label,
    required this.mode,
    required this.current,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final selected = mode == current;
    return ListTile(
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
          : null,
      onTap: () => onSelect(mode),
    );
  }
}
