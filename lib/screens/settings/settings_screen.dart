import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_colors.dart';
import '../../core/audio_manager.dart';
import '../../core/constants.dart';
import '../../data/repositories/progress_repository.dart';
import '../../widgets/app_ui.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  static const _privacyPolicyUrl = 'https://gxdevs.blogspot.com/2026/07/arrow-escape-privacy-policy.html';
  static const _playStoreUrl = 'https://play.google.com/store/apps/details?id=${AppConstants.packageId}';

  Future<void> _launchUrl(BuildContext context, String url) async {
    AudioManager.instance.playClick();
    try {
      final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) showAppMessage(context, 'This link could not be opened.');
    } catch (_) {
      if (context.mounted) showAppMessage(context, 'This link is not available on this device.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressRepository>();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Text('Settings', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: AppColors.ink, letterSpacing: -.8))),
        const SizedBox(height: 30),
        const _SectionLabel('Preferences'),
        const SizedBox(height: 12),
        AppCard(padding: const EdgeInsets.symmetric(horizontal: 18), child: Column(children: [
          _SettingsRow(icon: LucideIcons.globe, label: 'Language',
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('English', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
              const SizedBox(width: 5),
              Icon(LucideIcons.chevronRight, size: 21, color: AppColors.textSecondary),
            ]),
            onTap: () => showAppSheet(context, title: 'App language', child: Column(children: [
              AppCard(child: Row(children: [
                Expanded(child: Text('English', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink))),
                Icon(LucideIcons.check, color: AppColors.primary),
              ])),
              const SizedBox(height: 18),
              Text('English is the available language in this version. More languages are coming in a future update.',
                style: TextStyle(fontSize: 15, height: 1.5, color: AppColors.textSecondary)),
              const SizedBox(height: 22),
              AppButton(label: 'Done', onPressed: () => Navigator.pop(context)),
            ]))),
          const _SettingsDivider(),
          _SettingsRow(icon: LucideIcons.vibrate, label: 'Vibrations', trailing: MintSwitch(key: const Key('vibrations-switch'),
            value: progress.vibrationEnabled, label: 'Vibrations', onChanged: (v) {
              progress.setVibrationEnabled(v);
              if (v) HapticFeedback.selectionClick();
            })),
          const _SettingsDivider(),
          _SettingsRow(icon: LucideIcons.volume2, label: 'Sounds', trailing: MintSwitch(key: const Key('sounds-switch'),
            value: progress.soundEnabled, label: 'Sounds', onChanged: progress.setSoundEnabled)),
          const _SettingsDivider(),
          _SettingsRow(icon: LucideIcons.music, label: 'Music', trailing: MintSwitch(key: const Key('music-switch'),
            value: progress.musicEnabled, label: 'Background music', onChanged: progress.setMusicEnabled)),
          const _SettingsDivider(),
          SizedBox(height: 72, child: Row(children: [
            Icon(LucideIcons.music, size: 26, color: AppColors.primary),
            const SizedBox(width: 16),
            Expanded(child: SliderTheme(
              data: SliderTheme.of(context).copyWith(trackHeight: 5, overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10), activeTrackColor: AppColors.primary,
                inactiveTrackColor: AppColors.surfaceLight, thumbColor: AppColors.primary),
              child: Slider(value: progress.musicVolume, label: '${(progress.musicVolume * 100).round()}%',
                semanticFormatterCallback: (v) => 'Music volume ${(v * 100).round()} percent',
                onChanged: progress.musicEnabled ? progress.setMusicVolume : null),
            )),
            SizedBox(width: 43, child: Text('${(progress.musicVolume * 100).round()}%', textAlign: TextAlign.end,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textSecondary))),
          ])),
          const _SettingsDivider(),
          _SettingsRow(icon: LucideIcons.moon, label: 'Dark mode', trailing: MintSwitch(key: const Key('dark-mode-switch'),
            value: AppColors.isDark, label: 'Dark mode', onChanged: (v) => progress.setThemeMode(v ? ThemeMode.dark : ThemeMode.light))),
        ])),
        const SizedBox(height: 28),
        const _SectionLabel('Account'),
        const SizedBox(height: 12),
        AppCard(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(LucideIcons.userRound, color: AppColors.primary, size: 27),
            const SizedBox(width: 14),
            Expanded(child: Text('Account connection', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.ink))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(999)),
              child: Text('Local save', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primaryDark))),
          ]),
          const SizedBox(height: 18),
          Text('Your progress is saved on this device. Google sign-in and cross-device sync aren’t configured in this build.',
            style: TextStyle(fontSize: 15, height: 1.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        ])),
        const SizedBox(height: 28),
        const _SectionLabel('About'),
        const SizedBox(height: 12),
        AppCard(padding: const EdgeInsets.symmetric(horizontal: 18), child: Column(children: [
          _SettingsRow(icon: LucideIcons.shieldCheck, label: 'Privacy policy',
            trailing: Icon(LucideIcons.chevronRight, color: AppColors.textSecondary, size: 21), onTap: () => _launchUrl(context, _privacyPolicyUrl)),
          const _SettingsDivider(),
          _SettingsRow(icon: LucideIcons.star, label: 'Rate the app',
            trailing: Icon(LucideIcons.chevronRight, color: AppColors.textSecondary, size: 21), onTap: () => _launchUrl(context, _playStoreUrl)),
        ])),
        const SizedBox(height: 24),
        Center(child: FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) => Text(snapshot.hasData ? '${AppConstants.appName} · v${snapshot.data!.version}' : AppConstants.appName,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
        )),
      ]),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(left: 8),
    child: Text(text, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textSecondary)));
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();
  @override
  Widget build(BuildContext context) => Divider(height: 1, thickness: 1, indent: 44, color: AppColors.surfaceLight);
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;
  const _SettingsRow({required this.icon, required this.label, required this.trailing, this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: SizedBox(height: 72, child: Row(children: [
      Icon(icon, color: AppColors.primary, size: 26),
      const SizedBox(width: 16),
      Expanded(child: Text(label, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.ink))),
      trailing,
    ])),
  );
}
