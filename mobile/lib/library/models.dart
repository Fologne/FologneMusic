import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    required this.folder,
    required this.addedAt,
    this.createdAt,
    this.available = true,
  });
  final String id;
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final String folder;
  final int addedAt;
  final int? createdAt;
  final bool available;
  int get seconds => durationMs ~/ 1000;
  Color get color => const Color(0xFF437CA1);
  int get style => id.hashCode.abs() % 4;

  factory Track.fromJson(Map<String, dynamic> json) => Track(
    id: json['id'] as String,
    title: json['title'] as String,
    artist: json['artist'] as String,
    album: json['album'] as String,
    durationMs: (json['durationMs'] as num).toInt(),
    folder: json['folder'] as String,
    addedAt: (json['addedAt'] as num).toInt(),
    createdAt: (json['createdAt'] as num?)?.toInt(),
    available: json['available'] as bool? ?? true,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'album': album,
    'durationMs': durationMs,
    'folder': folder,
    'addedAt': addedAt,
    'createdAt': createdAt,
    'available': available,
  };
  Track missing() => Track.fromJson({...toJson(), 'available': false});
  MediaItem toMediaItem() => MediaItem(
    id: id,
    title: title,
    artist: artist,
    album: album,
    duration: Duration(milliseconds: durationMs),
    extras: toJson(),
  );
}

class MusicPlaylist {
  MusicPlaylist({
    required this.id,
    required this.name,
    List<String>? trackIds,
    this.coverId,
  }) : trackIds = trackIds ?? [];
  final String id;
  String name;
  List<String> trackIds;
  String? coverId;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'trackIds': trackIds,
    'coverId': coverId,
  };
  factory MusicPlaylist.fromJson(Map<String, dynamic> json) => MusicPlaylist(
    id: json['id'] as String,
    name: json['name'] as String,
    trackIds: List<String>.from(json['trackIds'] as List),
    coverId: json['coverId'] as String?,
  );
}

class ListenEntry {
  const ListenEntry(this.trackId, this.at);
  final String trackId;
  final int at;
  Map<String, dynamic> toJson() => {'trackId': trackId, 'at': at};
  factory ListenEntry.fromJson(Map<String, dynamic> json) =>
      ListenEntry(json['trackId'] as String, (json['at'] as num).toInt());
}
