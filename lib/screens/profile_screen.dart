import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_settings.dart';
import '../models/user_profile.dart';
import '../services/player_controller.dart';
import '../services/settings_controller.dart';
import '../widgets/glass.dart';
import '../widgets/profile_id_card.dart';
import 'audio_lab_screen.dart';
import 'customisation_screen.dart';

/// Faithful Mochy-Music inspired Profile Screen (100% Lemielmusic brand):
/// - Dotted charcoal header container with giant faint watermark & matte ID card
/// - Pure black #000000 canvas below with borderless #121215 rounded 24px cards
/// - Big editorial stats, Liquid Glass / Classic theme switch, Audio Lab, and
///   Version & Developer About card (with Facebook, Instagram, GitHub).
class ProfileScreen extends StatefulWidget {
  final PlayerController controller;
  final SettingsController settingsController;

  const ProfileScreen({
    super.key,
    required this.controller,
    required this.settingsController,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    widget.settingsController.addListener(_refresh);
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.settingsController.removeListener(_refresh);
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _openCustomisation() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CustomisationScreen(
          settingsController: widget.settingsController,
          previewArtworkUrl: widget.controller.currentTrack?.artworkUrl,
        ),
      ),
    );
  }

  void _openAudioLab() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AudioLabScreen(
          controller: widget.controller,
          settingsController: widget.settingsController,
        ),
      ),
    );
  }

  Future<void> _openSocialUrl(String url, String label) async {
    final uri = Uri.parse(url);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
    } catch (_) {}

    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã sao chép liên kết $label'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.settingsController.profile;
    final settings = widget.settingsController.settings;
    final accent = settings.accentColor;
    final onAccent = settings.onAccentColor;

    // Approximate listening time from play count (avg ~3.5 min/track)
    final estMins = (profile.totalPlays * 3.5).round();
    final hours = estMins ~/ 60;
    final mins = estMins % 60;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Mochy Signature Dotted Charcoal Top Header + Personal ID Card
        SliverToBoxAdapter(
          child: DottedHeaderSurface(
            watermarkLetter: 'L',
            bottomRadius: 28,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/logo.png',
                          width: 34,
                          height: 34,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 34,
                            height: 34,
                            color: const Color(0xFF2C2C30),
                            child: const Icon(
                              Icons.graphic_eq_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      SpringTap(
                        onTap: () => showEditProfileSheet(
                          context,
                          widget.settingsController,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: const Color(0xFF26262A),
                          ),
                          child: const Text(
                            'Chỉnh sửa',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Xin chào, ${profile.displayName}!',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ProfileIdCard(
                    profile: profile,
                    accentColor: accent,
                    favoritesCount: widget.controller.favorites.length,
                    showEditHint: true,
                    onAvatarTap: () => showEditProfileSheet(
                      context,
                      widget.settingsController,
                    ),
                    onEditTap: () => showEditProfileSheet(
                      context,
                      widget.settingsController,
                    ),
                    onToggleFinish: widget.settingsController.toggleCardFinish,
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 14)),

        // Mochy Big Editorial Listening Time & Stats Card (borderless #121215)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
              decoration: BoxDecoration(
                color: const Color(0xFF121215),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text.rich(
                            TextSpan(
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.0,
                              ),
                              children: [
                                TextSpan(
                                  text: '$hours',
                                  style: const TextStyle(fontSize: 38),
                                ),
                                const TextSpan(
                                  text: 'h',
                                  style: TextStyle(fontSize: 18),
                                ),
                                TextSpan(
                                  text: '  |  ',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w300,
                                    color: Colors.white.withValues(alpha: 0.25),
                                  ),
                                ),
                                TextSpan(
                                  text: '$mins',
                                  style: const TextStyle(fontSize: 38),
                                ),
                                const TextSpan(
                                  text: 'm',
                                  style: TextStyle(fontSize: 18),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Thời gian nghe\n${profile.totalPlays} lượt · ${widget.controller.favorites.length} thích',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(height: 0.7, color: const Color(0xFF242428)),
                  const SizedBox(height: 12),
                  SpringTap(
                    onTap: _openCustomisation,
                    child: const Row(
                      children: [
                        Text(
                          'Tuỳ biến giao diện & Lời bài hát',
                          style: TextStyle(
                            color: Color(0xFFAEAEB2),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: Color(0xFF8E8E93),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // Theme Mode Switcher (Liquid Glass vs Classic) — Monochrome Crisp Pill
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF121215),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _MonochromeSegment(
                      label: 'Liquid Glass',
                      icon: Icons.blur_on_rounded,
                      active:
                          settings.visualTheme == AppVisualTheme.liquidGlass,
                      accent: accent,
                      onAccent: onAccent,
                      onTap: () => widget.settingsController
                          .setVisualTheme(AppVisualTheme.liquidGlass),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _MonochromeSegment(
                      label: 'Classic',
                      icon: Icons.layers_rounded,
                      active: settings.visualTheme == AppVisualTheme.classic,
                      accent: accent,
                      onAccent: onAccent,
                      onTap: () => widget.settingsController
                          .setVisualTheme(AppVisualTheme.classic),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // Audio Lab & Customisation Clean Tonal Cards
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(
                  child: SpringTap(
                    onTap: _openAudioLab,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF121215),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.graphic_eq_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Audio Lab',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'EQ · Speed · HQ',
                            style: TextStyle(
                              color: Color(0xFF8E8E93),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SpringTap(
                    onTap: _openCustomisation,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF121215),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.palette_outlined,
                            color: Colors.white,
                            size: 22,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Tuỳ biến',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Player · Lời nhạc',
                            style: TextStyle(
                              color: Color(0xFF8E8E93),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // Exact Mochy-Style Version & About App Card + Social Links
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF121215),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Phiên bản & thông tin ứng dụng',
                    style: TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        '2.2.0',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.2,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: const Color(0xFF2C2C30),
                        ),
                        child: const Text(
                          'Lemielmusicv2',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _SocialPill(
                          label: 'Facebook',
                          icon: Icons.facebook_rounded,
                          onTap: () => _openSocialUrl(
                            'https://www.facebook.com/dnqdwthgv/',
                            'Facebook',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SocialPill(
                          label: 'Instagram',
                          icon: Icons.camera_alt_outlined,
                          onTap: () => _openSocialUrl(
                            'https://www.instagram.com/s1mpleirl.das/',
                            'Instagram',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SocialPill(
                          label: 'GitHub',
                          icon: Icons.code_rounded,
                          onTap: () => _openSocialUrl(
                            'https://github.com/concas2025',
                            'GitHub',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 175)),
      ],
    );
  }
}

class _MonochromeSegment extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color accent;
  final Color onAccent;
  final VoidCallback onTap;

  const _MonochromeSegment({
    required this.label,
    required this.icon,
    required this.active,
    required this.accent,
    required this.onAccent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SpringTap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: active ? accent : Colors.transparent,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: active ? onAccent : const Color(0xFF8E8E93),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? onAccent : const Color(0xFF8E8E93),
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SocialPill({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SpringTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFF1D1D21),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Local profile & avatar editor sheet (photo picker + 6 monogram styles).
Future<void> showEditProfileSheet(
  BuildContext context,
  SettingsController settingsController, {
  bool isOnboarding = false,
}) async {
  final initial = settingsController.profile;
  final nameCtrl = TextEditingController(
    text: isOnboarding && initial.displayName == 'Người nghe Lemiel'
        ? ''
        : initial.displayName,
  );
  final bioCtrl = TextEditingController(text: initial.bio);
  String? avatarPath = initial.avatarPath;
  int avatarPreset = initial.avatarPresetIndex;
  bool silver = initial.silverCard;
  final accent = settingsController.settings.accentColor;
  final onAccent = settingsController.settings.onAccentColor;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          Future<void> pickAvatar() async {
            if (kIsWeb) return;
            try {
              final picker = ImagePicker();
              final picked = await picker.pickImage(
                source: ImageSource.gallery,
                maxWidth: 640,
                maxHeight: 640,
                imageQuality: 88,
              );
              if (picked == null) return;
              final docs = await getApplicationDocumentsDirectory();
              final dest = File(
                '${docs.path}${Platform.pathSeparator}lemiel_avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
              );
              await File(picked.path).copy(dest.path);
              setModalState(() => avatarPath = dest.path);
            } catch (_) {}
          }

          final previewProfile = initial.copyWith(
            displayName: nameCtrl.text.trim().isNotEmpty
                ? nameCtrl.text.trim()
                : 'Người nghe Lemiel',
            bio: bioCtrl.text.trim().isNotEmpty
                ? bioCtrl.text.trim()
                : initial.bio,
            avatarPath: avatarPath,
            clearAvatar: avatarPath == null,
            avatarPresetIndex: avatarPreset,
            silverCard: silver,
          );

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF16161A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Tuỳ chỉnh Thẻ Cá Nhân',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ProfileIdCard(
                      profile: previewProfile,
                      accentColor: accent,
                      favoritesCount: 0,
                      showEditHint: true,
                      onAvatarTap: pickAvatar,
                      onToggleFinish: () => setModalState(() => silver = !silver),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        SpringTap(
                          onTap: pickAvatar,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: const Color(0xFF26262B),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.photo_library_outlined,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Ảnh từ máy',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 34,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: UserProfile.avatarGradients.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (_, idx) {
                                final grad = UserProfile.avatarGradients[idx];
                                final active =
                                    avatarPath == null && avatarPreset == idx;
                                return GestureDetector(
                                  onTap: () => setModalState(() {
                                    avatarPath = null;
                                    avatarPreset = idx;
                                  }),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 160),
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: idx == 0
                                          ? const Color(0xFF4F4F52)
                                          : null,
                                      gradient: idx == 0
                                          ? null
                                          : LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: grad,
                                            ),
                                      border: Border.all(
                                        color: active
                                            ? Colors.white
                                            : Colors.transparent,
                                        width: 2.2,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nameCtrl,
                      onChanged: (_) => setModalState(() {}),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Tên hiển thị',
                        hintStyle: const TextStyle(color: Color(0xFF636366)),
                        filled: true,
                        fillColor: const Color(0xFF242428),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: bioCtrl,
                      onChanged: (_) => setModalState(() {}),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Giới thiệu ngắn',
                        hintStyle: const TextStyle(color: Color(0xFF636366)),
                        filled: true,
                        fillColor: const Color(0xFF242428),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SpringTap(
                      onTap: () {
                        final finalName = nameCtrl.text.trim().isNotEmpty
                            ? nameCtrl.text.trim()
                            : 'Người nghe Lemiel';
                        final finalBio = bioCtrl.text.trim().isNotEmpty
                            ? bioCtrl.text.trim()
                            : initial.bio;
                        settingsController.updateProfile(
                          initial.copyWith(
                            displayName: finalName,
                            bio: finalBio,
                            avatarPath: avatarPath,
                            clearAvatar: avatarPath == null,
                            avatarPresetIndex: avatarPreset,
                            silverCard: silver,
                            onboardingDone: true,
                          ),
                        );
                        Navigator.of(ctx).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          color: accent,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Lưu thẻ cá nhân',
                          style: TextStyle(
                            color: onAccent,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
