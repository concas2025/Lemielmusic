import 'dart:async';
import 'package:material_ui/material_ui.dart';
import '../models/track.dart';
import '../services/player_controller.dart';
import '../services/settings_controller.dart';
import '../services/ytm_service.dart';
import '../widgets/glass.dart';
import 'library_screen.dart';

class SearchScreen extends StatefulWidget {
  final PlayerController controller;
  final SettingsController settingsController;
  final YtmService ytm;

  const SearchScreen({
    super.key,
    required this.controller,
    required this.settingsController,
    required this.ytm,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _textCtrl = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  String? _error;
  List<Track> _results = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _textCtrl.dispose();
    super.dispose();
  }

  void _onQueryChanged(String val) {
    setState(() {});
    _debounce?.cancel();
    final trimmed = val.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = [];
        _loading = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 420), () {
      _runSearch(trimmed, saveHistory: false);
    });
  }

  Future<void> _runSearch(String query, {bool saveHistory = true}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    if (saveHistory) {
      widget.controller.addSearchQuery(trimmed);
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await widget.ytm.searchSongs(trimmed);
      if (!mounted || _textCtrl.text.trim() != trimmed) return;
      setState(() {
        _results = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Lỗi tìm kiếm. Vui lòng kiểm tra mạng và thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.controller.currentTrack;
    final history = widget.controller.searchHistory;
    final settings = widget.settingsController.settings;
    final accent = settings.accentColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: Text(
            'Tìm kiếm',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
            ),
          ),
        ),
        // Liquid Glass Lens Search Capsule (BitChord / iOS 26 style)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GlassSurface(
            borderRadius: 24,
            blur: 22,
            opacity: 0.14,
            isLens: true,
            highQuality: settings.highGlass,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
            child: TextField(
              controller: _textCtrl,
              onChanged: _onQueryChanged,
              onSubmitted: (q) => _runSearch(q, saveHistory: true),
              style: const TextStyle(color: Colors.white, fontSize: 15),
              cursorColor: accent,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Tên bài hát, nghệ sĩ, lời nhạc...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                ),
                icon: Icon(
                  Icons.search_rounded,
                  color: accent.withValues(alpha: 0.9),
                ),
                suffixIcon: _textCtrl.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _textCtrl.clear();
                          _onQueryChanged('');
                        },
                        icon: Icon(
                          Icons.close_rounded,
                          color: Colors.white.withValues(alpha: 0.65),
                          size: 19,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: accent))
              : _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    )
                  : _textCtrl.text.trim().isEmpty
                      ? _buildSearchHistory(history, settings.highGlass)
                      : _results.isEmpty
                          ? Center(
                              child: Text(
                                'Không tìm thấy kết quả phù hợp.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.55),
                                ),
                              ),
                            )
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding:
                                  const EdgeInsets.fromLTRB(12, 0, 12, 175),
                              itemCount: _results.length,
                              itemBuilder: (_, i) {
                                final track = _results[i];
                                return TrackTile(
                                  track: track,
                                  isCurrent: current?.id == track.id,
                                  isPlaying: widget.controller.isPlaying,
                                  isFavorite:
                                      widget.controller.isFavorite(track.id),
                                  accentColor: accent,
                                  onTap: () {
                                    widget.controller.addSearchQuery(
                                      _textCtrl.text,
                                    );
                                    widget.controller
                                        .playTrack(track, queue: _results);
                                  },
                                  onFavoriteTap: () =>
                                      widget.controller.toggleFavorite(track),
                                  onAddToPlaylist: () => showAddToPlaylistSheet(
                                    context,
                                    controller: widget.controller,
                                    track: track,
                                    accentColor: accent,
                                  ),
                                );
                              },
                            ),
        ),
      ],
    );
  }

  Widget _buildSearchHistory(List<String> history, bool highGlass) {
    if (history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Text(
            'Nhập tên bài hát hoặc nghệ sĩ để tìm trên YouTube Music.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.48),
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 175),
      children: [
        Text(
          'Tìm kiếm gần đây',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: history.map((q) {
            return SpringTap(
              onTap: () {
                _textCtrl.text = q;
                _textCtrl.selection = TextSelection.fromPosition(
                  TextPosition(offset: q.length),
                );
                _runSearch(q, saveHistory: true);
              },
              child: GlassSurface(
                borderRadius: 18,
                opacity: 0.10,
                highQuality: highGlass,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      q,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => widget.controller.removeSearchQuery(q),
                      child: Icon(
                        Icons.close_rounded,
                        size: 15,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
