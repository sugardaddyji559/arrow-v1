import 'package:flutter/material.dart';

/// The shared mint, porcelain and ink palette used by every screen.
class AppColors {
  AppColors._();

  static bool isDark = false;
  static void updateTheme(bool dark) => isDark = dark;

  static Color get primary => isDark ? const Color(0xFF57D7B8) : const Color(0xFF24B99A);
  static Color get primaryLight => isDark ? const Color(0xFF203E37) : const Color(0xFFD8F2EA);
  static Color get primaryDark => isDark ? const Color(0xFF8AE8D0) : const Color(0xFF14977D);
  static Color get accent => primary;
  static Color get accentGold => const Color(0xFFF0A008);
  static Color get accentGreen => primary;
  static Color get accentOrange => accentGold;

  static Color get background => isDark ? const Color(0xFF131D21) : const Color(0xFFFFFFFF);
  static Color get surface => isDark ? const Color(0xFF1B282D) : const Color(0xFFFFFFFF);
  static Color get surfaceLight => isDark ? const Color(0xFF2C3D42) : const Color(0xFFE7ECEF);
  static Color get gridBg => background;
  static Color get ink => isDark ? const Color(0xFFEDF5F5) : const Color(0xFF142B35);

  static Color get arrowUp => ink;
  static Color get arrowDown => ink;
  static Color get arrowLeft => ink;
  static Color get arrowRight => ink;

  static Color get easy => primary;
  static Color get medium => const Color(0xFF4CA6D8);
  static Color get hard => accentGold;
  static Color get expert => const Color(0xFFE78151);
  static Color get master => const Color(0xFFAD83DA);

  static Color get textPrimary => ink;
  static Color get textSecondary => isDark ? const Color(0xFFB0C1C5) : const Color(0xFF858F96);
  static Color get textMuted => isDark ? const Color(0xFF8A9FA5) : const Color(0xFF9AA4AB);
  static Color get heartRed => const Color(0xFFFF4D68);
  static Color get heartEmpty => isDark ? const Color(0xFF35474D) : const Color(0xFFE7ECEF);
  static Color get streakFire => const Color(0xFFFF9B32);
  static Color get coinGold => const Color(0xFFEAB23C);
  static Color get starYellow => const Color(0xFFF5BB3D);
  static Color get borderGlow => primary;

  static const List<Color> _groupColorsLight = [
    Color(0xFFE50914), Color(0xFF0055FF), Color(0xFF00A859),
    Color(0xFF8E24AA), Color(0xFFFF6D00), Color(0xFF00B4D8),
    Color(0xFFFF2A8D), Color(0xFFFFA000), Color(0xFF558B2F),
    Color(0xFF00897B), Color(0xFF3D5AFE), Color(0xFFC2185B),
  ];
  static const List<Color> _groupColorsDark = [
    Color(0xFFFF647C), Color(0xFF69A0FF), Color(0xFF00E676),
    Color(0xFFD58AFF), Color(0xFFFFAB57), Color(0xFF00E5FF),
    Color(0xFFFF7FBA), Color(0xFFFFD600), Color(0xFFAEEA00),
    Color(0xFF1DE9B6), Color(0xFF9999FF), Color(0xFFFF70A8),
  ];

  static Color getGroupColor(int groupIndex) {
    final list = isDark ? _groupColorsDark : _groupColorsLight;
    return list[groupIndex % list.length];
  }

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: isDark ? const Color(0x28000000) : const Color(0x0A183B42),
      blurRadius: 22,
      offset: const Offset(0, 7),
    ),
  ];

  static List<BoxShadow> get buttonShadow => [
    BoxShadow(
      color: primary.withValues(alpha: isDark ? 0.10 : 0.22),
      blurRadius: 22,
      offset: const Offset(0, 9),
    ),
  ];

  // Flat fills keep the interface calm; these compatibility getters let older
  // game dialogs adopt the same palette without a second visual language.
  static LinearGradient get primaryGradient => LinearGradient(colors: [primary, primary]);
  static LinearGradient get secondaryGradient => LinearGradient(colors: [primaryLight, primaryLight]);
  static LinearGradient get bgGradient => LinearGradient(colors: [background, background]);
  static LinearGradient get successGradient => primaryGradient;
  static LinearGradient get dangerGradient => const LinearGradient(colors: [Color(0xFFEF6679), Color(0xFFEF6679)]);

  static Color difficultyColor(int level) {
    if (level <= 30) return primary;
    if (level <= 70) return medium;
    if (level <= 150) return hard;
    if (level <= 300) return expert;
    return master;
  }
}
