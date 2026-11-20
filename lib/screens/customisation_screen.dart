import 'package:material_ui/material_ui.dart';
import '../models/app_settings.dart';
import '../services/settings_controller.dart';
import '../widgets/glass.dart';
import '../widgets/wavy_slider.dart';

class CustomisationScreen extends StatefulWidget {
  final SettingsController settingsController;
  final String? previewArtworkUrl;

  const CustomisationScreen({
    super.key,
    required this.settingsController,
    this.previewArtworkUrl,
  });

  @override
  State<CustomisationScreen> createState() => _CustomisationScreenState();
}

class _CustomisationScreenState extends State<CustomisationScreen> {
  @override
  void initState() {
    super.initState();
    widget.settingsController.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.settingsController.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settingsController.settings;
    final accent = s.accentColor;

    return Scaffold(
      backgroundColor: Colors.black,
      body: AmbientBackground(
        artworkUrl: widget.previewArtworkUrl,
        accentColor: accent,
        style: s.backgroundStyle,
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 20, 10),
                  child: Row(
                    children: [
                      SpringTap(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF1C1C20),
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tuỳ biến giao diện',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'Liquid Glass • Phong cách trình phát • Lời bài hát',
                              style: TextStyle(
                                color: Color(0xFF8E8E93),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Live interactive preview card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                  child: _LivePlayerPreview(settings: s),
                ),
              ),

              // 0. Dual Theme Selector: Liquid Glass vs Classic
              SliverToBoxAdapter(
                child: _Section(
                  title: 'Chế độ giao diện (Theme)',
                  icon: Icons.contrast_rounded,
                  accent: accent,
                  child: Row(
                    children: [
                      Expanded(
                        child: _ThemeCardOption(
                          title: 'Liquid Glass',
                          subtitle: 'Kính mờ, độ sâu & phản chiếu',
                          icon: Icons.blur_on_rounded,
                          selected: s.visualTheme == AppVisualTheme.liquidGlass,
                          accent: accent,
                          onTap: () => widget.settingsController
                              .setVisualTheme(AppVisualTheme.liquidGlass),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ThemeCardOption(
                          title: 'Classic',
                          subtitle: 'Gọn, sắc nét & dễ đọc',
                          icon: Icons.layers_rounded,
                          selected: s.visualTheme == AppVisualTheme.classic,
                          accent: accent,
                          onTap: () => widget.settingsController
                              .setVisualTheme(AppVisualTheme.classic),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 1. Player UI Style
              SliverToBoxAdapter(
                child: _Section(
                  title: 'Mẫu trình phát nhạc (Now Playing)',
                  icon: Icons.album_rounded,
                  accent: accent,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _OptionPill(
                        label: 'Flagship Mochy',
                        icon: Icons.auto_awesome_rounded,
                        selected: s.playerStyle == PlayerStyle.flagship,
                        accent: accent,
                        onTap: () => widget.settingsController
                            .setPlayerStyle(PlayerStyle.flagship),
                      ),
                      _OptionPill(
                        label: 'Đĩa Vinyl xoay',
                        icon: Icons.disc_full_rounded,
                        selected: s.playerStyle == PlayerStyle.vinyl,
                        accent: accent,
                        onTap: () => widget.settingsController
                            .setPlayerStyle(PlayerStyle.vinyl),
                      ),
                      _OptionPill(
                        label: 'Khung nổi',
                        icon: Icons.crop_free_rounded,
                        selected: s.playerStyle == PlayerStyle.edgeToEdge,
                        accent: accent,
                        onTap: () => widget.settingsController
                            .setPlayerStyle(PlayerStyle.edgeToEdge),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Background Style
              SliverToBoxAdapter(
                child: _Section(
                  title: 'Nền trình phát',
                  icon: Icons.gradient_rounded,
                  accent: accent,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _OptionPill(
                        label: 'Ánh sáng nền',
                        selected:
                            s.backgroundStyle == PlayerBackgroundStyle.ambientGlow,
                        accent: accent,
                        onTap: () => widget.settingsController
                            .setBackgroundStyle(PlayerBackgroundStyle.ambientGlow),
                      ),
                      _OptionPill(
                        label: 'Apple Blur đậm',
                        selected:
                            s.backgroundStyle == PlayerBackgroundStyle.appleBlur,
                        accent: accent,
                        onTap: () => widget.settingsController
                            .setBackgroundStyle(PlayerBackgroundStyle.appleBlur),
                      ),
                      _OptionPill(
                        label: 'Tối giản',
                        selected:
                            s.backgroundStyle == PlayerBackgroundStyle.darkGradient,
                        accent: accent,
                        onTap: () => widget.settingsController
                            .setBackgroundStyle(PlayerBackgroundStyle.darkGradient),
                      ),
                      _OptionPill(
                        label: 'Đen OLED',
                        selected:
                            s.backgroundStyle == PlayerBackgroundStyle.oledBlack,
                        accent: accent,
                        onTap: () => widget.settingsController
                            .setBackgroundStyle(PlayerBackgroundStyle.oledBlack),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Seek Bar Style
              SliverToBoxAdapter(
                child: _Section(
                  title: 'Thanh tua nhạc',
                  icon: Icons.waves_rounded,
                  accent: accent,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _OptionPill(
                        label: 'Sóng Mochy',
                        selected: s.sliderStyle == SliderStyle.mochyWavy,
                        accent: accent,
                        onTap: () => widget.settingsController
                            .setSliderStyle(SliderStyle.mochyWavy),
                      ),
                      _OptionPill(
                        label: 'Apple Slim',
                        selected: s.sliderStyle == SliderStyle.appleSlim,
                        accent: accent,
                        onTap: () => widget.settingsController
                            .setSliderStyle(SliderStyle.appleSlim),
                      ),
                      _OptionPill(
                        label: 'Liquid Pill',
                        selected: s.sliderStyle == SliderStyle.liquidPill,
                        accent: accent,
                        onTap: () => widget.settingsController
                            .setSliderStyle(SliderStyle.liquidPill),
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Accent Color & Liquid Glass Quality
              SliverToBoxAdapter(
                child: _Section(
                  title: 'Màu điểm nhấn & Chất lượng kính',
                  icon: Icons.palette_rounded,
                  accent: accent,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: AccentPreset.values.map((preset) {
                          final selected = s.accentPreset == preset;
                          return SpringTap(
                            onTap: () => widget.settingsController
                                .setAccentPreset(preset),
                            child: Column(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: preset.color,
                                    border: Border.all(
                                      color: selected
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.2),
                                      width: selected ? 2.6 : 1,
                                    ),
                                    boxShadow: selected
                                        ? [
                                            BoxShadow(
                                              color: preset.color
                                                  .withValues(alpha: 0.55),
                                              blurRadius: 14,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: selected
                                      ? Icon(
                                          Icons.check_rounded,
                                          color: preset.color.computeLuminance() > 0.55
                                              ? Colors.black
                                              : Colors.white,
                                          size: 20,
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  preset.label.split(' ').first,
                                  style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : Colors.white60,
                                    fontSize: 11,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      if (s.visualTheme == AppVisualTheme.liquidGlass) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _OptionPill(
                                label: 'Liquid Glass Đầy đủ',
                                selected: s.glassQuality == GlassQuality.high,
                                accent: accent,
                                onTap: () => widget.settingsController
                                    .setGlassQuality(GlassQuality.high),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _OptionPill(
                                label: 'Tiết kiệm pin',
                                selected:
                                    s.glassQuality == GlassQuality.performance,
                                accent: accent,
                                onTap: () => widget.settingsController
                                    .setGlassQuality(GlassQuality.performance),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // 5. Lyrics Customisation
              SliverToBoxAdapter(
                child: _Section(
                  title: 'Cá nhân hoá Lời bài hát',
                  icon: Icons.lyrics_rounded,
                  accent: accent,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _OptionPill(
                            label: 'Apple Glow',
                            selected: s.lyricsStyle == LyricsStyle.appleGlow,
                            accent: accent,
                            onTap: () => widget.settingsController
                                .setLyricsStyle(LyricsStyle.appleGlow),
                          ),
                          _OptionPill(
                            label: 'Mochy Motion',
                            selected: s.lyricsStyle == LyricsStyle.mochyMotion,
                            accent: accent,
                            onTap: () => widget.settingsController
                                .setLyricsStyle(LyricsStyle.mochyMotion),
                          ),
                          _OptionPill(
                            label: 'Karaoke Nổi bật',
                            selected: s.lyricsStyle == LyricsStyle.karaokePill,
                            accent: accent,
                            onTap: () => widget.settingsController
                                .setLyricsStyle(LyricsStyle.karaokePill),
                          ),
                          _OptionPill(
                            label: 'Tối giản',
                            selected: s.lyricsStyle == LyricsStyle.minimal,
                            accent: accent,
                            onTap: () => widget.settingsController
                                .setLyricsStyle(LyricsStyle.minimal),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text(
                            'Căn lề chữ',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          const Spacer(),
                          for (final (align, icon) in [
                            (LyricsAlign.left, Icons.format_align_left_rounded),
                            (LyricsAlign.center, Icons.format_align_center_rounded),
                            (LyricsAlign.right, Icons.format_align_right_rounded),
                          ])
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: SpringTap(
                                onTap: () => widget.settingsController
                                    .setLyricsAlign(align),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: s.lyricsAlign == align
                                        ? accent
                                        : const Color(0xFF1E1E22),
                                  ),
                                  child: Icon(
                                    icon,
                                    size: 18,
                                    color: s.lyricsAlign == align
                                        ? s.onAccentColor
                                        : Colors.white70,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Text(
                            'Cỡ chữ lời hát (${s.lyricsFontSize.round()} pt)',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: s.lyricsFontSize,
                        min: 16,
                        max: 28,
                        divisions: 12,
                        activeColor: accent,
                        inactiveColor: Colors.white24,
                        onChanged: widget.settingsController.setLyricsFontSize,
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: accent,
                        title: const Text(
                          'Làm mờ dòng chưa hát',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        subtitle: const Text(
                          'Tạo chiều sâu kiểu Apple Music cho lời đồng bộ',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        value: s.blurInactiveLyrics,
                        onChanged: widget.settingsController.setBlurInactiveLyrics,
                      ),
                    ],
                  ),
                ),
              ),

              // 6. Lyrics Providers Priority & Toggles
              SliverToBoxAdapter(
                child: _Section(
                  title: 'Nguồn cung Lời bài hát',
                  icon: Icons.hub_rounded,
                  accent: accent,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ứng dụng tự động tìm theo thứ tự ưu tiên bên dưới. Bật/tắt hoặc đẩy nguồn bạn thích lên đầu:',
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      ...List.generate(s.lyricsProviderOrder.length, (index) {
                        final id = s.lyricsProviderOrder[index];
                        final name = AppSettings.providerDisplayNames[id] ?? id;
                        final enabled = s.enabledLyricsProviders.contains(id);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: const Color(0xFF1A1A1E),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: enabled ? accent : Colors.white10,
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: enabled
                                        ? s.onAccentColor
                                        : Colors.white54,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    color: enabled ? Colors.white : Colors.white54,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: index > 0
                                    ? () => widget.settingsController
                                        .moveLyricsProvider(index, index - 1)
                                    : null,
                                icon: Icon(
                                  Icons.keyboard_arrow_up_rounded,
                                  color: index > 0 ? Colors.white70 : Colors.white24,
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: index < s.lyricsProviderOrder.length - 1
                                    ? () => widget.settingsController
                                        .moveLyricsProvider(index, index + 2)
                                    : null,
                                icon: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: index < s.lyricsProviderOrder.length - 1
                                      ? Colors.white70
                                      : Colors.white24,
                                ),
                              ),
                              Switch.adaptive(
                                value: enabled,
                                activeThumbColor: accent,
                                onChanged: (v) => widget.settingsController
                                    .toggleLyricsProvider(id, v),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LivePlayerPreview extends StatelessWidget {
  final AppSettings settings;
  const _LivePlayerPreview({required this.settings});

  @override
  Widget build(BuildContext context) {
    final accent = settings.accentColor;
    final align = switch (settings.lyricsAlign) {
      LyricsAlign.left => TextAlign.left,
      LyricsAlign.center => TextAlign.center,
      LyricsAlign.right => TextAlign.right,
    };

    return GlassSurface(
      borderRadius: 24,
      blur: 20,
      opacity: 0.14,
      highQuality: settings.highGlass,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Mini Artwork Preview adapting to PlayerStyle
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: settings.playerStyle == PlayerStyle.vinyl
                      ? BoxShape.circle
                      : BoxShape.rectangle,
                  borderRadius: settings.playerStyle == PlayerStyle.vinyl
                      ? null
                      : BorderRadius.circular(
                          settings.playerStyle == PlayerStyle.edgeToEdge ? 8 : 16,
                        ),
                  gradient: LinearGradient(
                    colors: settings.isMonochrome
                        ? const [Color(0xFF34343B), Color(0xFF19191E)]
                        : [accent, Color.lerp(accent, Colors.black, 0.45)!],
                  ),
                ),
                child: Icon(
                  settings.playerStyle == PlayerStyle.vinyl
                      ? Icons.album_rounded
                      : Icons.music_note_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Xem trước trực tiếp',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Mùa thu mang giấc mơ quay về',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'Lemielmusic Studio Preview',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CustomMusicSlider(
            value: 0.58,
            isPlaying: true,
            style: settings.sliderStyle,
            accentColor: accent,
            onChanged: (_) {},
            onChangeEnd: (_) {},
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: settings.lyricsStyle == LyricsStyle.karaokePill
                  ? accent.withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.05),
            ),
            child: Text(
              'Lá bay theo gió xôn xao...',
              textAlign: align,
              style: TextStyle(
                color: Colors.white,
                fontSize: (settings.lyricsFontSize * 0.78).clamp(14.0, 21.0),
                fontWeight: FontWeight.w700,
                shadows: settings.lyricsStyle == LyricsStyle.appleGlow
                    ? [
                        Shadow(
                          color: accent.withValues(alpha: 0.7),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final Widget child;

  const _Section({
    required this.title,
    required this.icon,
    required this.accent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
      child: GlassSurface(
        borderRadius: 22,
        blur: 18,
        opacity: 0.09,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accent, size: 19),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ThemeCardOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _ThemeCardOption({
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
          color: selected ? const Color(0xFF1F1F24) : const Color(0xFF161619),
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
                Icon(icon, size: 19, color: selected ? accent : Colors.white70),
                const Spacer(),
                if (selected)
                  Icon(Icons.check_circle_rounded, size: 18, color: accent),
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

class _OptionPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _OptionPill({
    required this.label,
    this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onAccent =
        accent.computeLuminance() > 0.55 ? Colors.black : Colors.white;
    return SpringTap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected ? accent : const Color(0xFF1C1C20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: selected ? onAccent : const Color(0xFFAEAEB2),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? onAccent : const Color(0xFFAEAEB2),
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
