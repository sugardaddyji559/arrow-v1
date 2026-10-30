import 'package:arrow_escape/core/app_colors.dart';
import 'package:arrow_escape/data/repositories/level_repository.dart';
import 'package:arrow_escape/data/repositories/progress_repository.dart';
import 'package:arrow_escape/screens/challenge/challenge_screen.dart';
import 'package:arrow_escape/screens/main_menu/main_menu_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final loader = FontLoader('Nunito');
    for (final weight in ['Regular', 'Bold', 'ExtraBold', 'Black']) {
      loader.addFont(rootBundle.load('assets/fonts/Nunito-$weight.ttf'));
    }
    await loader.load();
  });

  Future<void> capture(WidgetTester tester, String name, Widget screen) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'currentLevel': 26, 'highestUnlockedLevel': 26, 'streakDays': 1});
    AppColors.updateTheme(false);
    final prefs = await SharedPreferences.getInstance();
    final levels = LevelRepository(prefs);
    await levels.loadPregeneratedLevels();
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider(create: (_) => ProgressRepository(prefs)),
      Provider<LevelRepository>.value(value: levels),
    ], child: MaterialApp(theme: ThemeData(fontFamily: 'Nunito', scaffoldBackgroundColor: Colors.white), home: screen)));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
  }

  testWidgets('home snapshot', (tester) => capture(tester, 'home', const MainMenuScreen()));
  testWidgets('challenge snapshot', (tester) => capture(tester, 'challenge', DailyChallengeScreen(onHome: () {})));
  testWidgets('settings snapshot', (tester) => capture(tester, 'settings', const MainMenuScreen(initialTab: 3)));
}
