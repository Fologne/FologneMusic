import 'package:flutter/services.dart';

import 'models.dart';

abstract class MediaLibrary {
  Future<bool> permission({bool request = false});
  Future<List<Track>> scan();
  Future<bool> delete(String id);
  Future<void> openSettings();
}

class AndroidMediaLibrary implements MediaLibrary {
  static const channel = MethodChannel('musicapp/media');
  @override
  Future<bool> permission({bool request = false}) async =>
      await channel.invokeMethod<bool>(
        request ? 'requestPermission' : 'hasPermission',
      ) ??
      false;
  @override
  Future<List<Track>> scan() async {
    final data = await channel.invokeListMethod<dynamic>('scan') ?? [];
    return data
        .map((row) => Track.fromJson(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  @override
  Future<void> openSettings() => channel.invokeMethod<void>('openSettings');
  @override
  Future<bool> delete(String id) async =>
      await channel.invokeMethod<bool>('deleteTrack', {'uri': id}) ?? false;
  static Future<Uint8List?> artwork(String uri) =>
      channel.invokeMethod<Uint8List>('artwork', {'uri': uri});
  static Future<String?> notificationArtwork(String uri) =>
      channel.invokeMethod<String>('notificationArtwork', {'uri': uri});
  static Future<bool> openSource(Uri uri) async =>
      await channel.invokeMethod<bool>('openSource', {'url': uri.toString()}) ??
      false;
}
