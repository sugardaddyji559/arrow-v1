import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../widgets/app_ui.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) Navigator.pushReplacementNamed(context, '/menu');
    });
  }
  @override
  void dispose() { _timer?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const ArrowWordmark(size: 56),
      const SizedBox(height: 16),
      Text('A little room to think.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
      const SizedBox(height: 38),
      SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary)),
    ])),
  );
}
