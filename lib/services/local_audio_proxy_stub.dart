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

  bool isFullyCached(String id) => false;

  Future<void> dispose() async {}
}
