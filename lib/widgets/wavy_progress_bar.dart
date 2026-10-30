import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// A quiet, animated progress track. Keeping the original widget API makes the
/// game header usable at any width without an always-running wave ticker.
class WavyProgressBar extends StatelessWidget {
  final double progress;
  final double width;
  final double height;
  const WavyProgressBar({super.key, required this.progress, this.width = 100, this.height = 8});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: Semantics(
      label: 'Board ${(progress * 100).round()} percent complete',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: progress.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => LinearProgressIndicator(
            value: value,
            minHeight: height,
            color: AppColors.primary,
            backgroundColor: AppColors.primaryLight,
          ),
        ),
      ),
    ),
  );
}
