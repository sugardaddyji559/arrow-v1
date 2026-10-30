import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class LivesBar extends StatelessWidget {
  final int lives;
  final int maxLives;
  const LivesBar({super.key, required this.lives, required this.maxLives});

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$lives of $maxLives hearts remaining',
    child: Row(mainAxisSize: MainAxisSize.min, children: List.generate(maxLives, (i) {
      final full = i < lives;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
          child: Icon(full ? Icons.favorite_rounded : Icons.favorite_rounded,
            key: ValueKey(full), size: 29, color: full ? AppColors.heartRed : AppColors.heartEmpty),
        ),
      );
    })),
  );
}
