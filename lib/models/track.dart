import 'package:just_audio_background/just_audio_background.dart';

class Track {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String thumbnailUrl;
  final int durationSeconds;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    this.album = '',
    required this.thumbnailUrl,
    this.durationSeconds = 0,
  });

  /// Returns a crisp square-friendly thumbnail URL when hosted on Google's CDN.
  String get artworkUrl {
    if (thumbnailUrl.contains('lh3.googleusercontent.com') ||
        thumbnailUrl.contains('yt3.ggpht.com')) {
      return thumbnailUrl.replaceAll(
        RegExp(r'=w\d+-h\d+[^&]*'),
        '=w600-h600-l90-rj',
      );
    }
    if (thumbnailUrl.isEmpty && id.isNotEmpty) {
      return 'https://i.ytimg.com/vi/$id/hqdefault.jpg';
    }
    return thumbnailUrl;
  }

  String get formattedDuration {
    if (durationSeconds <= 0) return '';
    final m = durationSeconds ~/ 60;
    final s = (durationSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  MediaItem toMediaItem({Duration? durationOverride}) {
    final effectiveDur = (durationOverride != null && durationOverride > Duration.zero)
        ? durationOverride
        : (durationSeconds > 0 ? Duration(seconds: durationSeconds) : null);
    return MediaItem(
      id: id,
      title: title,
      artist: artist,
      album: album.isNotEmpty ? album : 'Lemielmusic',
      artUri: artworkUrl.isNotEmpty ? Uri.tryParse(artworkUrl) : null,
      duration: effectiveDur,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'thumbnailUrl': thumbnailUrl,
        'durationSeconds': durationSeconds,
      };

  factory Track.fromJson(Map<String, dynamic> json) => Track(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Unknown',
        artist: json['artist'] as String? ?? 'Unknown Artist',
        album: json['album'] as String? ?? '',
        thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
        durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      );

  @override
  bool operator ==(Object other) => other is Track && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class LyricLine {
  final Duration? time;
  final String text;

  const LyricLine({this.time, required this.text});
}

class LyricsResult {
  final List<LyricLine> lines;
  final String providerId;
  final String providerName;

  const LyricsResult({
    required this.lines,
    required this.providerId,
    required this.providerName,
  });

  bool get isEmpty => lines.isEmpty;
  bool get isNotEmpty => lines.isNotEmpty;
  bool get isSynced => lines.any((l) => l.time != null);

  static const empty = LyricsResult(
    lines: [],
    providerId: '',
    providerName: '',
  );
}

class ResolvedAudioStream {
  final String url;
  final int contentLength;
  final String mimeType;
  final String userAgent;
  final Duration? duration;

  const ResolvedAudioStream({
    required this.url,
    required this.contentLength,
    this.mimeType = 'audio/mp4',
    required this.userAgent,
    this.duration,
  });
}
