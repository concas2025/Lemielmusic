import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import '../models/app_settings.dart';
import '../models/user_profile.dart';
import '../services/settings_controller.dart';
import '../theme/lemiel_theme.dart';
import '../widgets/glass.dart';
import '../widgets/profile_id_card.dart';

/// Full-screen welcome & personal ID card setup inspired by clean editorial
/// music onboarding flows, crafted exclusively for Lemielmusic.
class OnboardingScreen extends StatefulWidget {
  final SettingsController settingsController;
  final VoidCallback onComplete;

  const OnboardingScreen({
    super.key,
    required this.settingsController,
    required this.onComplete,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bioCtrl;
  String? _avatarPath;
  int _avatarPreset = 0;

  @override
  void initState() {
    super.initState();
    final initial = widget.settingsController.profile;
    _nameCtrl = TextEditingController(
      text: initial.displayName == 'Người nghe Lemiel' ? '' : initial.displayName,
    );
    _bioCtrl = TextEditingController(text: initial.bio);
    _avatarPath = initial.avatarPath;
    _avatarPreset = initial.avatarPresetIndex;
    widget.settingsController.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.settingsController.removeListener(_refresh);
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _pickPhoto() async {
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
      if (mounted) setState(() => _avatarPath = dest.path);
    } catch (_) {}
  }

  void _finish({bool skipped = false}) {
    final base = widget.settingsController.profile;
    final name = (!skipped && _nameCtrl.text.trim().isNotEmpty)
        ? _nameCtrl.text.trim()
        : base.displayName;
    final bio = (!skipped && _bioCtrl.text.trim().isNotEmpty)
        ? _bioCtrl.text.trim()
        : base.bio;

    widget.settingsController.updateProfile(
      base.copyWith(
        displayName: name,
        bio: bio,
        avatarPath: _avatarPath,
        clearAvatar: _avatarPath == null,
        avatarPresetIndex: _avatarPreset,
        onboardingDone: true,
      ),
    );
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settingsController.settings;
    final theme = LemielTheme.of(context);
    final accent = settings.accentColor;

    final previewProfile = widget.settingsController.profile.copyWith(
      displayName: _nameCtrl.text.trim().isNotEmpty
          ? _nameCtrl.text.trim()
          : 'Người nghe Lemiel',
      bio: _bioCtrl.text.trim().isNotEmpty
          ? _bioCtrl.text.trim()
          : widget.settingsController.profile.bio,
      avatarPath: _avatarPath,
      clearAvatar: _avatarPath == null,
      avatarPresetIndex: _avatarPreset,
    );

    return Scaffold(
      backgroundColor: theme.canvas,
      body: AmbientBackground(
        accentColor: accent,
        style: PlayerBackgroundStyle.darkGradient,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  // Top Skip action
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.asset(
                            'assets/logo.png',
                            width: 34,
                            height: 34,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 34,
                              height: 34,
                              color: accent.withValues(alpha: 0.25),
                              child: const Icon(
                                Icons.music_note_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Lemielmusic',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => _finish(skipped: true),
                          child: Text(
                            'Bỏ qua',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.58),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tạo Thẻ Cá Nhân\ncủa riêng bạn',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.9,
                              height: 1.12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Mọi thông tin được lưu cục bộ trên iPhone của bạn. Chạm vào ảnh đại diện trên thẻ để đổi ảnh.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.62),
                              fontSize: 13.5,
                              height: 1.42,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Centerpiece Brushed Silver ID Card (live preview)
                          StaggeredFadeSlide(
                            index: 0,
                            child: ProfileIdCard(
                              profile: previewProfile,
                              accentColor: accent,
                              favoritesCount: 0,
                              forceSilver: true,
                              showEditHint: true,
                              onAvatarTap: _pickPhoto,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Avatar Picker Row: Photo + 6 Curated Monogram Gradients
                          Row(
                            children: [
                              SpringTap(
                                onTap: _pickPhoto,
                                child: GlassSurface(
                                  borderRadius: 16,
                                  opacity: 0.14,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
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
                                        'Chọn ảnh',
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
                                          ? (settings.isMonochrome
                                              ? const [
                                                  Color(0xFF3A3A40),
                                                  Color(0xFF1A1A1E),
                                                ]
                                              : [
                                                  accent,
                                                  Color.lerp(
                                                    accent,
                                                    Colors.black,
                                                    0.45,
                                                  )!,
                                                ])
                                          : UserProfile.avatarGradients[idx];
                                      final active =
                                          _avatarPath == null && _avatarPreset == idx;
                                      return GestureDetector(
                                        onTap: () => setState(() {
                                          _avatarPath = null;
                                          _avatarPreset = idx;
                                        }),
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 180),
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

                          const SizedBox(height: 18),

                          // Rounded Pill Name Input
                          _PillInput(
                            controller: _nameCtrl,
                            hint: 'Nhập tên của bạn (VD: Minh Anh, Lemiel...)',
                            icon: Icons.person_outline_rounded,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 10),
                          _PillInput(
                            controller: _bioCtrl,
                            hint: 'Dòng giới thiệu ngắn...',
                            icon: Icons.auto_awesome_outlined,
                            onChanged: (_) => setState(() {}),
                          ),

                          const SizedBox(height: 20),

                          // Visual Theme Mode Selector right inside Onboarding
                          Text(
                            'CHỌN PHONG CÁCH GIAO DIỆN',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.50),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _ThemeChoiceTile(
                                  title: 'Liquid Glass',
                                  subtitle: 'Kính mờ có chiều sâu',
                                  icon: Icons.blur_on_rounded,
                                  selected: settings.visualTheme ==
                                      AppVisualTheme.liquidGlass,
                                  accent: accent,
                                  onTap: () => widget.settingsController
                                      .setVisualTheme(AppVisualTheme.liquidGlass),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _ThemeChoiceTile(
                                  title: 'Classic',
                                  subtitle: 'Gọn, sắc nét, dễ đọc',
                                  icon: Icons.layers_rounded,
                                  selected: settings.visualTheme ==
                                      AppVisualTheme.classic,
                                  accent: accent,
                                  onTap: () => widget.settingsController
                                      .setVisualTheme(AppVisualTheme.classic),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Pinned Footer CTA
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
                    child: SpringTap(
                      onTap: () => _finish(),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          color: accent,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Bắt đầu nghe nhạc',
                          style: TextStyle(
                            color: settings.onAccentColor,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PillInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final ValueChanged<String> onChanged;

  const _PillInput({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      borderRadius: 24,
      opacity: 0.11,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          icon: Icon(icon, size: 19, color: Colors.white54),
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.38),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _ThemeChoiceTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _ThemeChoiceTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SpringTap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: selected ? const Color(0xFF1F1F24) : const Color(0xFF141417),
          border: Border.all(
            color: selected ? accent : Colors.transparent,
            width: selected ? 1.4 : 0.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: selected ? accent : Colors.white70),
                const Spacer(),
                if (selected)
                  Icon(Icons.check_circle_rounded, size: 17, color: accent),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.58),
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
