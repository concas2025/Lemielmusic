import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../models/track.dart';
import '../models/user_profile.dart';

class StorageService {
  static const _favKey = 'lemiel_favorites_v1';
  static const _historyKey = 'lemiel_history_v1';
  static const _searchKey = 'lemiel_searches_v1';
  static const _settingsKey = 'lemiel_settings_v2';
  static const _profileKey = 'lemiel_profile_v2';
  static const _playlistsKey = 'lemiel_playlists_v2';

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

  AppSettings loadSettings() {
    final raw = _prefs?.getString(_settingsKey);
    if (raw == null || raw.isEmpty) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _prefs?.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  UserProfile loadProfile() {
    final raw = _prefs?.getString(_profileKey);
    if (raw == null || raw.isEmpty) {
      final fresh = UserProfile.createDefault();
      saveProfile(fresh);
      return fresh;
    }
    try {
      return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return UserProfile.createDefault();
    }
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _prefs?.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  List<LocalPlaylist> loadPlaylists() {
    final raw = _prefs?.getStringList(_playlistsKey) ?? const [];
    final out = <LocalPlaylist>[];
    for (final item in raw) {
      try {
        out.add(LocalPlaylist.fromJson(jsonDecode(item) as Map<String, dynamic>));
      } catch (_) {}
    }
    return out;
  }

  Future<void> savePlaylists(List<LocalPlaylist> playlists) async {
    final encoded = playlists.map((p) => jsonEncode(p.toJson())).toList();
    await _prefs?.setStringList(_playlistsKey, encoded);
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
