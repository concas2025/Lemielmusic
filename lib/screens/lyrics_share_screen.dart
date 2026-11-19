import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/app_settings.dart';
import '../models/track.dart';
import '../models/user_profile.dart';
import '../widgets/glass.dart';
import '../widgets/profile_id_card.dart';

enum _CardBgStyle { gradient, blurCover, solidDark, solidLight }

class _CardPalette {
  final String name;
  final List<Color> colors;
  final bool lightText;
  const _CardPalette(this.name, this.colors, {this.lightText = true});
}

class LyricsShareScreen extends StatefulWidget {
  final Track track;
  final List<LyricLine> lyrics;
  final int initialIndex;
  final UserProfile profile;
  final Color accentColor;

  const LyricsShareScreen({
    super.key,
    required this.track,
    required this.lyrics,
    required this.initialIndex,
    required this.profile,
    required this.accentColor,
  });

  @override
  State<LyricsShareScreen> createState() => _LyricsShareScreenState();
}

class _LyricsShareScreenState extends State<LyricsShareScreen> {
  static const _palettes = [
    _CardPalette('Rose Velvet', [Color(0xFF4A0F28), Color(0xFFFF375F)]),
    _CardPalette('Midnight', [Color(0xFF12163A), Color(0xFF5E5CE6)]),
    _CardPalette('Emerald', [Color(0xFF0A2E2B), Color(0xFF1FA68B)]),
    _CardPalette('Sunset', [Color(0xFF4D210B), Color(0xFFFF9F0A)]),
    _CardPalette('Obsidian', [Color(0xFF101116), Color(0xFF252836)]),
    _CardPalette('Ocean', [Color(0xFF091E3A), Color(0xFF2F80ED)]),
    _CardPalette('Sakura', [Color(0xFF3A1C3E), Color(0xFFEA7FA2)]),
    _CardPalette(
      'Pearl',
      [Color(0xFFF4F6FA), Color(0xFFDCE3EE)],
      lightText: false,
    ),
  ];

  final GlobalKey _cardKey = GlobalKey();
  late final Set<int> _selectedIndices;
  bool _pickingLines = false;
  _CardBgStyle _bgStyle = _CardBgStyle.gradient;
  int _paletteIdx = 0;
  LyricsAlign _align = LyricsAlign.left;
  bool _storyRatio = false; // false = 1:1 Post, true = 9:16 Story
  bool _showWatermark = true;
  double _fontSize = 22.0;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _selectedIndices = {};
    if (widget.lyrics.isNotEmpty) {
      final start = widget.initialIndex.clamp(0, widget.lyrics.length - 1);
      for (int i = start; i < widget.lyrics.length && _selectedIndices.length < 3; i++) {
        _selectedIndices.add(i);
      }
    }
  }

  List<String> get _selectedLines {
    final sorted = _selectedIndices.toList()..sort();
    return sorted.map((i) => widget.lyrics[i].text).toList(growable: false);
  }

  void _toggleLine(int idx) {
    setState(() {
      if (_selectedIndices.contains(idx)) {
        if (_selectedIndices.length > 1) _selectedIndices.remove(idx);
      } else {
        if (_selectedIndices.length >= 5) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chọn tối đa 5 dòng lời để thẻ chia sẻ đẹp nhất.'),
              duration: Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        _selectedIndices.add(idx);
      }
    });
  }

  Future<void> _shareCard() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Không thể chụp thẻ lời bài hát.');
      }
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Lỗi tạo file ảnh PNG.');
      }
      final bytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}${Platform.pathSeparator}lemiel_lyric_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes, flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: '${widget.track.title} — ${widget.track.artist} • Lemielmusic',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể chia sẻ ảnh: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;

    return Scaffold(
      backgroundColor: const Color(0xFF06060A),
      body: AmbientBackground(
        artworkUrl: widget.track.artworkUrl,
        accentColor: accent,
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 16, 6),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Chia sẻ Lời bài hát',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SpringTap(
                      onTap: () => setState(() => _pickingLines = !_pickingLines),
                      child: GlassSurface(
                        borderRadius: 16,
                        opacity: _pickingLines ? 0.28 : 0.12,
                        tintColor: _pickingLines ? accent : Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        child: Text(
                          _pickingLines
                              ? 'Xong (${_selectedIndices.length}/5)'
                              : 'Chọn lời (${_selectedIndices.length})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Main workspace: either Line Picker OR Live Card Studio
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: _pickingLines
                      ? _buildLinePicker(accent)
                      : _buildCardStudio(accent),
                ),
              ),

              // Share button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: SpringTap(
                  onTap: _exporting ? null : _shareCard,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          accent,
                          Color.lerp(accent, const Color(0xFF5E5CE6), 0.35)!,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.38),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_exporting)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        else
                          const Icon(
                            Icons.ios_share_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        const SizedBox(width: 8),
                        Text(
                          _exporting
                              ? 'Đang xuất ảnh chất lượng cao...'
                              : 'Chia sẻ lên Story / IG / FB / TikTok',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
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
    );
  }

  Widget _buildLinePicker(Color accent) {
    return ListView.builder(
      key: const ValueKey('line_picker'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      itemCount: widget.lyrics.length,
      itemBuilder: (_, i) {
        final selected = _selectedIndices.contains(i);
        return GestureDetector(
          onTap: () => _toggleLine(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: selected
                  ? accent.withValues(alpha: 0.28)
                  : Colors.white.withValues(alpha: 0.06),
              border: Border.all(
                color: selected ? accent : Colors.white12,
                width: selected ? 1.3 : 0.8,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 19,
                  color: selected ? Colors.white : Colors.white38,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.lyrics[i].text,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardStudio(Color accent) {
    return SingleChildScrollView(
      key: const ValueKey('card_studio'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 6),
          // Exportable RepaintBoundary Lyric Share Card
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: _storyRatio ? 255 : 340,
              ),
              child: RepaintBoundary(
                key: _cardKey,
                child: _buildExportableCard(),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Customisation Controls Panel
          GlassSurface(
            borderRadius: 22,
            blur: 18,
            opacity: 0.11,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Background Style
                const Text(
                  'Kiểu nền thẻ',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (st, label) in [
                      (_CardBgStyle.gradient, 'Gradient'),
                      (_CardBgStyle.blurCover, 'Blur Bìa Nhạc'),
                      (_CardBgStyle.solidDark, 'Tối Đậm'),
                      (_CardBgStyle.solidLight, 'Sáng Tinh Tế'),
                    ])
                      _StudioChip(
                        label: label,
                        selected: _bgStyle == st,
                        accent: accent,
                        onTap: () => setState(() => _bgStyle = st),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Color Palettes
                if (_bgStyle == _CardBgStyle.gradient) ...[
                  const Text(
                    'Bảng màu',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _palettes.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final pal = _palettes[i];
                        final selected = i == _paletteIdx;
                        return GestureDetector(
                          onTap: () => setState(() => _paletteIdx = i),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: pal.colors,
                              ),
                              border: Border.all(
                                color: selected ? Colors.white : Colors.white24,
                                width: selected ? 2.5 : 1,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Ratio, Alignment & Watermark
                Row(
                  children: [
                    _StudioChip(
                      label: '1:1 Post',
                      selected: !_storyRatio,
                      accent: accent,
                      onTap: () => setState(() => _storyRatio = false),
                    ),
                    const SizedBox(width: 8),
                    _StudioChip(
                      label: '9:16 Story',
                      selected: _storyRatio,
                      accent: accent,
                      onTap: () => setState(() => _storyRatio = true),
                    ),
                    const Spacer(),
                    for (final (al, icon) in [
                      (LyricsAlign.left, Icons.format_align_left_rounded),
                      (LyricsAlign.center, Icons.format_align_center_rounded),
                      (LyricsAlign.right, Icons.format_align_right_rounded),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: GestureDetector(
                          onTap: () => setState(() => _align = al),
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: _align == al
                                  ? accent.withValues(alpha: 0.30)
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                            child: Icon(icon, size: 17, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Font Size + Personal Watermark toggle
                Row(
                  children: [
                    const Text(
                      'Cỡ chữ',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Expanded(
                      child: Slider(
                        value: _fontSize,
                        min: 16,
                        max: 28,
                        activeColor: accent,
                        inactiveColor: Colors.white24,
                        onChanged: (v) => setState(() => _fontSize = v),
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _showWatermark = !_showWatermark),
                      child: Row(
                        children: [
                          Icon(
                            _showWatermark
                                ? Icons.verified_rounded
                                : Icons.verified_outlined,
                            color: _showWatermark ? accent : Colors.white38,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Chữ ký',
                            style: TextStyle(
                              color: _showWatermark
                                  ? Colors.white
                                  : Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildExportableCard() {
    final palette = _palettes[_paletteIdx];
    final isLight = _bgStyle == _CardBgStyle.solidLight ||
        (_bgStyle == _CardBgStyle.gradient && !palette.lightText);
    final fg = isLight ? const Color(0xFF14151D) : Colors.white;
    final fgMuted = isLight
        ? const Color(0xFF14151D).withValues(alpha: 0.62)
        : Colors.white.withValues(alpha: 0.72);
    final textAlign = switch (_align) {
      LyricsAlign.left => TextAlign.left,
      LyricsAlign.center => TextAlign.center,
      LyricsAlign.right => TextAlign.right,
    };

    return AspectRatio(
      aspectRatio: _storyRatio ? 9 / 16 : 1.0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background layer
            if (_bgStyle == _CardBgStyle.gradient)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: palette.colors,
                  ),
                ),
              )
            else if (_bgStyle == _CardBgStyle.solidDark)
              const ColoredBox(color: Color(0xFF12131A))
            else if (_bgStyle == _CardBgStyle.solidLight)
              const ColoredBox(color: Color(0xFFF3F5F9))
            else ...[
              const ColoredBox(color: Color(0xFF12131A)),
              if (widget.track.artworkUrl.isNotEmpty)
                ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                  child: Image.network(
                    widget.track.artworkUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ColoredBox(color: Colors.black.withValues(alpha: 0.42)),
            ],

            // Subtle glass rim inside the card
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: fg.withValues(alpha: 0.16),
                  width: 1.0,
                ),
              ),
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header: Track Artwork + Song Info
                  Row(
                    children: [
                      ArtworkImage(
                        url: widget.track.artworkUrl,
                        size: 46,
                        radius: 11,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: fg,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: fgMuted,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Selected Lyric Lines
                  Column(
                    crossAxisAlignment: switch (_align) {
                      LyricsAlign.left => CrossAxisAlignment.start,
                      LyricsAlign.center => CrossAxisAlignment.center,
                      LyricsAlign.right => CrossAxisAlignment.end,
                    },
                    children: _selectedLines.map((line) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          line,
                          textAlign: textAlign,
                          style: TextStyle(
                            color: fg,
                            fontSize: _storyRatio ? _fontSize : (_fontSize - 2),
                            fontWeight: FontWeight.w800,
                            height: 1.26,
                            letterSpacing: -0.3,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const Spacer(),

                  // Footer Watermark (Lemielmusic + User Profile)
                  if (_showWatermark)
                    Row(
                      children: [
                        ProfileAvatar(
                          profile: widget.profile,
                          accentColor: widget.accentColor,
                          size: 22,
                          borderColor: fg.withValues(alpha: 0.30),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Lemielmusic • ${widget.profile.displayName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: fgMuted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        Icon(Icons.graphic_eq_rounded, size: 16, color: fgMuted),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudioChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _StudioChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SpringTap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? accent.withValues(alpha: 0.30)
              : Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: selected ? accent : Colors.white12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
