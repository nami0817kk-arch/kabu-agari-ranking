import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/feedback_service.dart';
import 'state/game_state.dart';
import 'state/settings_controller.dart';
import 'screens/onboarding_screen.dart';
import 'screens/start_screen.dart';

void main() {
  runApp(const SoccerManagerApp());
}

class SoccerManagerApp extends StatelessWidget {
  const SoccerManagerApp({super.key});

  TextTheme _bolden(TextTheme t) {
    TextStyle? bump(TextStyle? s) => s?.copyWith(fontWeight: FontWeight.w700);
    return t.copyWith(
      displayLarge: bump(t.displayLarge),
      displayMedium: bump(t.displayMedium),
      displaySmall: bump(t.displaySmall),
      headlineLarge: bump(t.headlineLarge),
      headlineMedium: bump(t.headlineMedium),
      headlineSmall: bump(t.headlineSmall),
      titleLarge: bump(t.titleLarge),
      titleMedium: bump(t.titleMedium),
      titleSmall: bump(t.titleSmall),
      bodyLarge: bump(t.bodyLarge),
      bodyMedium: bump(t.bodyMedium),
      bodySmall: bump(t.bodySmall),
      labelLarge: bump(t.labelLarge),
      labelMedium: bump(t.labelMedium),
      labelSmall: bump(t.labelSmall),
    );
  }

  ThemeData _buildTheme(Brightness brightness, {required bool boldText}) {
    final base = ThemeData(
      colorSchemeSeed: const Color(0xFF1B5E3C),
      useMaterial3: true,
      brightness: brightness,
    );
    return base.copyWith(
      textTheme: boldText ? _bolden(base.textTheme) : base.textTheme,
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
        fillColor:
            base.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameState()..init()),
        ChangeNotifierProvider(create: (_) => SettingsController()..init()),
      ],
      child: Consumer<SettingsController>(
        builder: (context, settings, _) {
          FeedbackService.attach(settings);
          return MaterialApp(
            title: 'サッカー経営マネージャー',
            theme:
                _buildTheme(Brightness.light, boldText: settings.boldTextMode),
            darkTheme:
                _buildTheme(Brightness.dark, boldText: settings.boldTextMode),
            themeMode: settings.themeMode,
            builder: (context, child) {
              final mediaQuery = MediaQuery.of(context);
              return MediaQuery(
                data: mediaQuery.copyWith(
                  textScaler: TextScaler.linear(settings.textScale),
                ),
                child: child!,
              );
            },
            home: const _RootScreen(),
          );
        },
      ),
    );
  }
}

/// 設定・セーブデータの初期化が終わるまで待ち、初回起動ならチュートリアルを挟んでから
/// 通常のスタート画面へ進む。
class _RootScreen extends StatelessWidget {
  const _RootScreen();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final gameState = context.watch<GameState>();

    if (!settings.initialized || !gameState.initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!settings.hasSeenOnboarding) {
      return OnboardingScreen(
          onDone: () => settings.setHasSeenOnboarding(true));
    }
    return const StartScreen();
  }
}
