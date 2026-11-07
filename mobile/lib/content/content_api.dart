import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../library/models.dart';

enum TextKind {
  lyrics('Letra'),
  meaning('Significado');

  const TextKind(this.label);
  final String label;
}

class SearchTrack {
  const SearchTrack(this.title, this.artist, this.album, this.durationMs);
  factory SearchTrack.fromTrack(Track track) => SearchTrack(
    track.title,
    track.artist == 'Artista desconhecido' ? '' : track.artist,
    track.album == 'Álbum desconhecido' ? '' : track.album,
    track.durationMs > 0 ? track.durationMs : null,
  );
  factory SearchTrack.fromJson(Map<String, dynamic> data) => SearchTrack(
    data['title'] as String,
    data['artist'] as String,
    data['album'] as String? ?? '',
    data['duration_ms'] as int?,
  );
  final String title;
  final String artist;
  final String album;
  final int? durationMs;

  Map<String, dynamic> toJson() => {
    'title': title,
    'artist': artist,
    'album': album,
    'duration_ms': durationMs,
  };
}

class TrackMatch {
  const TrackMatch(this.id, this.key, this.track);
  TrackMatch.fromJson(Map<String, dynamic> data)
    : id = data['id'] as String,
      key = data['track_key'] as String,
      track = SearchTrack.fromJson(_object(data['track']));
  final String id;
  final String key;
  final SearchTrack track;
}

class TrackResolution {
  const TrackResolution(
    this.status,
    this.metadata, {
    this.match,
    this.candidates = const [],
  });
  TrackResolution.fromJson(Map<String, dynamic> data)
    : status = data['status'] as String,
      match = data['match'] == null
          ? null
          : TrackMatch.fromJson(_object(data['match'])),
      metadata = TrackMatch.fromJson(_object(data['metadata_match'])),
      candidates = (data['candidates'] as List)
          .map((value) => TrackMatch.fromJson(_object(value)))
          .toList(growable: false);
  final String status;
  final TrackMatch? match;
  final TrackMatch metadata;
  final List<TrackMatch> candidates;
}

class TrackText {
  TrackText.fromJson(Map<String, dynamic> data)
    : status = data['status'] as String,
      text = data['text'] as String?,
      syncedLrc = data['synced_lrc'] as String?,
      language = data['language'] as String?,
      kind = data['kind'] as String?,
      fetchedAt = DateTime.tryParse(data['fetched_at'] as String? ?? ''),
      source = data['source'] == null ? null : _object(data['source']) {
    if (data['schema_version'] != 1) throw const FormatException();
  }
  final String status;
  final String? text;
  final String? syncedLrc;
  final String? language;
  final String? kind;
  final DateTime? fetchedAt;
  final Map<String, dynamic>? source;
  static final _timestamp = RegExp(r'\[(\d+):(\d{2})(?:[.:](\d{1,3}))?\]');
  static final _offset = RegExp(r'\[offset:([+-]?\d+)\]', caseSensitive: false);
  late final List<(int, String)> _timedLines = _parseTimedLines();

  List<(int, String)> _parseTimedLines() {
    final lrc = syncedLrc;
    if (lrc == null) return [];
    final offset = int.tryParse(_offset.firstMatch(lrc)?[1] ?? '') ?? 0;
    final lines = <(int, String)>[];
    for (final row in const LineSplitter().convert(lrc)) {
      final line = row.replaceAll(_timestamp, '').trim();
      for (final match in _timestamp.allMatches(row)) {
        final fraction = (match[3] ?? '').padRight(3, '0');
        final minutes = int.tryParse(match[1]!);
        if (minutes == null || minutes > 1440) continue;
        final time =
            minutes * 60000 +
            int.parse(match[2]!) * 1000 +
            int.parse(fraction) -
            offset;
        lines.add((time, line));
      }
    }
    return lines..sort((a, b) => a.$1.compareTo(b.$1));
  }

  String? currentLine(int milliseconds) {
    var first = 0;
    var last = _timedLines.length;
    while (first < last) {
      final middle = (first + last) ~/ 2;
      if (_timedLines[middle].$1 <= milliseconds) {
        first = middle + 1;
      } else {
        last = middle;
      }
    }
    return first == 0 ? null : _timedLines[first - 1].$2;
  }

  String? get sourceName => source?['name'] is String ? source!['name'] : null;
  String? get sourceTitle =>
      source?['title'] is String ? source!['title'] : null;
  Uri? get sourceUrl {
    final value = source?['url'];
    final uri = value is String ? Uri.tryParse(value) : null;
    return uri?.scheme == 'https' && uri!.host.isNotEmpty ? uri : null;
  }

  bool get offlineAllowed =>
      status == 'found' &&
      source?['offline_allowed'] == true &&
      (text?.trim().isNotEmpty == true || syncedLrc?.trim().isNotEmpty == true);

  late final String readableText =
      text ?? _timedLines.map((entry) => entry.$2).join('\n');

  Map<String, dynamic> toJson() => {
    'schema_version': 1,
    'status': status,
    'text': text,
    'synced_lrc': syncedLrc,
    'language': language,
    'kind': kind,
    'source': source,
    'fetched_at': fetchedAt?.toIso8601String(),
  };
}

Map<String, dynamic> _object(Object? value) {
  if (value is Map<String, dynamic>) return value;
  throw const FormatException();
}

class ContentFailure implements Exception {
  const ContentFailure(this.message);
  final String message;
}

abstract interface class TextLookup {
  Future<TrackResolution> resolve(SearchTrack track, {TextKind? kind});
  Future<TrackText> fetch(TrackMatch match, TextKind kind);
}

class ContentApi implements TextLookup {
  ContentApi(this.baseUrl, {this.timeout = const Duration(seconds: 16)});
  final String baseUrl;
  final Duration timeout;

  @override
  Future<TrackResolution> resolve(SearchTrack track, {TextKind? kind}) async =>
      TrackResolution.fromJson(
        await _request(['resolve'], data: track.toJson()),
      );

  @override
  Future<TrackText> fetch(TrackMatch match, TextKind kind) async =>
      TrackText.fromJson(await _request([match.id, kind.name]));

  Future<Map<String, dynamic>> _request(
    List<String> parts, {
    Map<String, dynamic>? data,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final base = Uri.parse(baseUrl);
      final uri = base.replace(
        pathSegments: [
          ...base.pathSegments.where((segment) => segment.isNotEmpty),
          'api',
          'v1',
          'tracks',
          ...parts,
          '',
        ],
      );
      final request = await client
          .openUrl(data == null ? 'GET' : 'POST', uri)
          .timeout(timeout);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (data != null) {
        final body = utf8.encode(jsonEncode(data));
        request.headers.contentType = ContentType.json;
        request.contentLength = body.length;
        request.add(body);
      }
      final response = await request.close().timeout(timeout);
      if (response.statusCode == 429) {
        throw const ContentFailure(
          'Limite de buscas atingido. Tente em instantes.',
        );
      }
      if (response.statusCode == 410) {
        throw const ContentFailure('A busca expirou. Pesquise novamente.');
      }
      if (response.statusCode == 400) {
        throw const ContentFailure(
          'Confira o título, o artista e a duração da busca.',
        );
      }
      if (response.statusCode != 200 && response.statusCode != 503) {
        throw const ContentFailure('O servidor não conseguiu atender à busca.');
      }
      var size = 0;
      final bytes = await response
          .map((chunk) {
            size += chunk.length;
            if (size > 1024 * 1024) throw const FormatException();
            return chunk;
          })
          .expand((chunk) => chunk)
          .toList()
          .timeout(timeout);
      final result = _object(jsonDecode(utf8.decode(bytes)));
      if (result['schema_version'] != 1) throw const FormatException();
      if (response.statusCode == 503) {
        throw ContentFailure(
          result['status'] == 'provider_rate_limited'
              ? 'A fonte atingiu o limite de consultas. Tente em instantes.'
              : 'A fonte está indisponível. Tente novamente mais tarde.',
        );
      }
      return result;
    } on SocketException {
      throw const ContentFailure('Sem conexão com o servidor de textos.');
    } on TimeoutException {
      throw const ContentFailure('A busca demorou demais. Tente novamente.');
    } finally {
      client.close(force: true);
    }
  }
}
