import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'state/game_state.dart';
import 'screens/start_screen.dart';

void main() {
  runApp(const SoccerManagerApp());
}

class SoccerManagerApp extends StatelessWidget {
  const SoccerManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GameState()..init(),
      child: MaterialApp(
        title: 'サッカー経営マネージャー',
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF1B5E3C),
          useMaterial3: true,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: const Color(0xFF1B5E3C),
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        home: const StartScreen(),
      ),
    );
  }
}
