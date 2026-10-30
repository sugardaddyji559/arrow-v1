import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../data/repositories/progress_repository.dart';
import '../../widgets/app_ui.dart';

class TournamentScreen extends StatefulWidget {
  const TournamentScreen({super.key});
  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> {
  int _selected = 1;
  static const _levels = [4, 26, 74];
  static const _labels = ['Easy', 'Medium', 'Hard'];
  static const _seconds = [90, 180, 300];

  String _format(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressRepository>();
    final best = progress.tournamentBestSeconds[_levels[_selected]];
    return AppFrame(child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
      child: Column(children: [
        Row(children: [
          RoundIconButton(icon: LucideIcons.arrowLeft, label: 'Back to home',
            onPressed: () => Navigator.canPop(context) ? Navigator.pop(context) : Navigator.pushReplacementNamed(context, '/menu')),
          Expanded(child: Text('Tournament', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.ink))),
          const SizedBox(width: 52),
        ]),
        const SizedBox(height: 28),
        const RewardArt(shield: true, size: 154),
        const SizedBox(height: 20),
        Text('Your next personal best', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 30, height: 1.15, fontWeight: FontWeight.w900, color: AppColors.ink, letterSpacing: -.7)),
        const SizedBox(height: 12),
        Text('One board. One clock.\nFind your flow and beat your own time.', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, height: 1.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        const SizedBox(height: 30),
        AppCard(child: Column(children: [
          Row(children: List.generate(3, (i) => Expanded(child: Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 5, right: i == 2 ? 0 : 5),
            child: ChoiceChip(label: SizedBox(width: double.infinity, child: Text(_labels[i], textAlign: TextAlign.center)),
              selected: _selected == i, showCheckmark: false,
              labelStyle: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w900, color: _selected == i ? Colors.white : AppColors.textSecondary),
              selectedColor: AppColors.primary, backgroundColor: AppColors.primaryLight.withValues(alpha: .4),
              side: BorderSide.none, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              onSelected: (_) => setState(() => _selected = i)),
          )))),
          const SizedBox(height: 24),
          _detail(LucideIcons.layoutGrid, 'Board', 'Level ${_levels[_selected]}'),
          const SizedBox(height: 16),
          _detail(LucideIcons.timer, 'Time limit', _format(_seconds[_selected])),
          const SizedBox(height: 16),
          _detail(LucideIcons.trophy, 'Your best', best == null ? 'Set your first time' : _format(best)),
        ])),
        const SizedBox(height: 28),
        AppButton(label: 'Start run', height: 66, onPressed: () => Navigator.pushNamed(context, '/game', arguments: {
          'level': _levels[_selected], 'mode': 'tournament', 'timeLimit': _seconds[_selected],
        })),
        const SizedBox(height: 22),
        Text('A solo time attack. Your best times stay on this device.\nClear the board before the clock runs out.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
      ]),
    ));
  }

  Widget _detail(IconData icon, String label, String value) => Row(children: [
    Icon(icon, color: AppColors.primary, size: 21),
    const SizedBox(width: 12),
    Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
    const Spacer(),
    Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.ink)),
  ]);
}
