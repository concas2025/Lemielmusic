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

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HỒ SƠ & CÀI ĐẶT',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.48),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Thẻ Thành Viên',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.7,
                      ),
                    ),
                  ],
                ),
                SpringTap(
                  onTap: () => showEditProfileSheet(
                    context,
                    widget.settingsController,
                  ),
                  child: GlassSurface(
                    borderRadius: 18,
                    opacity: 0.14,
                    highQuality: settings.highGlass,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_rounded, size: 16, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'Sửa thẻ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Redesigned 1.89:1 Personal ID Card with vertical marquee & brushed silver/obsidian finish
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: StaggeredFadeSlide(
              index: 0,
              child: ProfileIdCard(
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
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
            child: Center(
              child: Text(
                'Vuốt nhẹ lên thẻ để xem ánh sáng • Chạm ảnh hoặc góc trên để tuỳ chỉnh',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.44),
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ),

        // Quick Theme Mode Switcher (Liquid Glass / Classic)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: GlassSurface(
              borderRadius: 20,
              opacity: 0.10,
              highQuality: settings.highGlass,
              padding: const EdgeInsets.all(6),
              child: Row(
                children: [
                  Expanded(
                    child: _ThemeToggleButton(
                      label: 'Liquid Glass',
                      icon: Icons.blur_on_rounded,
                      active:
                          settings.visualTheme == AppVisualTheme.liquidGlass,
                      accent: accent,
                      onTap: () => widget.settingsController
                          .setVisualTheme(AppVisualTheme.liquidGlass),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _ThemeToggleButton(
                      label: 'Classic',
                      icon: Icons.layers_rounded,
                      active: settings.visualTheme == AppVisualTheme.classic,
                      accent: accent,
                      onTap: () => widget.settingsController
                          .setVisualTheme(AppVisualTheme.classic),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Listening Stats Grid
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _StatCard(
                    value: '${profile.totalPlays}',
                    label: 'Lượt nghe',
                    icon: Icons.headphones_rounded,
                    accent: accent,
                    highGlass: settings.highGlass,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    value: '${widget.controller.favorites.length}',
                    label: 'Yêu thích',
                    icon: Icons.favorite_rounded,
                    accent: accent,
                    highGlass: settings.highGlass,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    value: '${widget.controller.playlists.length}',
                    label: 'Playlist',
                    icon: Icons.queue_music_rounded,
                    accent: accent,
                    highGlass: settings.highGlass,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // Studio Action Tiles: Customisation & Audio Lab
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _ActionCard(
                  icon: Icons.palette_rounded,
                  title: 'Cài đặt giao diện & Lời bài hát',
                  subtitle:
                      'Liquid Glass / Classic, mẫu trình phát, hiệu ứng lời & nguồn lời',
                  accent: accent,
                  highGlass: settings.highGlass,
                  onTap: _openCustomisation,
                ),
                const SizedBox(height: 10),
                _ActionCard(
                  icon: Icons.graphic_eq_rounded,
                  title: 'Audio Lab & Chất lượng nhạc',
                  subtitle:
                      'Chất lượng AAC, Tốc độ/Cao độ (Slowed/Nightcore), Hẹn giờ & EQ',
                  accent: const Color(0xFF6E6BF5),
                  highGlass: settings.highGlass,
                  onTap: _openAudioLab,
                ),
              ],
            ),
          ),
        ),

        // Top Artists
        if (profile.topArtists.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Text(
                'Nghệ sĩ bạn nghe nhiều nhất',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.90),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GlassSurface(
                borderRadius: 20,
                opacity: 0.09,
                highQuality: settings.highGlass,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  children: profile.topArtists.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final artist = entry.value;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: idx == 0
                                  ? accent.withValues(alpha: 0.30)
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                            child: Text(
                              '${idx + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              artist.key,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${artist.value} lượt',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.56),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],

        // About & Developer Social Card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: GlassSurface(
              borderRadius: 24,
              blur: 20,
              opacity: 0.11,
              highQuality: settings.highGlass,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset(
                          'assets/logo.png',
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 52,
                            height: 52,
                            color: accent.withValues(alpha: 0.25),
                            child: const Icon(
                              Icons.music_note_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Text(
                                  'Lemielmusic',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                SizedBox(width: 7),
                                Text(
                                  'v2.1.0',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Phát triển bởi @concas2025 • Made with <3',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.62),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _SocialButton(
                          label: 'Facebook',
                          icon: Icons.facebook_rounded,
                          color: const Color(0xFF1877F2),
                          onTap: () => _openSocialUrl(
                            'https://www.facebook.com/dnqdwthgv/',
                            'Facebook',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SocialButton(
                          label: 'Instagram',
                          icon: Icons.camera_alt_rounded,
                          color: const Color(0xFFE1306C),
                          onTap: () => _openSocialUrl(
                            'https://www.instagram.com/s1mpleirl.das/',
                            'Instagram',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SocialButton(
                          label: 'GitHub',
                          icon: Icons.code_rounded,
                          color: const Color(0xFF8B949E),
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

        const SliverToBoxAdapter(child: SizedBox(height: 170)),
      ],
    );
  }
}

class _ThemeToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  const _ThemeToggleButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SpringTap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: active ? accent.withValues(alpha: 0.28) : Colors.transparent,
          border: Border.all(
            color: active ? accent.withValues(alpha: 0.65) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: active ? Colors.white : Colors.white60),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : Colors.white60,
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

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color accent;
  final bool highGlass;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.accent,
    required this.highGlass,
  });

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      borderRadius: 20,
      opacity: 0.10,
      highQuality: highGlass,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.56),
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final bool highGlass;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.highGlass,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SpringTap(
      onTap: onTap,
      child: GlassSurface(
        borderRadius: 22,
        opacity: 0.11,
        highQuality: highGlass,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: accent.withValues(alpha: 0.22),
                border: Border.all(color: accent.withValues(alpha: 0.45)),
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.58),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SocialButton({
    required this.label,
    required this.icon,
    required this.color,
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
          color: color.withValues(alpha: 0.16),
          border: Border.all(
            color: color.withValues(alpha: 0.42),
            width: 0.9,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Local profile & avatar editor sheet (supports photo library + 6 monogram gradients).
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
            child: GlassSurface(
              borderRadius: 30,
              blur: 28,
              opacity: 0.22,
              tintColor: const Color(0xFF14141E),
              isLens: true,
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
                          color: Colors.white30,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Tuỳ chỉnh Thẻ Cá Nhân',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Lưu cục bộ trên thiết bị • Chạm vào ảnh trên thẻ để chọn ảnh',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 16),

                    ProfileIdCard(
                      profile: previewProfile,
                      accentColor: accent,
                      favoritesCount: 0,
                      showEditHint: true,
                      onAvatarTap: pickAvatar,
                      onToggleFinish: () => setModalState(() => silver = !silver),
                    ),
                    const SizedBox(height: 16),

                    // Photo picker + 6 monogram gradient swatches
                    Row(
                      children: [
                        SpringTap(
                          onTap: pickAvatar,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: accent.withValues(alpha: 0.22),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.55),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.photo_library_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Ảnh từ máy',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
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
                                final grad = idx == 0
                                    ? [
                                        accent,
                                        Color.lerp(
                                          accent,
                                          const Color(0xFF5E5CE6),
                                          0.55,
                                        )!,
                                      ]
                                    : UserProfile.avatarGradients[idx];
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
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: grad,
                                      ),
                                      border: Border.all(
                                        color: active
                                            ? Colors.white
                                            : Colors.white24,
                                        width: active ? 2.4 : 1,
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
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        labelText: 'Tên hiển thị',
                        hintText: 'VD: Lemiel, Minh Anh...',
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
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
                        labelText: 'Dòng giới thiệu / Bio',
                        hintText: 'Âm nhạc là ngôn ngữ của cảm xúc',
                        labelStyle: const TextStyle(color: Colors.white70),
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
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
                          borderRadius: BorderRadius.circular(18),
                          color: accent,
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Lưu thẻ cá nhân',
                          style: TextStyle(
                            color: Colors.white,
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
