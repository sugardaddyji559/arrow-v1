import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/app_colors.dart';
import '../core/audio_manager.dart';

/// All main screens share a comfortable reading width on tablets and desktop.
class AppFrame extends StatelessWidget {
  final Widget child;
  final Widget? bottomNavigationBar;
  const AppFrame({super.key, required this.child, this.bottomNavigationBar});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: child,
        ),
      ),
    ),
    bottomNavigationBar: bottomNavigationBar == null ? null : SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: bottomNavigationBar!,
        ),
      ),
    ),
  );
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.radius = 26});

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.surfaceLight),
      boxShadow: AppColors.softShadow,
    ),
    child: child,
  );
}

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary;
  final bool loading;
  final double height;
  const AppButton({super.key, required this.label, this.onPressed, this.icon,
    this.secondary = false, this.loading = false, this.height = 60});

  @override
  Widget build(BuildContext context) {
    final color = secondary ? AppColors.primaryLight : AppColors.primary;
    final foreground = secondary ? AppColors.ink : Colors.white;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: onPressed == null ? 0.5 : 1,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
          boxShadow: secondary || onPressed == null ? null : AppColors.buttonShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: loading ? null : () {
              AudioManager.instance.playClick();
              onPressed?.call();
            },
            child: Center(
              child: loading
                ? SizedBox(width: 23, height: 23, child: CircularProgressIndicator(color: foreground, strokeWidth: 2.5))
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (icon != null) ...[Icon(icon, color: foreground, size: 22), const SizedBox(width: 10)],
                    Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: foreground, fontSize: 22, fontWeight: FontWeight.w900))),
                  ]),
            ),
          ),
        ),
      ),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? iconColor;
  final double size;
  final double iconSize;
  final bool shadow;
  final Widget? badge;
  const RoundIconButton({super.key, required this.icon, required this.label,
    this.onPressed, this.color, this.iconColor, this.size = 52,
    this.iconSize = 25, this.shadow = false, this.badge});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: SizedBox(width: size, height: size,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          decoration: BoxDecoration(
            color: color ?? AppColors.primaryLight,
            shape: BoxShape.circle,
            boxShadow: shadow ? AppColors.softShadow : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(color: Colors.transparent, child: IconButton(
            tooltip: label,
            onPressed: onPressed == null ? null : () {
              AudioManager.instance.playClick();
              onPressed!();
            },
            icon: Icon(icon, size: iconSize, color: iconColor ?? AppColors.ink),
          )),
        ),
        if (badge != null) Positioned(top: -5, right: -5, child: badge!),
      ]),
    ),
  );
}

class ArrowWordmark extends StatelessWidget {
  final double size;
  const ArrowWordmark({super.key, this.size = 48});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Arrows',
    child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
      Icon(LucideIcons.arrowUpRight, color: AppColors.primary, size: size * 1.05),
      Text('rrows', style: TextStyle(fontSize: size, height: 1.1,
        fontWeight: FontWeight.w900, letterSpacing: -2.2, color: AppColors.ink)),
    ]),
  );
}

class StreakPill extends StatelessWidget {
  final int days;
  final VoidCallback? onTap;
  const StreakPill({super.key, required this.days, this.onTap});
  @override
  Widget build(BuildContext context) => Tooltip(
    message: '$days day play streak',
    child: Material(color: AppColors.surface, borderRadius: BorderRadius.circular(999),
      child: InkWell(borderRadius: BorderRadius.circular(999), onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: AppColors.surfaceLight)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('🔥', style: TextStyle(fontSize: 25)),
            const SizedBox(width: 11),
            Text('$days', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: AppColors.ink)),
          ]),
        ),
      ),
    ),
  );
}

class MintSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;
  const MintSwitch({super.key, required this.value, required this.onChanged, required this.label});
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    toggled: value,
    child: Switch.adaptive(
      value: value,
      activeThumbColor: AppColors.primary,
      activeTrackColor: AppColors.primary,
      inactiveThumbColor: AppColors.surface,
      inactiveTrackColor: AppColors.primaryLight,
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      onChanged: onChanged == null ? null : (v) {
        AudioManager.instance.playClick();
        if (context.mounted) {
          // Respect the existing haptic preference through the caller.
          onChanged!(v);
        }
      },
    ),
  );
}

class BottomNavigation extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onTap;
  final bool showCollectionDot;
  const BottomNavigation({super.key, required this.selected, required this.onTap, this.showCollectionDot = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
    child: AppCard(
      radius: 28,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
      child: Row(children: [
        _item(0, LucideIcons.house, 'Home'),
        _item(1, LucideIcons.calendarDays, 'Challenge'),
        _item(2, LucideIcons.star, 'Collection'),
        _item(3, LucideIcons.settings, 'Settings'),
      ]),
    ),
  );

  Widget _item(int index, IconData icon, String label) {
    final active = selected == index;
    return Expanded(child: Semantics(
      selected: active,
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(21),
        onTap: () {
          AudioManager.instance.playClick();
          onTap(index);
        },
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 68, height: 42,
            decoration: BoxDecoration(color: active ? AppColors.primaryLight : Colors.transparent, borderRadius: BorderRadius.circular(19)),
            child: Stack(alignment: Alignment.center, children: [
              Icon(icon, size: 27, color: active ? AppColors.primary : AppColors.ink),
              if (index == 2 && showCollectionDot) Positioned(top: 4, right: 13,
                child: Container(width: 6, height: 6, decoration: BoxDecoration(color: AppColors.heartRed, shape: BoxShape.circle))),
            ]),
          ),
          const SizedBox(height: 4),
          FittedBox(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
            color: active ? AppColors.primary : AppColors.ink))),
        ]),
      ),
    ));
  }
}

void showAppMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      duration: const Duration(seconds: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ));
}

Future<void> showAppSheet(BuildContext context, {required String title, required Widget child}) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: AppColors.surface,
  isScrollControlled: true,
  showDragHandle: true,
  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
  builder: (context) => SafeArea(child: SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(26, 2, 26, 28),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.ink)),
      const SizedBox(height: 18),
      child,
    ]),
  )),
);

/// Original, resolution-independent illustrations. No remote image dependency.
class RewardArt extends StatelessWidget {
  final bool shield;
  final double size;
  final bool earned;
  const RewardArt({super.key, this.shield = false, this.size = 112, this.earned = true});
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: shield ? _ShieldPainter() : _TrophyPainter(earned: earned),
  );
}

class _TrophyPainter extends CustomPainter {
  final bool earned;
  _TrophyPainter({required this.earned});
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 120, size.height / 120);
    final ceramic = LinearGradient(
      begin: Alignment.centerLeft, end: Alignment.centerRight,
      colors: earned ? [const Color(0xFFFFE7A0), const Color(0xFFFFC94E), const Color(0xFFE5A52A)]
        : [const Color(0xFFF8F9F8), const Color(0xFFE2E5E4), const Color(0xFFFAFBFA), const Color(0xFFD5DAD9)],
    ).createShader(const Rect.fromLTWH(15, 10, 90, 105));
    final paint = Paint()..shader = ceramic;
    final edge = Paint()..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round..shader = ceramic;
    canvas.drawPath(Path()..moveTo(31, 24)..cubicTo(2, 13, 9, 60, 37, 57), edge);
    canvas.drawPath(Path()..moveTo(89, 24)..cubicTo(118, 13, 111, 60, 83, 57), edge);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(53, 61, 14, 28), const Radius.circular(5)), paint);
    canvas.drawOval(Rect.fromLTWH(38, 85, 44, 10), paint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(31, 94, 58, 12), const Radius.circular(4)), paint);
    canvas.drawPath(Path()..moveTo(27, 17)..lineTo(93, 17)..cubicTo(94, 54, 82, 72, 60, 73)..cubicTo(38, 72, 26, 54, 27, 17), paint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(24, 12, 72, 10), const Radius.circular(5)), paint);
    final emboss = Paint()..color = earned ? const Color(0xFFB98023).withValues(alpha: .4) : const Color(0xFFBFC7C5).withValues(alpha: .55);
    // A little pumpkin embossed into the seasonal cup.
    canvas.drawOval(const Rect.fromLTWH(44, 32, 32, 26), emboss);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(58, 27, 5, 8), const Radius.circular(2)), emboss);
    final cut = Paint()..color = earned ? const Color(0xFFFFDB76) : const Color(0xFFE9ECEB);
    canvas.drawPath(Path()..moveTo(49, 42)..lineTo(54, 37)..lineTo(56, 43)..close(), cut);
    canvas.drawPath(Path()..moveTo(64, 43)..lineTo(67, 37)..lineTo(71, 42)..close(), cut);
    canvas.drawPath(Path()..moveTo(50, 48)..lineTo(56, 51)..lineTo(60, 48)..lineTo(64, 51)..lineTo(71, 47)..quadraticBezierTo(61, 62, 50, 48), cut);
    canvas.drawArc(const Rect.fromLTWH(31, 21, 30, 43), math.pi * .6, math.pi * .65, false,
      Paint()..color = Colors.white.withValues(alpha: .5)..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeCap = StrokeCap.round);
  }
  @override
  bool shouldRepaint(_TrophyPainter old) => old.earned != earned;
}

class _ShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 120, size.height / 120);
    final shield = Path()..moveTo(60, 8)..cubicTo(75, 19, 88, 21, 103, 23)..lineTo(100, 63)..cubicTo(97, 85, 78, 102, 60, 112)..cubicTo(42, 102, 23, 85, 20, 63)..lineTo(17, 23)..cubicTo(34, 21, 47, 17, 60, 8)..close();
    canvas.drawPath(shield, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFFFFDE64), Color(0xFFF6B72C), Color(0xFFD98A13)]).createShader(const Rect.fromLTWH(15, 8, 90, 104)));
    canvas.save();canvas.translate(60, 59);canvas.scale(.83, .83);canvas.translate(-60, -59);
    canvas.drawPath(shield, Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFFFFD858), Color(0xFFFFBB28), Color(0xFFF1A51E)]).createShader(const Rect.fromLTWH(15, 8, 90, 104)));
    canvas.restore();
    final arrow = Path()..moveTo(37, 76)..lineTo(65, 48)..lineTo(52, 47)..lineTo(54, 34)..lineTo(88, 32)..lineTo(86, 66)..lineTo(73, 68)..lineTo(74, 55)..lineTo(46, 84)..close();
    canvas.drawPath(arrow, Paint()..shader = const LinearGradient(begin: Alignment.bottomLeft, end: Alignment.topRight,
      colors: [Color(0xFF6950DC), Color(0xFFE94D9B), Color(0xFFF38B49), Color(0xFF77C96B), Color(0xFF23BFA5)]).createShader(const Rect.fromLTWH(35, 30, 55, 55)));
    canvas.drawPath(Path()..moveTo(24, 29)..lineTo(27, 61)..cubicTo(29, 77, 40, 91, 51, 98),
      Paint()..color = Colors.white.withValues(alpha: .30)..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeCap = StrokeCap.round);
  }
  @override
  bool shouldRepaint(_ShieldPainter old) => false;
}

void tapFeedback(bool vibration) {
  if (vibration) HapticFeedback.selectionClick();
}
