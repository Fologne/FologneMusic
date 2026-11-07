import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:music_app/library/media_library.dart';
import 'package:music_app/library/models.dart';
import 'package:music_app/library/music_store.dart';

const testTracks = [
  Track(
    id: 'content://media/external/audio/media/1',
    title: 'Maré noturna',
    artist: 'Artista de teste',
    album: 'Álbum de teste',
    durationMs: 60000,
    folder: 'Music/Test',
    addedAt: 1000,
  ),
  Track(
    id: 'content://media/external/audio/media/2',
    title: 'Horizonte',
    artist: 'Outro artista',
    album: 'Outro álbum',
    durationMs: 12000,
    folder: 'Music/Outros',
    addedAt: 2000,
  ),
];

class FakeMedia implements MediaLibrary {
  bool allowed = true;
  bool failScan = false;
  List<Track> rows = List.of(testTracks);
  @override
  Future<bool> permission({bool request = false}) async => allowed;
  @override
  Future<List<Track>> scan() async {
    if (failScan) throw StateError('scan failed');
    return rows;
  }

  @override
  Future<void> openSettings() async {}
}

class MemoryStore implements MusicStore {
  List<Track> tracks = [];
  Map<String, dynamic> state = {};
  @override
  Future<List<Track>> readTracks() async => List.of(tracks);
  @override
  Future<void> writeTracks(List<Track> value) async {
    tracks = List.of(value);
  }

  @override
  Future<Map<String, dynamic>> readState() async =>
      jsonDecode(jsonEncode(state)) as Map<String, dynamic>;
  @override
  Future<void> writeState(Map<String, dynamic> value) async {
    state = jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
  }
}

class FakeHandler extends BaseAudioHandler {
  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    if (name == 'load') {
      final tracks = (extras!['tracks'] as List)
          .map((row) => Track.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
      queue.add(tracks.map((t) => t.toMediaItem()).toList());
      final index = tracks.isEmpty
          ? 0
          : (extras['index'] as int).clamp(0, tracks.length - 1);
      mediaItem.add(tracks.isEmpty ? null : tracks[index].toMediaItem());
      playbackState.add(
        playbackState.value.copyWith(
          playing: extras['play'] == true,
          processingState: AudioProcessingState.ready,
          queueIndex: index,
          updatePosition: Duration(
            milliseconds: extras['positionMs'] as int? ?? 0,
          ),
        ),
      );
    } else if (name == 'reorder') {
      final items = List<MediaItem>.of(queue.value);
      items.insert(extras!['to'] as int, items.removeAt(extras['from'] as int));
      queue.add(items);
    }
  }

  @override
  Future<void> play() async {
    playbackState.add(playbackState.value.copyWith(playing: true));
  }

  @override
  Future<void> pause() async {
    playbackState.add(playbackState.value.copyWith(playing: false));
  }

  @override
  Future<void> stop() => pause();
  @override
  Future<void> seek(Duration position) async {
    playbackState.add(playbackState.value.copyWith(updatePosition: position));
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    playbackState.add(playbackState.value.copyWith(repeatMode: repeatMode));
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    playbackState.add(playbackState.value.copyWith(shuffleMode: shuffleMode));
  }
}
