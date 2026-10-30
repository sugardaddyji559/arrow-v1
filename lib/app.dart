import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/app_colors.dart';
import 'data/repositories/progress_repository.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/main_menu/main_menu_screen.dart';
import 'screens/level_select/level_select_screen.dart';
import 'screens/game/game_screen.dart';
import 'screens/game_over/game_over_screen.dart';
import 'screens/tournament/tournament_screen.dart';

class ArrowPuzzleApp extends StatelessWidget {
  const ArrowPuzzleApp({super.key});

  ThemeData _theme(Brightness brightness) {
    final base = ThemeData(brightness: brightness, useMaterial3: true, fontFamily: 'Nunito');
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: brightness).copyWith(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.ink,
        outlineVariant: AppColors.surfaceLight,
      ),
      textTheme: base.textTheme.apply(fontFamily: 'Nunito', bodyColor: AppColors.ink, displayColor: AppColors.ink),
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkSparkle.splashFactory,
      dividerColor: AppColors.surfaceLight,
      dialogBackgroundColor: AppColors.surface,
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800),
        minimumSize: const Size(44, 44),
      )),
      tooltipTheme: TooltipThemeData(decoration: BoxDecoration(
        color: AppColors.ink, borderRadius: BorderRadius.circular(10))),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressRepository>();
    final themeMode = progress.themeMode;
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    AppColors.updateTheme(isDark);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: MaterialApp(
        title: 'Arrows — a little room to think',
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        initialRoute: '/splash',
        routes: {
          '/splash': (_) => const SplashScreen(),
          '/menu': (_) => const MainMenuScreen(),
          '/levels': (_) => const LevelSelectScreen(),
          '/game': (_) => const GameScreen(),
          '/game_over': (_) => const GameOverScreen(),
          '/settings': (_) => const MainMenuScreen(initialTab: 3),
          '/challenge': (_) => const MainMenuScreen(initialTab: 1),
          '/collection': (_) => const MainMenuScreen(initialTab: 2),
          '/tournament': (_) => const TournamentScreen(),
        },
      ),
    );
  }
}
