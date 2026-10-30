import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../data/repositories/progress_repository.dart';
import '../../widgets/app_ui.dart';

class DailyChallengeScreen extends StatefulWidget {
  final VoidCallback onHome;
  const DailyChallengeScreen({super.key, required this.onHome});
  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen> {
  late DateTime _month;
  late DateTime _selected;
  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    _selected = _today;
    _month = DateTime(_today.year, _today.month);
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _selected = _month.year == _today.year && _month.month == _today.month
          ? _today : DateTime(_month.year, _month.month);
    });
  }

  Future<void> _play() async {
    final date = _selected;
    if (date.isAfter(_today)) return;
    await Navigator.pushNamed(context, '/game', arguments: {
      'level': ProgressRepository.dailyChallengeLevel(date),
      'challengeDate': ProgressRepository.dateKey(date),
      'mode': 'daily',
    });
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressRepository>();
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final offset = DateTime(_month.year, _month.month).weekday - 1;
    final rows = ((offset + daysInMonth) / 7).ceil();
    final completed = progress.completedChallengesInMonth(_month);
    final selectedDone = progress.isDailyChallengeComplete(_selected);
    final future = _selected.isAfter(_today);
    final canGoForward = _month.isBefore(DateTime(_today.year, _today.month));
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
      child: Column(children: [
        Row(children: [
          RoundIconButton(icon: LucideIcons.chevronLeft, label: 'Back to home', onPressed: widget.onHome),
          Expanded(child: Center(child: RewardArt(size: 116, earned: selectedDone))),
          const SizedBox(width: 52),
        ]),
        const SizedBox(height: 20),
        AppCard(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          child: Column(children: [
            ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(
              value: completed / daysInMonth, minHeight: 10,
              color: AppColors.primary, backgroundColor: AppColors.primaryLight,
            )),
            const SizedBox(height: 12),
            Text('$completed / $daysInMonth days', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: AppColors.ink)),
          ]),
        ),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          RoundIconButton(icon: LucideIcons.chevronLeft, label: 'Previous month', size: 40, iconSize: 20,
            color: Colors.transparent, iconColor: AppColors.textSecondary, onPressed: () => _changeMonth(-1)),
          Flexible(child: FittedBox(child: Text(DateFormat('MMMM yyyy').format(_month), style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: AppColors.primary)))),
          RoundIconButton(icon: LucideIcons.chevronRight, label: 'Next month', size: 40, iconSize: 20,
            color: Colors.transparent, iconColor: AppColors.textSecondary, onPressed: canGoForward ? () => _changeMonth(1) : null),
        ]),
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
          child: Column(children: [
            Row(children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((day) => Expanded(
              child: Center(child: FittedBox(child: Text(day, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textSecondary)))),
            )).toList()),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rows * 7,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1),
              itemBuilder: (context, index) {
                final day = index - offset + 1;
                if (day < 1 || day > daysInMonth) return const SizedBox.shrink();
                final date = DateTime(_month.year, _month.month, day);
                final done = progress.isDailyChallengeComplete(date);
                final isToday = date == _today;
                final isSelected = date == _selected;
                final isFuture = date.isAfter(_today);
                return Padding(padding: const EdgeInsets.all(3), child: Semantics(
                  button: true,
                  selected: isSelected,
                  label: '${DateFormat('MMMM d').format(date)}${done ? ', completed' : ''}${isFuture ? ', upcoming' : ''}',
                  child: Material(
                    color: done ? AppColors.primary : isSelected ? AppColors.primaryLight : Colors.transparent,
                    shape: CircleBorder(side: BorderSide(color: isSelected ? AppColors.primary : isToday ? AppColors.primary.withValues(alpha: .35) : Colors.transparent, width: 2)),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(onTap: () => setState(() => _selected = date), child: Center(
                      child: done ? Icon(LucideIcons.check, size: 21, color: isSelected ? Colors.white : AppColors.surface)
                        : Text('$day', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900,
                            color: isFuture ? AppColors.textMuted.withValues(alpha: .55) : AppColors.ink)),
                    )),
                  ),
                ));
              },
            ),
            if (completed == 0) Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('One puzzle a day. A little better every day.', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        FittedBox(child: Text(future ? 'A fresh puzzle is on its way' : '${DateFormat('MMMM d').format(_selected)} · Level ${ProgressRepository.dailyChallengeLevel(_selected)}',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textSecondary))),
        const SizedBox(height: 14),
        AppButton(label: future ? 'Not yet available' : selectedDone ? 'Play again' : 'Play', height: 66,
          onPressed: future ? null : _play),
        if (selectedDone) Padding(padding: const EdgeInsets.only(top: 14), child: Row(mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) => Icon(i < (progress.dailyChallengeStars[ProgressRepository.dateKey(_selected)] ?? 0) ? Icons.star_rounded : Icons.star_outline_rounded,
            color: AppColors.starYellow, size: 26)))),
      ]),
    );
  }
}
