import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../library/models.dart';
import 'content_api.dart';

class SavedTrackTexts {
  const SavedTrackTexts(
    this.key,
    this.title,
    this.artist,
    this.bytes,
    this.kinds,
  );
  final String key;
  final String title;
  final String artist;
  final int bytes;
  final Set<TextKind> kinds;
}

class TextStore {
  TextStore(this.directory, {this.maxBytes = 20 * 1024 * 1024});
  final Directory directory;
  final int maxBytes;
  Future<void> _writes = Future.value();

  static String keyFor(Track track) => sha256
      .convert(
        utf8.encode(
          jsonEncode([
            track.id,
            track.addedAt,
            track.title,
            track.artist,
            track.durationMs,
          ]),
        ),
      )
      .toString();

  File _file(String key) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(key)) {
      throw ArgumentError('Identificador de download inválido');
    }
    return File(p.join(directory.path, '$key.json'));
  }

  Future<Map<String, dynamic>?> _read(File file) async {
    try {
      if (!await file.exists() || await file.length() > maxBytes) return null;
      final data = jsonDecode(await file.readAsString());
      if (data is! Map<String, dynamic> ||
          data['schema_version'] != 1 ||
          data['texts'] is! Map<String, dynamic>) {
        return null;
      }
      return data;
    } on FormatException {
      return null;
    } on PathNotFoundException {
      return null;
    }
  }

  TrackText? _text(Map<String, dynamic>? data, TextKind kind) {
    try {
      final raw = (data?['texts'] as Map<String, dynamic>?)?[kind.name];
      if (raw is! Map<String, dynamic> ||
          raw['content'] is! Map<String, dynamic>) {
        return null;
      }
      final text = TrackText.fromJson(raw['content']);
      return text.offlineAllowed ? text : null;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<TrackText?> read(Track track, TextKind kind) async =>
      _text(await _read(_file(keyFor(track))), kind);

  Future<List<SavedTrackTexts>> entries() async {
    if (!await directory.exists()) return [];
    final items = <SavedTrackTexts>[];
    await for (final file in directory.list(followLinks: false)) {
      if (file is! File ||
          !RegExp(r'^[a-f0-9]{64}\.json$').hasMatch(p.basename(file.path))) {
        continue;
      }
      final data = await _read(file);
      final kinds = TextKind.values
          .where((kind) => _text(data, kind) != null)
          .toSet();
      items.add(
        SavedTrackTexts(
          p.basenameWithoutExtension(file.path),
          data?['title'] is String
              ? data!['title']
              : 'Arquivo de texto indisponível',
          data?['artist'] is String ? data!['artist'] : '',
          await file.length(),
          kinds,
        ),
      );
    }
    return items..sort((a, b) => a.title.compareTo(b.title));
  }

  Future<void> _serialize(Future<void> Function() operation) {
    final next = _writes.then((_) => operation());
    _writes = next.then((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<void> save(
    Track track,
    TextKind kind,
    String trackKey,
    TrackText text,
  ) => _serialize(() async {
    if (!text.offlineAllowed) {
      throw const ContentFailure(
        'Esta fonte não permite salvar o texto offline.',
      );
    }
    final key = keyFor(track);
    final file = _file(key);
    final previous = await _read(file);
    final bytes = utf8.encode(
      jsonEncode({
        'schema_version': 1,
        'title': track.title,
        'artist': track.artist,
        'texts': {
          ...?previous?['texts'] as Map<String, dynamic>?,
          kind.name: {'track_key': trackKey, 'content': text.toJson()},
        },
      }),
    );
    final used = (await entries())
        .where((entry) => entry.key != key)
        .fold(0, (total, entry) => total + entry.bytes);
    if (used + bytes.length > maxBytes) {
      throw const ContentFailure(
        'Limite de 20 MiB atingido. Remova um download nas configurações.',
      );
    }
    await directory.create(recursive: true);
    final temp = File('${file.path}.tmp');
    try {
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(file.path);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  });

  Future<void> remove(String key) => _serialize(() async {
    final file = _file(key);
    if (await file.exists()) await file.delete();
  });
}
