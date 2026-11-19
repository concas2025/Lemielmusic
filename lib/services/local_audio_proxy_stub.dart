import '../models/track.dart';

class LocalAudioProxy {
  Future<Uri> registerStream(String id, ResolvedAudioStream stream) async {
    return Uri.parse(stream.url);
  }

  Future<void> dispose() async {}
}
