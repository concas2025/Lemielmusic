import 'dart:typed_data';
import '../models/track.dart';

class LocalAudioProxy {
  final Future<ResolvedAudioStream?> Function(String id)? onRefreshStream;

  LocalAudioProxy({this.onRefreshStream});

  Future<Uri> registerStream(
    String id,
    ResolvedAudioStream stream, {
    bool enableCache = true,
  }) async =>
      Uri.parse(stream.url);

  static bool normalizeFragmentedMp4Header(Uint8List bytes) => false;

  bool isFullyCached(String id) => false;

  Future<void> dispose() async {}
}
