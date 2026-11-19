import '../models/track.dart';

class LocalAudioProxy {
  Future<Uri> registerStream(
    String id,
    ResolvedAudioStream stream, {
    bool enableCache = true,
  }) async =>
      Uri.parse(stream.url);

  bool isFullyCached(String id) => false;

  Future<void> dispose() async {}
}
