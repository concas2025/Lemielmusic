import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/app_settings.dart';
import '../models/user_profile.dart';
import 'storage_service.dart';

class SettingsController extends ChangeNotifier {
  final StorageService storage;
  AppSettings _settings = const AppSettings();
  UserProfile _profile = UserProfile.createDefault();

  SettingsController({required this.storage});

  AppSettings get settings => _settings;
  UserProfile get profile => _profile;

  Future<void> init() async {
    await storage.init();
    _settings = storage.loadSettings();
    _profile = storage.loadProfile();
    notifyListeners();
  }

  void updateSettings(AppSettings next) {
    _settings = next;
    notifyListeners();
    unawaited(storage.saveSettings(next));
  }

  void setPlayerStyle(PlayerStyle style) =>
      updateSettings(_settings.copyWith(playerStyle: style));

  void setBackgroundStyle(PlayerBackgroundStyle style) =>
      updateSettings(_settings.copyWith(backgroundStyle: style));

  void setSliderStyle(SliderStyle style) =>
      updateSettings(_settings.copyWith(sliderStyle: style));

  void setLyricsStyle(LyricsStyle style) =>
      updateSettings(_settings.copyWith(lyricsStyle: style));

  void setLyricsAlign(LyricsAlign align) =>
      updateSettings(_settings.copyWith(lyricsAlign: align));

  void setLyricsFontSize(double size) =>
      updateSettings(_settings.copyWith(lyricsFontSize: size.clamp(16.0, 28.0)));

  void setBlurInactiveLyrics(bool value) =>
      updateSettings(_settings.copyWith(blurInactiveLyrics: value));

  void setAudioQuality(AudioQualityTier tier) =>
      updateSettings(_settings.copyWith(audioQuality: tier));

  void setAccentPreset(AccentPreset preset) =>
      updateSettings(_settings.copyWith(accentPreset: preset));

  void setGlassQuality(GlassQuality quality) =>
      updateSettings(_settings.copyWith(glassQuality: quality));

  void toggleLyricsProvider(String providerId, bool enabled) {
    final next = List<String>.from(_settings.enabledLyricsProviders);
    if (enabled) {
      if (!next.contains(providerId)) next.add(providerId);
    } else if (next.length > 1) {
      // Keep at least one provider enabled so lyrics always have a source.
      next.remove(providerId);
    }
    updateSettings(_settings.copyWith(enabledLyricsProviders: next));
  }

  void moveLyricsProvider(int oldIndex, int newIndex) {
    final list = List<String>.from(_settings.lyricsProviderOrder);
    if (oldIndex < 0 || oldIndex >= list.length) return;
    final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    final item = list.removeAt(oldIndex);
    list.insert(target.clamp(0, list.length), item);
    updateSettings(_settings.copyWith(lyricsProviderOrder: list));
  }

  void setPlaybackSpeed(double speed) =>
      updateSettings(_settings.copyWith(playbackSpeed: speed.clamp(0.5, 2.0)));

  void setPlaybackPitch(double pitch) =>
      updateSettings(_settings.copyWith(playbackPitch: pitch.clamp(0.5, 2.0)));

  void applyEqPreset(String presetName) {
    final bands = AppSettings.eqPresets[presetName];
    if (bands == null) return;
    updateSettings(_settings.copyWith(
      eqPreset: presetName,
      eqBands: List<double>.from(bands),
    ));
  }

  void setEqBand(int index, double gainDb) {
    if (index < 0 || index >= 5) return;
    final bands = List<double>.from(_settings.eqBands);
    bands[index] = gainDb.clamp(-12.0, 12.0);
    updateSettings(_settings.copyWith(eqPreset: 'Custom', eqBands: bands));
  }

  void updateProfile(UserProfile next) {
    _profile = next;
    notifyListeners();
    unawaited(storage.saveProfile(next));
  }

  void toggleCardFinish() {
    updateProfile(_profile.copyWith(silverCard: !_profile.silverCard));
  }

  void recordTrackPlay(String artist) {
    final cleanArtist = artist.split(RegExp(r'[,&•]')).first.trim();
    final updatedArtists = Map<String, int>.from(_profile.artistPlays);
    if (cleanArtist.isNotEmpty) {
      updatedArtists[cleanArtist] = (updatedArtists[cleanArtist] ?? 0) + 1;
    }
    updateProfile(_profile.copyWith(
      totalPlays: _profile.totalPlays + 1,
      artistPlays: updatedArtists,
    ));
  }
}
