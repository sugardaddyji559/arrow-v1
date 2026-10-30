import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../data/repositories/progress_repository.dart';
import '../../widgets/app_ui.dart';

class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressRepository>();
    return DefaultTabController(length: 2, child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(22, 24, 22, 0), child: Column(children: [
        Row(children: [
          Icon(LucideIcons.star, color: AppColors.primary, size: 31),
          const SizedBox(width: 12),
          Expanded(child: Text('Collection', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.ink, letterSpacing: -.8))),
        ]),
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerLeft, child: Text('Small wins. Well earned.', style: TextStyle(fontSize: 16, color: AppColors.textSecondary, fontWeight: FontWeight.w700))),
        const SizedBox(height: 24),
        AppCard(child: Row(children: [
          _stat('${progress.completedLevelCount}', 'Levels cleared'),
          _stat('${progress.totalStars}', 'Stars earned'),
          _stat('${progress.dailyChallengeStars.length}', 'Challenges'),
        ])),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(color: AppColors.primaryLight.withValues(alpha: .5), borderRadius: BorderRadius.circular(999)),
          child: TabBar(
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(999), boxShadow: AppColors.softShadow),
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: const TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w900),
            tabs: const [Tab(text: 'Levels', height: 42), Tab(text: 'Awards', height: 42)],
          ),
        ),
      ])),
      Expanded(child: TabBarView(children: [
        const LevelCollectionGrid(),
        ListView(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
          children: [
            _award(context, 'First escape', 'Clear your first level', progress.completedLevelCount, 1),
            _award(context, 'Finding your flow', 'Clear 10 levels', progress.completedLevelCount, 10),
            _award(context, 'Perfectly clear', 'Earn 3 stars on 10 levels', progress.perfectLevelCount, 10),
            _award(context, 'A week of play', 'Visit 7 days in a row', progress.streakDays, 7),
            _award(context, 'Puzzle collector', 'Clear 50 levels', progress.completedLevelCount, 50),
            _award(context, 'Daily ritual', 'Complete 10 daily challenges', progress.dailyChallengeStars.length, 10),
            _award(context, 'The long game', 'Clear 100 levels', progress.completedLevelCount, 100),
          ],
        ),
      ])),
    ]));
  }

  Widget _stat(String value, String label) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: AppColors.primary)),
    const SizedBox(height: 3),
    FittedBox(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textSecondary))),
  ]));

  Widget _award(BuildContext context, String title, String detail, int value, int target) {
    final earned = value >= target;
    return Padding(padding: const EdgeInsets.only(bottom: 14), child: AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        RewardArt(size: 60, earned: earned),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink)),
          const SizedBox(height: 4),
          Text(detail, style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(
            value: (value / target).clamp(0, 1), minHeight: 5,
            color: AppColors.primary, backgroundColor: AppColors.primaryLight,
          )),
        ])),
        const SizedBox(width: 14),
        Icon(earned ? LucideIcons.check : LucideIcons.lock, size: 19, color: earned ? AppColors.primary : AppColors.textMuted),
      ]),
    ));
  }
}

class _LevelTile extends StatelessWidget {
  final int level;
  final ProgressRepository progress;
  const _LevelTile({required this.level, required this.progress});
  @override
  Widget build(BuildContext context) {
    final unlocked = progress.isLevelUnlocked(level);
    final stars = progress.getStarsForLevel(level);
    final current = level == progress.currentLevel;
    return Tooltip(
      message: unlocked ? 'Play level $level' : 'Clear the previous levels to unlock',
      child: Material(
        color: current ? AppColors.primaryLight : AppColors.surface,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: unlocked ? () => Navigator.pushNamed(context, '/game', arguments: {'level': level})
            : () => showAppMessage(context, 'Clear the previous levels to unlock level $level.'),
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(17), border: Border.all(
              color: current ? AppColors.primary : AppColors.surfaceLight, width: current ? 2 : 1)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (!unlocked) Icon(LucideIcons.lock, size: 18, color: AppColors.textMuted)
              else Text('$level', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.ink)),
              const SizedBox(height: 5),
              if (unlocked) Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(3, (i) => Icon(
                i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 12, color: i < stars ? AppColors.starYellow : AppColors.textMuted))),
            ]),
          ),
        ),
      ),
    );
  }
}

class LevelCollectionGrid extends StatelessWidget {
  const LevelCollectionGrid({super.key});
  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressRepository>();
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5,
        mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: .82),
      itemCount: 500,
      itemBuilder: (context, index) => _LevelTile(level: index + 1, progress: progress),
    );
  }
}
