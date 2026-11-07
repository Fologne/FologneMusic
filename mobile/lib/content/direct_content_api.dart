import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import '../core/app_info.dart';
import 'content_api.dart';

typedef ProviderRequest = Future<Object?> Function(Uri uri);

class DirectContentApi implements TextLookup {
  DirectContentApi({ProviderRequest? request, AssetBundle? assets})
    : _request = request ?? _providers.get,
      _assets = assets ?? rootBundle;

  static final _providers = _ProviderClient();
  final ProviderRequest _request;
  final AssetBundle _assets;
  late final Future<Map<String, dynamic>> _catalog = _assets
      .loadString('assets/track_context.json')
      .then((value) => _map(jsonDecode(value)));

  static const _labels = {
    'official',
    'official video',
    'official music video',
    'official audio',
    'music video',
    'lyric video',
    'official lyric video',
    'lyrics',
    'lyric',
    'letra',
    'tradução',
    'traducao',
    'legendado',
    'legenda',
    'sub español',
    'sub esp',
    'sub english',
    'english subtitles',
    'audio',
    'áudio',
    'hd',
    '4k',
    'videoclipe oficial',
    'vídeo oficial',
    'letra e tradução',
  };
  static final _videoTag = RegExp(r'\s*(?:\(([^()]*)\)|\[([^\[\]]*)\])\s*$');
  static final _channel = RegExp(
    r'(?:\s*[-–—]\s*topic|vevo)$',
    caseSensitive: false,
  );
  static final _separator = RegExp(r'\s+[-–—]\s+');
  static final _edges = RegExp(r'^[ *~〜～＊♪♫]+|[ *~〜～＊♪♫]+$');
  static final _symbols = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

  static String _fold(String value) => String.fromCharCodes(
    value.runes.map(
      (c) => c >= 0xff01 && c <= 0xff5e ? c - 0xfee0 : (c == 0x3000 ? 32 : c),
    ),
  ).trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  static String _artist(String value) {
    final clean = value.trim().replaceFirst(_channel, '').trim();
    return clean.isEmpty ? value.trim() : clean;
  }

  static String _artistKey(String value) =>
      _fold(_artist(value)).replaceAll(_symbols, '');
  static String _title(String value) {
    var title = value.trim();
    while (true) {
      final match = _videoTag.firstMatch(title);
      if (match == null) break;
      final annotation = _fold(match[1] ?? match[2] ?? '');
      if (!annotation.split(RegExp(r'\s*[/+|,&]\s*')).every(_labels.contains)) {
        break;
      }
      title = title.substring(0, match.start).trimRight();
    }
    return title.isEmpty ? value.trim() : title;
  }

  static String _titleKey(String title, String artist) {
    final key = _fold(_title(title)).replaceAll(_edges, '');
    if (_artistKey(artist) == 'orangerange' &&
        {'asterisk', 'アスタリスク', 'asutarisuku'}.contains(key)) {
      return 'asterisk';
    }
    return key;
  }

  static bool _same(SearchTrack a, SearchTrack b) =>
      _artistKey(a.artist) == _artistKey(b.artist) &&
      _titleKey(a.title, a.artist) == _titleKey(b.title, b.artist);

  static List<SearchTrack> _queries(SearchTrack track) {
    final title = _title(track.title);
    final artist = _artist(track.artist);
    final album =
        {
          '<unknown>',
          'álbum desconhecido',
          _fold(track.title),
          _fold(track.artist),
        }.contains(_fold(track.album))
        ? ''
        : track.album;
    final base = SearchTrack(title, artist, album, track.durationMs);
    final sides = title.split(_separator);
    if (sides.length != 2 || sides.any((side) => side.trim().isEmpty)) {
      return [base];
    }
    final (left, right) = (_title(sides.first), _title(sides.last));
    SearchTrack pair(String song, String performer, [String record = '']) =>
        SearchTrack(song, _artist(performer), record, track.durationMs);
    if (_artistKey(left) == _artistKey(artist)) {
      return [pair(right, left, album)];
    }
    if (_artistKey(right) == _artistKey(artist)) {
      return [pair(left, right, album)];
    }
    final number = RegExp(r'^\d+$');
    if (number.hasMatch(left) != number.hasMatch(right)) {
      return [number.hasMatch(left) ? pair(left, right) : pair(right, left)];
    }
    if (_fold(left) == _fold(right)) return [base];
    return [base, pair(right, left), pair(left, right)];
  }

  static TrackMatch _reference(SearchTrack track, [int? id]) {
    final key = id == null
        ? sha256.convert(utf8.encode(jsonEncode(track.toJson()))).toString()
        : 'lrclib:$id';
    return TrackMatch(id?.toString() ?? '', key, track);
  }

  static SearchTrack? _record(Map<String, dynamic> row) {
    final title = row['trackName'],
        artist = row['artistName'],
        album = row['albumName'];
    final duration = row['duration'];
    if (title is! String || artist is! String) return null;
    return SearchTrack(
      title,
      artist,
      album is String ? album : '',
      duration is num && duration > 0 && duration <= 86400
          ? (duration * 1000).round()
          : null,
    );
  }

  Future<List<TrackMatch>> _search(SearchTrack track) async {
    final title = track.title.replaceAll(_edges, '');
    Future<List<TrackMatch>> query(String title) async {
      final data = await _request(
        Uri.https('lrclib.net', '/api/search', {
          'track_name': title.isEmpty ? track.title : title,
          if (track.artist.isNotEmpty) 'artist_name': track.artist,
        }),
      );
      if (data is! List) throw const FormatException();
      final matches = <int, TrackMatch>{};
      for (final value in data.take(100).whereType<Map<String, dynamic>>()) {
        final id = value['id'];
        final result = _record(value);
        if (id is int && id > 0 && result != null && _same(result, track)) {
          matches[id] = _reference(result, id);
        }
      }
      return matches.values.toList();
    }

    final found = await query(title);
    if (found.isEmpty &&
        _artistKey(track.artist) == 'orangerange' &&
        _titleKey(title, track.artist) == 'asterisk' &&
        title != 'アスタリスク') {
      return query('アスタリスク');
    }
    return found;
  }

  @override
  Future<TrackResolution> resolve(SearchTrack track, {TextKind? kind}) async {
    final queries = _queries(track);
    final fallback = _reference(queries.first);
    if (kind == TextKind.meaning && queries.length == 1) {
      return TrackResolution('not_found', fallback);
    }
    final identities = <(SearchTrack, List<TrackMatch>)>[];
    for (final query in queries) {
      if (query.artist.isEmpty) continue;
      final found = await _search(query);
      if (found.isEmpty) continue;
      identities.add((query, found));
      if (identical(query, queries.first)) break;
    }
    if (identities.isEmpty) return TrackResolution('not_found', fallback);
    if (identities.length > 1) {
      return TrackResolution(
        'identity_ambiguous',
        fallback,
        candidates: [for (final identity in identities) ...identity.$2.take(5)],
      );
    }
    final (preferred, candidates) = identities.single;
    final metadata = _reference(preferred);
    int distance(TrackMatch match) {
      final a = preferred.durationMs, b = match.track.durationMs;
      return a == null || b == null ? 86400001 : (a - b).abs();
    }

    bool albumMatches(TrackMatch match) =>
        preferred.album.isNotEmpty &&
        _fold(preferred.album) == _fold(match.track.album);
    int score(TrackMatch match) =>
        (albumMatches(match) ? 2 : 0) + (distance(match) <= 4000 ? 1 : 0);
    if (candidates.any((item) => distance(item) <= 4000)) {
      candidates.removeWhere((item) => distance(item) > 4000);
    }
    candidates.sort((a, b) {
      final rank = score(b).compareTo(score(a));
      return rank != 0 ? rank : distance(a).compareTo(distance(b));
    });
    final top = candidates.first;
    if ((candidates.length == 1 || score(top) > score(candidates[1])) &&
        (preferred.album.isEmpty || albumMatches(top)) &&
        (preferred.durationMs == null || distance(top) <= 4000)) {
      return TrackResolution('matched', metadata, match: top);
    }
    return TrackResolution(
      'ambiguous',
      metadata,
      candidates: candidates.take(10).toList(),
    );
  }

  @override
  Future<TrackText> fetch(TrackMatch match, TextKind kind) async {
    if (kind == TextKind.meaning) return _meaning(match.track);
    final id = int.tryParse(match.id);
    if (id == null || id <= 0) return _result('not_resolved');
    final uri = Uri.https('lrclib.net', '/api/get/$id');
    final data = await _request(uri);
    if (data == null) return _result('not_found');
    final row = _map(data);
    final record = _record(row);
    if (row['id'] != id || record == null || !_same(record, match.track)) {
      throw const FormatException();
    }
    final source = {
      'name': 'LRCLIB',
      'url': uri.toString(),
      'offline_allowed': false,
    };
    if (row['instrumental'] == true) {
      return _result('instrumental', {'source': source});
    }
    final plain = row['plainLyrics'], synced = row['syncedLyrics'];
    final text = plain is String && plain.trim().isNotEmpty ? plain : null;
    final lrc = synced is String && synced.trim().isNotEmpty ? synced : null;
    return _result(text == null && lrc == null ? 'not_found' : 'found', {
      'text': text,
      'synced_lrc': lrc,
      'source': source,
    });
  }

  Future<TrackText> _meaning(SearchTrack track) async {
    final catalog = await _catalog;
    final artist = catalog[_artistKey(track.artist)];
    if (artist is Map<String, dynamic>) {
      final entry = artist[_titleKey(track.title, track.artist)];
      if (entry is Map<String, dynamic>) return _result('found', entry);
    }
    if (track.title.contains('|') ||
        track.artist.contains('|') ||
        _artistKey(track.artist).isEmpty) {
      return _result('not_found');
    }
    for (final language in ['pt', 'en']) {
      final suffix = language == 'pt' ? 'canção' : 'song';
      final qualified = language == 'pt'
          ? 'canção de ${track.artist}'
          : '${track.artist} song';
      final titles = [
        track.title,
        '${track.title} ($suffix)',
        '${track.title} ($qualified)',
      ];
      final host = '$language.wikipedia.org';
      final data = _map(
        await _request(
          Uri.https(host, '/w/api.php', {
            'action': 'query',
            'format': 'json',
            'formatversion': '2',
            'redirects': '1',
            'titles': titles.join('|'),
            'prop': 'extracts|pageprops',
            'ppprop': 'disambiguation',
            'exintro': '1',
            'explaintext': '1',
          }),
        ),
      );
      final pages = _map(data['query'])['pages'];
      if (pages is! List) throw const FormatException();
      final matches = <int, String>{};
      for (final row in pages.whereType<Map<String, dynamic>>()) {
        final id = row['pageid'],
            title = row['title'],
            extract = row['extract'];
        final props = row['pageprops'];
        if (props is Map && props.containsKey('disambiguation')) continue;
        if (id is! int ||
            id <= 0 ||
            title is! String ||
            extract is! String ||
            !titles.map(_fold).contains(_fold(title))) {
          continue;
        }
        final intro = _fold(
          extract.length > 600 ? extract.substring(0, 600) : extract,
        );
        final performer = RegExp(
          '(?:^|[^\\p{L}\\p{N}])${RegExp.escape(_fold(track.artist))}(?:[^\\p{L}\\p{N}]|\$)',
          unicode: true,
        );
        if (performer.hasMatch(intro) &&
            RegExp(r'\b(song|single|canção|música)\b').hasMatch(intro)) {
          matches[id] = title;
        }
      }
      if (matches.length == 1) {
        return _result('link_only', {
          'language': language,
          'kind': 'encyclopedic_context',
          'source': {
            'name': 'Wikipédia',
            'title': matches.values.single,
            'url': Uri.https(host, '/', {
              'curid': '${matches.keys.single}',
            }).toString(),
            'offline_allowed': false,
          },
        });
      }
    }
    return _result('not_found');
  }
}

Map<String, dynamic> _map(Object? data) {
  if (data is Map<String, dynamic>) return data;
  throw const FormatException();
}

TrackText _result(String status, [Map<String, dynamic> fields = const {}]) =>
    TrackText.fromJson({
      'schema_version': 1,
      'status': status,
      'fetched_at': DateTime.now().toUtc().toIso8601String(),
      ...fields,
    });

class _ProviderClient {
  Future<void> _last = Future.value();
  final _blockedUntil = <String, DateTime>{};
  DateTime? _lastRequest;

  Future<Object?> get(Uri uri) {
    final pending = _last.then((_) => _get(uri));
    _last = pending.then((_) {}, onError: (Object _, StackTrace _) {});
    return pending;
  }

  Future<Object?> _get(Uri uri) async {
    final now = DateTime.now();
    if (_blockedUntil[uri.host]?.isAfter(now) ?? false) {
      throw const ContentFailure(
        'A fonte pediu uma pausa entre buscas. Tente novamente em instantes.',
      );
    }
    final previous = _lastRequest;
    if (previous != null) {
      final remaining = previous
          .add(const Duration(milliseconds: 250))
          .difference(now);
      if (!remaining.isNegative) await Future<void>.delayed(remaining);
    }
    _lastRequest = DateTime.now();
    const timeout = Duration(seconds: 7);
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(uri).timeout(timeout);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.userAgentHeader, providerUserAgent);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(timeout);
      if (response.statusCode == 404) return null;
      if (response.statusCode == 429 || response.statusCode == 503) {
        final retry = response.headers.value(HttpHeaders.retryAfterHeader);
        final seconds = int.tryParse(retry ?? '');
        DateTime deadline;
        if (seconds != null && seconds >= 0) {
          deadline = DateTime.now().add(
            Duration(seconds: seconds.clamp(1, 86400)),
          );
        } else {
          try {
            deadline = HttpDate.parse(retry ?? '');
          } catch (_) {
            deadline = DateTime.now().add(const Duration(seconds: 30));
          }
        }
        _blockedUntil[uri.host] = deadline.add(
          Duration(milliseconds: Random().nextInt(300)),
        );
        throw const ContentFailure(
          'A fonte está ocupada. Tente novamente em instantes.',
        );
      }
      if (response.statusCode != 200) {
        throw const ContentFailure('A fonte está indisponível no momento.');
      }
      var length = 0;
      final bytes = await response
          .expand((chunk) {
            length += chunk.length;
            if (length > 1024 * 1024) throw const FormatException();
            return chunk;
          })
          .toList()
          .timeout(timeout);
      return jsonDecode(utf8.decode(bytes));
    } on SocketException {
      throw const ContentFailure('Sem conexão com a fonte de textos.');
    } on TimeoutException {
      throw const ContentFailure('A busca demorou demais. Tente novamente.');
    } finally {
      client.close(force: true);
    }
  }
}
