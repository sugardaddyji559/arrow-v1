import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../data/repositories/progress_repository.dart';
import '../../widgets/app_ui.dart';
import '../collection/collection_screen.dart';

class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressRepository>();
    return AppFrame(child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(22, 16, 22, 8), child: Row(children: [
        RoundIconButton(icon: LucideIcons.arrowLeft, label: 'Back',
          onPressed: () => Navigator.canPop(context) ? Navigator.pop(context) : Navigator.pushReplacementNamed(context, '/menu')),
        const SizedBox(width: 16),
        Expanded(child: Text('Your journey', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.ink))),
      ])),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12), child: Row(children: [
        Text('${progress.completedLevelCount} / 500 levels', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
        const Spacer(),
        Icon(Icons.star_rounded, size: 20, color: AppColors.starYellow),
        const SizedBox(width: 5),
        Text('${progress.totalStars}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.ink)),
      ])),
      const Expanded(child: LevelCollectionGrid()),
    ]));
  }
}
