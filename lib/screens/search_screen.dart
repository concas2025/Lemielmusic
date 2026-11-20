import 'dart:async';
import 'package:material_ui/material_ui.dart';
import '../models/track.dart';
import '../services/player_controller.dart';
import '../services/settings_controller.dart';
import '../services/ytm_service.dart';
import '../widgets/glass.dart';
import 'library_screen.dart';

/// BitChord monochrome editorial Search Screen:
/// Pure black #000000 canvas, smoked Liquid Glass pill search bar, clean
/// history rows with north-west autofill arrow, borderless track results.
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
          padding: EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Text(
            'Tìm kiếm',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.9,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GlassSurface(
            borderRadius: 24,
            blur: 22,
            isLens: true,
            highQuality: settings.highGlass,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: TextField(
              controller: _textCtrl,
              onChanged: _onQueryChanged,
              onSubmitted: (q) => _runSearch(q, saveHistory: true),
              style: const TextStyle(color: Colors.white, fontSize: 15),
              cursorColor: Colors.white,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Bài hát, nghệ sĩ, album...',
                hintStyle: const TextStyle(color: Color(0xFF8E8E93)),
                icon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF8E8E93),
                  size: 21,
                ),
                suffixIcon: _textCtrl.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _textCtrl.clear();
                          _onQueryChanged('');
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF8E8E93),
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
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.2,
                  ),
                )
              : _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFF8E8E93)),
                      ),
                    )
                  : _textCtrl.text.trim().isEmpty
                      ? _buildSearchHistory(history)
                      : _results.isEmpty
                          ? const Center(
                              child: Text(
                                'Không tìm thấy kết quả phù hợp.',
                                style: TextStyle(color: Color(0xFF8E8E93)),
                              ),
                            )
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding:
                                  const EdgeInsets.fromLTRB(10, 0, 10, 175),
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

  Widget _buildSearchHistory(List<String> history) {
    if (history.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 28),
          child: Text(
            'Nhập tên bài hát hoặc nghệ sĩ để tìm trên YouTube Music.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF636366), fontSize: 14),
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 175),
      itemCount: history.length + 1,
      separatorBuilder: (_, idx) => idx == 0
          ? const SizedBox(height: 6)
          : Container(height: 0.5, color: const Color(0xFF1C1C20)),
      itemBuilder: (_, i) {
        if (i == 0) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              'Gần đây',
              style: TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }
        final q = history[i - 1];
        return InkWell(
          onTap: () {
            _textCtrl.text = q;
            _textCtrl.selection = TextSelection.fromPosition(
              TextPosition(offset: q.length),
            );
            _runSearch(q, saveHistory: true);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.history_rounded,
                  size: 19,
                  color: Color(0xFF636366),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    q,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => widget.controller.removeSearchQuery(q),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      size: 17,
                      color: Color(0xFF636366),
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
}
