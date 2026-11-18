import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';

class StorageService {
  static const _favKey = 'lemiel_favorites_v1';
  static const _historyKey = 'lemiel_history_v1';
  static const _searchKey = 'lemiel_searches_v1';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  List<Track> loadFavorites() => _readTrackList(_favKey);

  Future<void> saveFavorites(List<Track> tracks) =>
      _writeTrackList(_favKey, tracks);

  List<Track> loadHistory() => _readTrackList(_historyKey);

  Future<void> saveHistory(List<Track> tracks) =>
      _writeTrackList(_historyKey, tracks);

  List<String> loadSearchHistory() => _prefs?.getStringList(_searchKey) ?? [];

  Future<void> saveSearchHistory(List<String> queries) async {
    await _prefs?.setStringList(_searchKey, queries);
  }

  List<Track> _readTrackList(String key) {
    final raw = _prefs?.getStringList(key) ?? const [];
    final out = <Track>[];
    for (final item in raw) {
      try {
        out.add(Track.fromJson(jsonDecode(item) as Map<String, dynamic>));
      } catch (_) {}
    }
    return out;
  }

  Future<void> _writeTrackList(String key, List<Track> tracks) async {
    final encoded = tracks.map((t) => jsonEncode(t.toJson())).toList();
    await _prefs?.setStringList(key, encoded);
  }
}
