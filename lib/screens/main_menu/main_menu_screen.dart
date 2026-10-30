import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/audio_manager.dart';
import '../../core/constants.dart';
import '../../data/models/level.dart';
import '../../data/repositories/level_repository.dart';
import '../../data/repositories/progress_repository.dart';
import '../../widgets/app_ui.dart';
import '../../widgets/unified_banner_ad.dart';
import '../challenge/challenge_screen.dart';
import '../collection/collection_screen.dart';
import '../settings/settings_screen.dart';

class MainMenuScreen extends StatefulWidget {
  final int initialTab;
  const MainMenuScreen({super.key, this.initialTab = 0});
  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  late int _selectedTab;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab.clamp(0, 3);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final progress = context.read<ProgressRepository>();
      progress.recordDailyPlay();
      if (_selectedTab == 2) progress.markCollectionSeen();
      final repository = context.read<LevelRepository>();
      for (var i = 0; i < 4; i++) {
        repository.preGenerateAsync(progress.currentLevel + i);
      }
      _checkPlayStoreUpdate();
    });
  }

  Future<void> _checkPlayStoreUpdate() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        if (info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        } else if (info.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate();
          await InAppUpdate.completeFlexibleUpdate();
        }
      }
    } catch (e) {
      debugPrint('Play Store update check failed: $e');
    }
  }

  void _selectTab(int index) {
    setState(() => _selectedTab = index);
    if (index == 2) context.read<ProgressRepository>().markCollectionSeen();
    if (context.read<ProgressRepository>().vibrationEnabled) {
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _playCampaign() async {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);
    await Navigator.pushNamed(context, '/game', arguments: {
      'level': context.read<ProgressRepository>().currentLevel,
    });
    if (mounted) setState(() => _isNavigating = false);
  }

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressRepository>();
    return AppFrame(
      bottomNavigationBar: BottomNavigation(
        selected: _selectedTab,
        onTap: _selectTab,
        showCollectionDot: progress.hasNewCollection,
      ),
      child: switch (_selectedTab) {
        1 => DailyChallengeScreen(onHome: () => _selectTab(0)),
        2 => const CollectionScreen(),
        3 => const SettingsScreen(),
        _ => _home(progress),
      },
    );
  }

  Widget _home(ProgressRepository progress) {
    final now = DateTime.now();
    final level = progress.currentLevel;
    final difficulty = AppConstants.levelTypeFor(level).isSpecial
        ? AppConstants.levelTypeFor(level).label
        : Difficulty.forLevel(level).label;
    final hasAds = AppConstants.enableAdMob || AppConstants.enableUnityAds;
    return LayoutBuilder(builder: (context, constraints) => SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: SizedBox(
        height: math.max(constraints.maxHeight, hasAds ? 750 : 690),
        child: Column(children: [
          const SizedBox(height: 16),
          StreakPill(days: progress.streakDays, onTap: () => _showStreak(progress)),
          const SizedBox(height: 26),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _FeatureCard(
              title: 'Challenge',
              subtitle: DateFormat('MMMM d').format(now),
              child: RewardArt(earned: progress.isDailyChallengeComplete(now), size: 108),
              onPlay: () => _selectTab(1),
            )),
            const SizedBox(width: 14),
            const Expanded(child: _FeatureCard(
              title: 'Tournament',
              subtitle: 'Beat your best',
              child: RewardArt(shield: true, size: 108),
              route: '/tournament',
            )),
          ]),
          const Spacer(flex: 3),
          GestureDetector(
            onLongPress: () {
              progress.toggleDemoMode();
              showAppMessage(context, progress.isDemoMode ? 'Demo mode enabled' : 'Demo mode disabled');
            },
            child: const ArrowWordmark(size: 49),
          ),
          const SizedBox(height: 10),
          if (level > 500)
            Text('All levels complete!', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: AppColors.primary))
          else ...[
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/levels'),
              child: Text('Level $level', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.primary)),
            ),
            const SizedBox(height: 2),
            Text(difficulty, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: AppColors.difficultyColor(level))),
            if (progress.isDemoMode) ...[
              const SizedBox(height: 6),
              Text('DEMO MODE', style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: AppColors.textMuted, fontWeight: FontWeight.w900)),
            ],
          ],
          const Spacer(flex: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AppButton(
              label: level > 500 ? 'Explore levels' : 'Continue',
              height: 66,
              loading: _isNavigating,
              onPressed: level > 500 ? () => Navigator.pushNamed(context, '/levels') : _playCampaign,
            ),
          ),
          const Spacer(flex: 4),
          if (hasAds) const SizedBox(height: 50, child: UnifiedBannerAd(
            admobUnitId: AppConstants.admobBannerUnitId,
            unityPlacementId: AppConstants.unityBannerAdId,
          )),
        ]),
      ),
    ));
  }

  void _showStreak(ProgressRepository progress) {
    AudioManager.instance.playClick();
    showAppSheet(context, title: 'Keep your spark', child: Column(children: [
      const Text('🔥', style: TextStyle(fontSize: 64)),
      const SizedBox(height: 10),
      Text('${progress.streakDays} day${progress.streakDays == 1 ? '' : 's'} in a row',
        style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: AppColors.ink)),
      const SizedBox(height: 10),
      Text('Visit each day to grow your streak. Take on today’s challenge and make a little progress.',
        textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 16, height: 1.5)),
      const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(LucideIcons.coins, color: AppColors.coinGold),
        const SizedBox(width: 8),
        Text('${progress.coins} coins earned', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
      ]),
      const SizedBox(height: 24),
      AppButton(label: 'Today’s challenge', onPressed: () { Navigator.pop(context); _selectTab(1); }),
    ]));
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onPlay;
  final String? route;
  const _FeatureCard({required this.title, required this.subtitle, required this.child, this.onPlay, this.route});
  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
    child: Column(children: [
      FittedBox(child: Text(title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.ink, letterSpacing: -.6))),
      const SizedBox(height: 5),
      FittedBox(child: Text(subtitle, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
      const SizedBox(height: 13),
      child,
      const SizedBox(height: 16),
      AppButton(label: 'Play', height: 46, onPressed: onPlay ?? () => Navigator.pushNamed(context, route!)),
    ]),
  );
}
