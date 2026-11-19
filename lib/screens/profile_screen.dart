import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
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
                      'HỒ SƠ CÁ NHÂN',
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

        // Interactive 1.89:1 Mochy-Style Personal ID Card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: StaggeredFadeSlide(
              index: 0,
              child: ProfileIdCard(
                profile: profile,
                accentColor: accent,
                favoritesCount: widget.controller.favorites.length,
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
                'Vuốt nhẹ lên thẻ để xem hiệu ứng ánh sáng • Chạm góc trên để đổi Obsidian / Silver',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.44),
                  fontSize: 11,
                ),
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
                  title: 'Tuỳ biến giao diện & Lời bài hát',
                  subtitle:
                      'Mẫu trình phát, Liquid Glass, hiệu ứng lời & nguồn cung lời',
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

        const SliverToBoxAdapter(child: SizedBox(height: 170)),
      ],
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

/// Opens the Mochy-style local profile editor (Name, Bio, iPhone Photos Avatar).
/// Also used on first launch so the user can personalize their Lemiel Pass right away.
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
                    Text(
                      isOnboarding
                          ? 'Chào mừng đến Lemielmusic'
                          : 'Tuỳ chỉnh Thẻ Cá Nhân',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Lưu hoàn toàn trên máy của bạn • Không cần mật khẩu',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 16),

                    // Live miniature ID card preview
                    ProfileIdCard(
                      profile: previewProfile,
                      accentColor: accent,
                      favoritesCount: 0,
                      onToggleFinish: () => setModalState(() => silver = !silver),
                    ),
                    const SizedBox(height: 16),

                    // Avatar Picker Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SpringTap(
                          onTap: pickAvatar,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
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
                                  size: 17,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Chọn ảnh đại diện',
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
                        if (avatarPath != null) ...[
                          const SizedBox(width: 10),
                          TextButton(
                            onPressed: () =>
                                setModalState(() => avatarPath = null),
                            child: const Text(
                              'Dùng chữ cái',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
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
                        child: Text(
                          isOnboarding ? 'Bắt đầu nghe nhạc' : 'Lưu thẻ cá nhân',
                          style: const TextStyle(
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
