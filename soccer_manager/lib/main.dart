import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'state/game_state.dart';
import 'screens/start_screen.dart';

void main() {
  runApp(const SoccerManagerApp());
}

class SoccerManagerApp extends StatelessWidget {
  const SoccerManagerApp({super.key});

  ThemeData _buildTheme(Brightness brightness) {
    final base = ThemeData(
      colorSchemeSeed: const Color(0xFF1B5E3C),
      useMaterial3: true,
      brightness: brightness,
    );
    return base.copyWith(
      cardTheme: CardThemeData(
        elevation: 0,
        color: base.colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.only(bottom: 12),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: base.colorScheme.surface,
        foregroundColor: base.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: base.colorScheme.surfaceContainer,
        indicatorColor: base.colorScheme.primaryContainer,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: base.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GameState()..init(),
      child: MaterialApp(
        title: 'サッカー経営マネージャー',
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        home: const StartScreen(),
      ),
    );
  }
}
