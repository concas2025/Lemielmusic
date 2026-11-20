import 'dart:math';
import 'package:material_ui/material_ui.dart';
import 'track.dart';

class UserProfile {
  static const List<List<Color>> avatarGradients = [
    [Color(0xFFFF375F), Color(0xFF6E6BF5)],
    [Color(0xFF6E6BF5), Color(0xFF2DD4BF)],
    [Color(0xFFFF9F0A), Color(0xFFFF375F)],
    [Color(0xFF2DD4BF), Color(0xFF2F80ED)],
    [Color(0xFFEA7FA2), Color(0xFF7B61FF)],
    [Color(0xFF525866), Color(0xFF222530)],
  ];

  final String displayName;
  final String bio;
  final String? avatarPath;
  final int avatarPresetIndex;
  final String memberId;
  final String joinedDate;
  final bool silverCard;
  final bool onboardingDone;
  final int totalPlays;
  final Map<String, int> artistPlays;

  const UserProfile({
    required this.displayName,
    this.bio = 'Âm nhạc là ngôn ngữ của cảm xúc',
    this.avatarPath,
    this.avatarPresetIndex = 0,
    required this.memberId,
    required this.joinedDate,
    this.silverCard = false,
    this.onboardingDone = false,
    this.totalPlays = 0,
    this.artistPlays = const {},
  });

  factory UserProfile.createDefault() {
    final now = DateTime.now();
    final rnd = Random();
    final code = (1000 + rnd.nextInt(9000)).toString();
    final mm = now.month.toString().padLeft(2, '0');
    final yyyy = now.year.toString();
    return UserProfile(
      displayName: 'Người nghe Lemiel',
      bio: 'Âm nhạc là ngôn ngữ của cảm xúc',
      memberId: 'LM-$yyyy-$code',
      joinedDate: '$mm/$yyyy',
      silverCard: false,
      onboardingDone: false,
    );
  }

  List<Color> get avatarColors =>
      avatarGradients[avatarPresetIndex.clamp(0, avatarGradients.length - 1)];

  String get initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'L';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  List<MapEntry<String, int>> get topArtists {
    final entries = artistPlays.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(4).toList(growable: false);
  }

  UserProfile copyWith({
    String? displayName,
    String? bio,
    String? avatarPath,
    bool clearAvatar = false,
    int? avatarPresetIndex,
    String? memberId,
    String? joinedDate,
    bool? silverCard,
    bool? onboardingDone,
    int? totalPlays,
    Map<String, int>? artistPlays,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      avatarPath: clearAvatar ? null : (avatarPath ?? this.avatarPath),
      avatarPresetIndex: avatarPresetIndex ?? this.avatarPresetIndex,
      memberId: memberId ?? this.memberId,
      joinedDate: joinedDate ?? this.joinedDate,
      silverCard: silverCard ?? this.silverCard,
      onboardingDone: onboardingDone ?? this.onboardingDone,
      totalPlays: totalPlays ?? this.totalPlays,
      artistPlays: artistPlays ?? this.artistPlays,
    );
  }

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'bio': bio,
        'avatarPath': avatarPath,
        'avatarPresetIndex': avatarPresetIndex,
        'memberId': memberId,
        'joinedDate': joinedDate,
        'silverCard': silverCard,
        'onboardingDone': onboardingDone,
        'totalPlays': totalPlays,
        'artistPlays': artistPlays,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawArtists = (json['artistPlays'] as Map?) ?? const {};
    final artists = <String, int>{};
    for (final entry in rawArtists.entries) {
      final k = entry.key.toString();
      final v = (entry.value as num?)?.toInt() ?? 0;
      if (k.isNotEmpty && v > 0) artists[k] = v;
    }
    final fallback = UserProfile.createDefault();
    return UserProfile(
      displayName: (json['displayName'] as String?)?.trim().isNotEmpty == true
          ? (json['displayName'] as String).trim()
          : fallback.displayName,
      bio: json['bio'] as String? ?? fallback.bio,
      avatarPath: json['avatarPath'] as String?,
      avatarPresetIndex:
          ((json['avatarPresetIndex'] as num?)?.toInt() ?? 0)
              .clamp(0, avatarGradients.length - 1),
      memberId: (json['memberId'] as String?)?.isNotEmpty == true
          ? json['memberId'] as String
          : fallback.memberId,
      joinedDate: (json['joinedDate'] as String?)?.isNotEmpty == true
          ? json['joinedDate'] as String
          : fallback.joinedDate,
      silverCard: json['silverCard'] as bool? ?? false,
      onboardingDone: json['onboardingDone'] as bool? ?? false,
      totalPlays: (json['totalPlays'] as num?)?.toInt() ?? 0,
      artistPlays: artists,
    );
  }
}

class LocalPlaylist {
  final String id;
  final String name;
  final List<Track> tracks;
  final String createdAt;
  final String sourcePlatform; // local | spotify | apple_music | youtube_music

  const LocalPlaylist({
    required this.id,
    required this.name,
    required this.tracks,
    required this.createdAt,
    this.sourcePlatform = 'local',
  });

  String get platformLabel => switch (sourcePlatform) {
        'spotify' => 'Spotify',
        'apple_music' => 'Apple Music',
        'youtube_music' => 'YouTube Music',
        _ => 'Cá nhân',
      };

  LocalPlaylist copyWith({
    String? name,
    List<Track>? tracks,
  }) =>
      LocalPlaylist(
        id: id,
        name: name ?? this.name,
        tracks: tracks ?? this.tracks,
        createdAt: createdAt,
        sourcePlatform: sourcePlatform,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tracks': tracks.map((t) => t.toJson()).toList(),
        'createdAt': createdAt,
        'sourcePlatform': sourcePlatform,
      };

  factory LocalPlaylist.fromJson(Map<String, dynamic> json) {
    final rawTracks = (json['tracks'] as List?) ?? const [];
    return LocalPlaylist(
      id: json['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? 'Playlist mới',
      tracks: rawTracks
          .whereType<Map<String, dynamic>>()
          .map(Track.fromJson)
          .toList(),
      createdAt: json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      sourcePlatform: json['sourcePlatform'] as String? ?? 'local',
    );
  }
}
