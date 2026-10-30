import 'package:arrow_escape/core/app_colors.dart';
import 'package:arrow_escape/data/models/arrow.dart';
import 'package:arrow_escape/data/models/level.dart';
import 'package:arrow_escape/data/repositories/level_repository.dart';
import 'package:arrow_escape/data/repositories/progress_repository.dart';
import 'package:arrow_escape/game/game_state.dart';
import 'package:arrow_escape/screens/challenge/challenge_screen.dart';
import 'package:arrow_escape/screens/main_menu/main_menu_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppColors.updateTheme(false);
  });

  Future<Widget> app(Widget child) async {
    final prefs = await SharedPreferences.getInstance();
    final levels = LevelRepository(prefs);
    await levels.loadPregeneratedLevels();
    return MultiProvider(providers: [
      ChangeNotifierProvider(create: (_) => ProgressRepository(prefs)),
      Provider<LevelRepository>.value(value: levels),
    ], child: MaterialApp(theme: ThemeData(fontFamily: 'Nunito'), home: child));
  }

  testWidgets('home navigation reaches all four reference-inspired destinations', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(await app(const MainMenuScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Tournament'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Challenge'));
    await tester.pumpAndSettle();
    expect(find.text(DateFormat('MMMM yyyy').format(DateTime.now())), findsOneWidget);

    await tester.tap(find.text('Collection'));
    await tester.pumpAndSettle();
    expect(find.text('Small wins. Well earned.'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Preferences'), findsOneWidget);
    expect(find.text('Account connection'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Continue'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings switches and volume update real preferences', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(await app(const MainMenuScreen(initialTab: 3)));
    await tester.pumpAndSettle();
    final context = tester.element(find.text('Preferences'));
    final progress = Provider.of<ProgressRepository>(context, listen: false);

    await tester.tap(find.byKey(const Key('dark-mode-switch')));
    await tester.pumpAndSettle();
    expect(progress.themeMode, ThemeMode.dark);
    await tester.tap(find.byKey(const Key('sounds-switch')));
    await tester.pumpAndSettle();
    expect(progress.soundEnabled, isFalse);
    tester.widget<Slider>(find.byType(Slider)).onChanged!(0.8);
    await tester.pumpAndSettle();
    expect(progress.musicVolume, 0.8);
    expect(find.text('80%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('calendar reflects completed days and disallows future months', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prefs = await SharedPreferences.getInstance();
    final progress = ProgressRepository(prefs);
    final now = DateTime.now();
    await progress.recordDailyChallenge(DateTime(now.year, now.month, now.day), 3, 100);
    final levels = LevelRepository(prefs);
    await levels.loadPregeneratedLevels();
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<ProgressRepository>.value(value: progress),
      Provider<LevelRepository>.value(value: levels),
    ], child: MaterialApp(home: Scaffold(body: DailyChallengeScreen(onHome: () {})))));
    await tester.pumpAndSettle();
    final days = DateTime(now.year, now.month + 1, 0).day;
    expect(find.text('1 / $days days'), findsOneWidget);
    final next = tester.widget<IconButton>(find.ancestor(of: find.byIcon(LucideIcons.chevronRight), matching: find.byType(IconButton)).first);
    expect(next.onPressed, isNull);
    expect(find.text('Play again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('challenge and tournament results persist without advancing the campaign', () async {
    final prefs = await SharedPreferences.getInstance();
    final progress = ProgressRepository(prefs);
    final date = DateTime(2026, 10, 30);
    expect(await progress.recordDailyChallenge(date, 3, 150), isTrue);
    expect(await progress.recordDailyChallenge(date, 1, 150), isFalse);
    expect(await progress.recordTournamentBest(26, 95), isTrue);
    expect(await progress.recordTournamentBest(26, 110), isFalse);
    expect(await progress.recordTournamentBest(26, 80), isTrue);
    await progress.setMusicVolume(0.75);
    await progress.setThemeMode(ThemeMode.dark);
    final restored = ProgressRepository(prefs);
    expect(restored.currentLevel, 1);
    expect(restored.highestUnlockedLevel, 1);
    expect(restored.isDailyChallengeComplete(date), isTrue);
    expect(restored.completedChallengesInMonth(date), 1);
    expect(restored.tournamentBestSeconds[26], 80);
    expect(restored.musicVolume, 0.75);
    expect(restored.themeMode, ThemeMode.dark);
    expect(restored.coins, 200);
    expect(ProgressRepository.dailyChallengeLevel(date), ProgressRepository.dailyChallengeLevel(date));
  });

  test('streak uses consecutive local calendar days', () async {
    var now = DateTime(2026, 10, 28, 23, 59);
    final progress = ProgressRepository(null, () => now);
    await progress.recordDailyPlay();
    expect(progress.streakDays, 1);
    now = DateTime(2026, 10, 29, 0, 1);
    await progress.recordDailyPlay();
    expect(progress.streakDays, 2);
    await progress.recordDailyPlay();
    expect(progress.streakDays, 2);
    now = DateTime(2026, 10, 31, 12);
    await progress.recordDailyPlay();
    expect(progress.streakDays, 1);
  });

  group('game interactions', () {
    ArrowModel arrow(String id, int row, int col, ArrowDirection direction, {List<List<int>>? path, int? group}) =>
      ArrowModel(id: id, row: row, col: col, direction: direction, path: path, colorGroup: group);
    LevelModel level(List<ArrowModel> arrows) => LevelModel(levelNumber: 1, gridSize: 5, arrows: arrows,
      patternName: 'test', difficulty: Difficulty.tutorial);
    GameState state(LevelModel level) => GameState(level: level,
      onLevelComplete: () {}, onGameOver: () {}, onLifeLost: () {}, onDeadlock: () {});

    test('hint only selects a legal arrow; blocked taps cost a heart; pause blocks input', () {
      final game = state(level([
        arrow('free', 2, 0, ArrowDirection.left, path: [[2, 0], [2, 1]]),
        arrow('blocked', 2, 4, ArrowDirection.left),
      ]));
      expect(game.nextSolvableArrowId, 'free');
      expect(game.isArrowBlocked('blocked'), isTrue);
      expect(game.tapArrow('blocked'), TapResult.blocked);
      expect(game.lives, 2);
      game.setPaused(true);
      expect(game.tapArrow('free'), TapResult.ignored);
      game.setPaused(false);
      expect(game.tapArrow('free'), TapResult.exited);
      game.resetLevel();
      expect(game.lives, 3);
      expect(game.movesUsed, 0);
      game.dispose();
    });

    test('a paired arrow can lead when its own exit is clear', () {
      final game = state(level([
        arrow('pair-a', 0, 0, ArrowDirection.up, path: [[0, 0], [1, 0]], group: 1),
        arrow('pair-b', 4, 4, ArrowDirection.left, group: 1),
        arrow('blocker', 4, 2, ArrowDirection.down),
      ]));
      expect(game.isArrowBlocked('pair-b'), isFalse);
      expect(game.nextSolvableArrowId, isNotNull);
      expect(game.tapArrow('pair-a'), TapResult.exited);
      expect(game.arrows.where((a) => a.colorGroup == 1).every((a) => a.state == ArrowState.sliding), isTrue);
      game.dispose();
    });
  });
}
