import 'dart:async';
import 'dart:math';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/track.dart';
import 'local_audio_proxy.dart';
import 'storage_service.dart';
import 'ytm_service.dart';

enum PlayerRepeatMode { off, all, one }

class PlayerController extends ChangeNotifier {
  final YtmService ytm;
  final StorageService storage;
  final AudioPlayer _player = AudioPlayer(useProxyForRequestHeaders: false);
  final LocalAudioProxy _proxy = LocalAudioProxy();

  List<Track> _queue = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _isLoadingStream = false;
  bool _shuffle = false;
  PlayerRepeatMode _repeatMode = PlayerRepeatMode.off;
  String? _errorMessage;
  Duration _duration = Duration.zero;
  int _playSeq = 0;

  List<Track> _favorites = [];
  List<Track> _history = [];
  List<String> _searchHistory = [];

  final List<StreamSubscription<dynamic>> _subs = [];

  PlayerController({required this.ytm, required this.storage});

  List<Track> get queue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  Track? get currentTrack =>
      (_currentIndex >= 0 && _currentIndex < _queue.length)
          ? _queue[_currentIndex]
          : null;
  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  bool get isLoadingStream => _isLoadingStream;
  bool get shuffle => _shuffle;
  PlayerRepeatMode get repeatMode => _repeatMode;
  String? get errorMessage => _errorMessage;
  Duration get duration => _duration;
  Stream<Duration> get positionStream => _player.positionStream;
  Duration get currentPosition => _player.position;

  List<Track> get favorites => List.unmodifiable(_favorites);
  List<Track> get history => List.unmodifiable(_history);
  List<String> get searchHistory => List.unmodifiable(_searchHistory);

  bool isFavorite(String id) => _favorites.any((t) => t.id == id);

  Future<void> init() async {
    await storage.init();
    _favorites = storage.loadFavorites();
    _history = storage.loadHistory();
    _searchHistory = storage.loadSearchHistory();

    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (_) {}

    _subs.add(_player.playerStateStream.listen((state) {
      final playing = state.playing;
      final buffering = state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering;

      if (state.processingState == ProcessingState.completed) {
        _onTrackCompleted();
        return;
      }

      if (_isPlaying != playing || _isBuffering != buffering) {
        _isPlaying = playing;
        _isBuffering = buffering;
        notifyListeners();
      }
    }));

    _subs.add(_player.durationStream.listen((d) {
      if (d != null && d != _duration) {
        _duration = d;
        notifyListeners();
      }
    }));

    _subs.add(_player.errorStream.listen((err) {
      _isLoadingStream = false;
      _isBuffering = false;
      _isPlaying = false;
      final detail = err.message ?? 'Mã lỗi ${err.code}';
      _errorMessage = 'Lỗi trình phát: $detail';
      notifyListeners();
    }));

    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> playTrack(Track track, {List<Track>? queue}) async {
    if (queue != null && queue.isNotEmpty) {
      _queue = List.of(queue);
      final idx = _queue.indexWhere((t) => t.id == track.id);
      if (idx == -1) {
        _queue.insert(0, track);
        _currentIndex = 0;
      } else {
        _currentIndex = idx;
      }
    } else {
      final idx = _queue.indexWhere((t) => t.id == track.id);
      if (idx != -1) {
        _currentIndex = idx;
      } else {
        _queue = [track];
        _currentIndex = 0;
      }
    }

    await _startCurrentTrack();
  }

  Future<void> playAtIndex(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    await _startCurrentTrack();
  }

  void addToQueue(Track track) {
    if (_queue.isEmpty) {
      playTrack(track);
      return;
    }
    if (!_queue.any((t) => t.id == track.id)) {
      _queue.add(track);
      notifyListeners();
    }
  }

  Future<void> _startCurrentTrack() async {
    final track = currentTrack;
    if (track == null) return;

    final seq = ++_playSeq;
    _errorMessage = null;
    _isLoadingStream = true;
    _duration = track.durationSeconds > 0
        ? Duration(seconds: track.durationSeconds)
        : Duration.zero;
    _recordHistory(track);
    notifyListeners();

    try {
      final resolved = await ytm.resolveAudioStream(track.id);
      if (seq != _playSeq) return;

      final playUri = await _proxy.registerStream(track.id, resolved);
      if (seq != _playSeq) return;

      final source = AudioSource.uri(
        playUri,
        tag: track.toMediaItem(),
      );
      await _player.setAudioSource(source);
      if (seq != _playSeq) return;

      _isLoadingStream = false;
      notifyListeners();
      await _player.play();

      // Prefetch Up Next recommendations silently when near the end of the queue.
      if (_currentIndex >= _queue.length - 2) {
        unawaited(_appendRadioTracks(track.id));
      }
    } catch (e) {
      if (seq != _playSeq) return;
      _isLoadingStream = false;
      _isPlaying = false;
      final raw = e.toString().replaceFirst('Exception: ', '');
      final detail = raw.length > 140 ? '${raw.substring(0, 140)}...' : raw;
      _errorMessage = 'Không thể phát "${track.title}": $detail';
      notifyListeners();
    }
  }

  Future<void> _appendRadioTracks(String videoId) async {
    final related = await ytm.fetchUpNext(videoId);
    if (related.isEmpty) return;
    final existingIds = _queue.map((t) => t.id).toSet();
    final additions =
        related.where((t) => !existingIds.contains(t.id)).take(10).toList();
    if (additions.isNotEmpty) {
      _queue.addAll(additions);
      notifyListeners();
    }
  }

  Future<void> togglePlayPause() async {
    if (_isLoadingStream) return;
    if (_player.playing) {
      await _player.pause();
    } else {
      if (_player.processingState == ProcessingState.idle && currentTrack != null) {
        await _startCurrentTrack();
      } else {
        await _player.play();
      }
    }
  }

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> next({bool autoAdvance = false}) async {
    if (_queue.isEmpty) return;

    if (_shuffle && _queue.length > 1) {
      final rnd = Random();
      int nextIdx = _currentIndex;
      while (nextIdx == _currentIndex) {
        nextIdx = rnd.nextInt(_queue.length);
      }
      _currentIndex = nextIdx;
      await _startCurrentTrack();
      return;
    }

    if (_currentIndex + 1 < _queue.length) {
      _currentIndex++;
      await _startCurrentTrack();
    } else if (_repeatMode == PlayerRepeatMode.all) {
      _currentIndex = 0;
      await _startCurrentTrack();
    } else if (!autoAdvance) {
      _currentIndex = 0;
      await _startCurrentTrack();
    } else {
      final lastId = currentTrack?.id;
      if (lastId != null) {
        await _appendRadioTracks(lastId);
        if (_currentIndex + 1 < _queue.length) {
          _currentIndex++;
          await _startCurrentTrack();
          return;
        }
      }
      _isPlaying = false;
      notifyListeners();
    }
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }
    if (_currentIndex > 0) {
      _currentIndex--;
    } else {
      _currentIndex = _queue.length - 1;
    }
    await _startCurrentTrack();
  }

  void _onTrackCompleted() {
    if (_repeatMode == PlayerRepeatMode.one) {
      _player.seek(Duration.zero).then((_) => _player.play());
      return;
    }
    unawaited(next(autoAdvance: true));
  }

  void toggleShuffle() {
    _shuffle = !_shuffle;
    notifyListeners();
  }

  void cycleRepeatMode() {
    _repeatMode = switch (_repeatMode) {
      PlayerRepeatMode.off => PlayerRepeatMode.all,
      PlayerRepeatMode.all => PlayerRepeatMode.one,
      PlayerRepeatMode.one => PlayerRepeatMode.off,
    };
    notifyListeners();
  }

  Future<void> toggleFavorite(Track track) async {
    final idx = _favorites.indexWhere((t) => t.id == track.id);
    if (idx != -1) {
      _favorites.removeAt(idx);
    } else {
      _favorites.insert(0, track);
    }
    notifyListeners();
    await storage.saveFavorites(_favorites);
  }

  void _recordHistory(Track track) {
    _history.removeWhere((t) => t.id == track.id);
    _history.insert(0, track);
    if (_history.length > 40) {
      _history = _history.sublist(0, 40);
    }
    unawaited(storage.saveHistory(_history));
  }

  Future<void> addSearchQuery(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    _searchHistory.remove(q);
    _searchHistory.insert(0, q);
    if (_searchHistory.length > 10) {
      _searchHistory = _searchHistory.sublist(0, 10);
    }
    notifyListeners();
    await storage.saveSearchHistory(_searchHistory);
  }

  Future<void> removeSearchQuery(String query) async {
    _searchHistory.remove(query);
    notifyListeners();
    await storage.saveSearchHistory(_searchHistory);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    unawaited(_proxy.dispose());
    _player.dispose();
    super.dispose();
  }
}
