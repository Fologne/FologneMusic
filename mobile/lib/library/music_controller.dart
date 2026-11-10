import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../content/text_store.dart';
import '../content/content_api.dart';
import '../content/direct_content_api.dart';
import '../core/app_info.dart';
import '../l10n/localization.dart';
import 'media_library.dart';
import 'models.dart';
import 'music_store.dart';
export 'models.dart';

enum TrackSort { title, artist, album, newest }

class MusicController extends ChangeNotifier {
  MusicController({
    required this.media,
    required this.store,
    required this.handler,
    this.downloads,
    this._language = AppLanguage.system,
    this.persistLanguage,
  });
  final MediaLibrary media;
  final MusicStore store;
  final AudioHandler handler;
  final TextStore? downloads;
  final Future<void> Function(AppLanguage)? persistLanguage;
  AppLanguage _language;
  AppLanguage get language => _language;

  Future<void> setLanguage(AppLanguage value) async {
    if (_language == value) return;
    await persistLanguage?.call(value);
    _language = value;
    _notify();
  }

  String apiBaseUrl = defaultApiBaseUrl;
  bool useDjango = defaultApiBaseUrl.isNotEmpty;
  final _directLookup = DirectContentApi();
  TextLookup get textLookup =>
      useDjango ? ContentApi(apiBaseUrl) : _directLookup;
  double readingSize = 18;
  bool midnightTheme = false;
  bool coverBackground = true;
  DateTime? sleepUntil;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _timer;
  Future<void> _writes = Future.value();
  Future<void>? _activeRefresh;
  bool _disposed = false;
  bool initialized = false;
  bool loading = false;
  bool permitted = false;
  String? error;
  List<Track> allTracks = [];
  List<MusicPlaylist> playlists = [];
  final Set<String> favorites = {};
  List<ListenEntry> history = [];
  TrackSort sort = TrackSort.title;
  Map<String, dynamic> _saved = {};
  bool _queueRestored = false;
  String? _heardId;
  double _lastPosition = 0;
  double _heardSeconds = 0;
  bool _counted = false;
  int _ticks = 0;
  (List<Track>, TrackSort, String)? _filterKey;
  List<Track> _filterResult = const [];

  List<Track> get tracks =>
      allTracks.where((track) => track.available).toList();
  Track? byId(String? id) {
    for (final track in allTracks) {
      if (track.id == id) return track;
    }
    return null;
  }

  Track? get current => byId(handler.mediaItem.value?.id);
  List<Track> get queue => handler.queue.value
      .map((item) => byId(item.id))
      .whereType<Track>()
      .toList();
  List<Track> get playbackQueue {
    final tracks = queue;
    final order = handler.customState.valueOrNull;
    if (order is! List<String> || order.length != tracks.length) return tracks;
    final byId = {for (final track in tracks) track.id: track};
    if (order.any((id) => !byId.containsKey(id))) return tracks;
    return order.map((id) => byId[id]!).toList();
  }

  bool get playing => handler.playbackState.value.playing;
  bool get buffering => {
    AudioProcessingState.loading,
    AudioProcessingState.buffering,
  }.contains(handler.playbackState.value.processingState);
  bool get shuffle =>
      handler.playbackState.value.shuffleMode != AudioServiceShuffleMode.none;
  int get repeat => switch (handler.playbackState.value.repeatMode) {
    AudioServiceRepeatMode.none => 0,
    AudioServiceRepeatMode.one => 2,
    _ => 1,
  };
  double get duration =>
      (handler.mediaItem.value?.duration?.inMilliseconds ??
          current?.durationMs ??
          0) /
      1000;
  double get position =>
      (handler.playbackState.value.position.inMilliseconds / 1000).clamp(
        0,
        math.max(0, duration),
      );
  int get listenedCount => history.length;

  Future<void> initialize() async {
    loading = true;
    _notify();
    try {
      allTracks = await store.readTracks();
      _saved = await store.readState();
      apiBaseUrl = _saved['apiBaseUrl'] as String? ?? defaultApiBaseUrl;
      useDjango =
          (_saved['useDjango'] as bool? ?? defaultApiBaseUrl.isNotEmpty) &&
          apiBaseUrl.isNotEmpty;
      readingSize = (_saved['readingSize'] as num? ?? 18).toDouble().clamp(
        16,
        28,
      );
      midnightTheme = _saved['midnightTheme'] == true;
      coverBackground = _saved['coverBackground'] != false;
      favorites.addAll(List<String>.from(_saved['favorites'] as List? ?? []));
      playlists = (_saved['playlists'] as List? ?? [])
          .map(
            (p) => MusicPlaylist.fromJson(Map<String, dynamic>.from(p as Map)),
          )
          .toList();
      history = (_saved['history'] as List? ?? [])
          .map((p) => ListenEntry.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList();
      sort =
          TrackSort.values.where((s) => s.name == _saved['sort']).firstOrNull ??
          TrackSort.title;
    } catch (_) {
      error = 'Não foi possível abrir os dados locais. Tente reiniciar o aplicativo.';
    }
    _subscriptions.add(handler.playbackState.listen((_) => _notify()));
    _subscriptions.add(
      handler.mediaItem.listen((_) {
        _notify();
        if (initialized) unawaited(save());
      }),
    );
    _subscriptions.add(handler.queue.listen((_) => _notify()));
    _subscriptions.add(handler.customState.listen((_) => _notify()));
    _subscriptions.add(
      handler.customEvent.listen((event) {
        if (event is Map && event['error'] is String) {
          error = event['error'] as String;
          _notify();
        }
        if (event is Map && event.containsKey('sleepUntil')) {
          final value = event['sleepUntil'];
          sleepUntil = value is int
              ? DateTime.fromMillisecondsSinceEpoch(value)
              : null;
          _notify();
        }
      }),
    );
    initialized = true;
    loading = false;
    await refresh();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _recordListening();
      if (++_ticks % 5 == 0 && _queueRestored) unawaited(save());
      if (playing) _notify();
    });
  }

  Future<void> refresh({bool request = false}) {
    final active = _activeRefresh;
    if (active != null) return active;
    if (loading || _disposed) return Future.value();
    final refresh = _scanLibrary(request: request).whenComplete(() {
      _activeRefresh = null;
    });
    _activeRefresh = refresh;
    return refresh;
  }

  Future<void> _scanLibrary({required bool request}) async {
    loading = true;
    error = null;
    _notify();
    try {
      permitted = await media.permission(request: request);
      if (!permitted) {
        await handler.stop();
        return;
      }
      final found = await media.scan();
      final ids = found.map((t) => t.id).toSet();
      final missing = allTracks
          .where((t) => !ids.contains(t.id))
          .map((t) => t.missing());
      allTracks = [
        ...{for (final t in found) t.id: t}.values,
        ...missing,
      ];
      await store.writeTracks(allTracks);
      if (!_queueRestored) {
        final ids = List<String>.from(_saved['queue'] as List? ?? []);
        final restored = ids
            .map(byId)
            .whereType<Track>()
            .where((t) => t.available)
            .toList();
        final selected = byId(_saved['current'] as String?);
        final index = restored.indexWhere((t) => t.id == selected?.id);
        if (restored.isNotEmpty) {
          await handler.customAction('load', {
            'tracks': restored.map((t) => t.toJson()).toList(),
            'index': math.max(0, index),
            'positionMs': index >= 0
                ? (_saved['positionMs'] as num? ?? 0).toInt().clamp(
                    0,
                    restored[index].durationMs,
                  )
                : 0,
            'play': false,
            'shuffle': _saved['shuffle'] == true,
            'playbackOrder': _saved['playbackOrder'],
          });
          await handler.setRepeatMode(
            _repeatMode((_saved['repeat'] as num? ?? 0).toInt()),
          );
        }
        _queueRestored = true;
      } else if (queue.any((t) => !t.available)) {
        final valid = queue.where((t) => t.available).toList();
        final oldId = current?.id;
        final index = valid.indexWhere((t) => t.id == oldId);
        await handler.customAction('load', {
          'tracks': valid.map((t) => t.toJson()).toList(),
          'index': math.max(0, index),
          'positionMs': index >= 0 ? (position * 1000).toInt() : 0,
          'play': false,
          'shuffle': shuffle,
          'playbackOrder': handler.customState.valueOrNull,
        });
        error = 'A fila foi atualizada: há arquivos que não estão mais disponíveis.';
      }
      await save();
    } catch (_) {
      error = 'Não foi possível atualizar a biblioteca. Verifique as permissões e tente novamente.';
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<bool> deleteFromDevice(Track track) async {
    if (byId(track.id)?.available != true || !await media.delete(track.id)) {
      return false;
    }
    await refreshAfterMediaChange();
    return true;
  }

  Future<void> refreshAfterMediaChange() async {
    await _activeRefresh;
    await refresh();
  }

  List<Track> filtered(String query, {List<Track>? from}) {
    final term = query.toLowerCase();
    final key = (allTracks, sort, term);
    if (from == null && _filterKey == key) return _filterResult;
    final result = (from ?? tracks)
        .where(
          (t) =>
              '${t.title} ${t.artist} ${t.album}'.toLowerCase().contains(term),
        )
        .toList();
    result.sort(
      (a, b) => switch (sort) {
        TrackSort.title => a.title.toLowerCase().compareTo(
          b.title.toLowerCase(),
        ),
        TrackSort.artist => a.artist.toLowerCase().compareTo(
          b.artist.toLowerCase(),
        ),
        TrackSort.album => a.album.toLowerCase().compareTo(
          b.album.toLowerCase(),
        ),
        TrackSort.newest => b.addedAt.compareTo(a.addedAt),
      },
    );
    if (from == null) {
      _filterKey = key;
      return _filterResult = List.unmodifiable(result);
    }
    return result;
  }

  Future<void> setSort(TrackSort value) async {
    sort = value;
    _notify();
    await save();
  }

  Future<void> select(
    Track track, {
    List<Track>? from,
    bool random = false,
  }) async {
    if (!permitted || !track.available) {
      error = 'Esta música está indisponível. Atualize a biblioteca ou conceda acesso ao áudio.';
      _notify();
      return;
    }
    error = null;
    final candidates = (from ?? queue).where((t) => t.available).toList();
    if (!candidates.any((t) => t.id == track.id)) candidates.add(track);
    final unique = {for (final item in candidates) item.id: item}.values
        .toList();
    _queueRestored = true;
    _counted = false;
    _heardSeconds = 0;
    await handler.customAction('load', {
      'tracks': unique.map((t) => t.toJson()).toList(),
      'index': unique.indexWhere((t) => t.id == track.id),
      'play': true,
      'shuffle': random,
    });
    await save();
    _notify();
  }

  Future<void> togglePlaying() async {
    if (!permitted || current == null || !current!.available) return;
    if (playing) {
      await handler.pause();
    } else {
      await handler.play();
    }
    await save();
  }

  Future<void> seek(double value) async {
    await handler.seek(Duration(milliseconds: (value * 1000).toInt()));
    await save();
  }

  Future<void> skip(int offset) async {
    if (offset > 0) {
      await handler.skipToNext();
    } else {
      await handler.skipToPrevious();
    }
    await save();
  }

  Future<void> toggleShuffle() async {
    await handler.setShuffleMode(
      shuffle ? AudioServiceShuffleMode.none : AudioServiceShuffleMode.all,
    );
    await save();
  }

  AudioServiceRepeatMode _repeatMode(int value) => switch (value) {
    1 => AudioServiceRepeatMode.all,
    2 => AudioServiceRepeatMode.one,
    _ => AudioServiceRepeatMode.none,
  };
  Future<void> cycleRepeat() async {
    await handler.setRepeatMode(_repeatMode((repeat + 1) % 3));
    await save();
  }

  Future<void> reorder(int from, int to) async {
    await handler.customAction('reorder', {'from': from, 'to': to});
    await save();
  }

  Future<void> selectInQueue(Track track) async {
    await handler.skipToQueueItem(
      handler.queue.value.indexWhere((item) => item.id == track.id),
    );
    await handler.play();
    await save();
  }

  Future<void> toggleFavorite(Track track) async {
    if (!favorites.add(track.id)) favorites.remove(track.id);
    _notify();
    await save();
  }

  Future<MusicPlaylist> createPlaylist(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) throw ArgumentError('Informe um nome.');
    final playlist = MusicPlaylist(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: clean,
    );
    playlists.add(playlist);
    _notify();
    await save();
    return playlist;
  }

  MusicPlaylist? playlistById(String id) =>
      playlists.where((p) => p.id == id).firstOrNull;
  List<Track> playlistTracks(MusicPlaylist playlist) =>
      playlist.trackIds.map(byId).whereType<Track>().toList();
  Future<void> renamePlaylist(MusicPlaylist playlist, String name) async {
    if (name.trim().isEmpty) return;
    playlist.name = name.trim();
    _notify();
    await save();
  }

  Future<void> deletePlaylist(MusicPlaylist playlist) async {
    playlists.remove(playlist);
    _notify();
    await save();
  }

  Future<void> addToPlaylist(
    MusicPlaylist playlist,
    Iterable<Track> tracks,
  ) async {
    playlist.trackIds = {
      ...playlist.trackIds,
      ...tracks.map((t) => t.id),
    }.toList();
    _notify();
    await save();
  }

  Future<void> removeFromPlaylist(MusicPlaylist playlist, Track track) async {
    playlist.trackIds.remove(track.id);
    if (playlist.coverId == track.id) playlist.coverId = null;
    _notify();
    await save();
  }

  Future<void> reorderPlaylist(MusicPlaylist playlist, int from, int to) async {
    playlist.trackIds.insert(to, playlist.trackIds.removeAt(from));
    _notify();
    await save();
  }

  Future<void> setCover(MusicPlaylist playlist, Track? track) async {
    playlist.coverId = track?.id;
    _notify();
    await save();
  }

  Future<void> clearHistory() async {
    history.clear();
    _notify();
    await save();
  }

  List<Track> get recentlyAdded {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = now - const Duration(days: 90).inMilliseconds;
    return allTracks.where((track) {
      final createdAt = track.createdAt;
      return track.available &&
          createdAt != null &&
          createdAt >= cutoff &&
          createdAt <= now;
    }).toList()..sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
  }

  List<Track> get recent {
    final ids = history.reversed.map((h) => h.trackId).toSet();
    return ids.map(byId).whereType<Track>().where((t) => t.available).toList();
  }

  List<Track> get mostPlayed {
    final counts = <String, int>{};
    for (final h in history) {
      counts[h.trackId] = (counts[h.trackId] ?? 0) + 1;
    }
    final ids = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return ids.map(byId).whereType<Track>().where((t) => t.available).toList();
  }

  void _recordListening() {
    final track = current;
    if (track == null) return;
    final now = position;
    if (_heardId != track.id || now < _lastPosition - 2) {
      _heardId = track.id;
      _heardSeconds = 0;
      _counted = false;
      _lastPosition = now;
    }
    final elapsed = now - _lastPosition;
    if (playing && !buffering && elapsed > 0 && elapsed < 2.5) {
      _heardSeconds += elapsed;
    }
    _lastPosition = now;
    final threshold = duration > 0 ? math.min(30.0, duration / 2) : 30.0;
    if (!_counted && _heardSeconds >= threshold) {
      history.add(ListenEntry(track.id, DateTime.now().millisecondsSinceEpoch));
      if (history.length > 1000) history.removeRange(0, history.length - 1000);
      _counted = true;
      unawaited(save());
    }
  }

  Future<void> save() {
    if (!initialized || _disposed) return Future.value();
    final snapshot = jsonDecode(
      jsonEncode({
        'schemaVersion': 1,
        'favorites': favorites.toList(),
        'playlists': playlists.map((p) => p.toJson()).toList(),
        'history': history.map((h) => h.toJson()).toList(),
        'sort': sort.name,
        'apiBaseUrl': apiBaseUrl,
        'useDjango': useDjango,
        'readingSize': readingSize,
        'midnightTheme': midnightTheme,
        'coverBackground': coverBackground,
        'queue': _queueRestored
            ? queue.map((t) => t.id).toList()
            : _saved['queue'] ?? [],
        'current': _queueRestored ? current?.id : _saved['current'],
        'positionMs': _queueRestored
            ? (position * 1000).toInt()
            : _saved['positionMs'] ?? 0,
        'shuffle': _queueRestored ? shuffle : _saved['shuffle'] ?? false,
        'playbackOrder': _queueRestored
            ? handler.customState.valueOrNull
            : _saved['playbackOrder'],
        'repeat': _queueRestored ? repeat : _saved['repeat'] ?? 0,
      }),
    ) as Map<String, dynamic>;
    _writes = _writes.then((_) => store.writeState(snapshot)).catchError((
      Object e,
    ) {
      error = 'Não foi possível salvar os dados locais. Verifique o espaço disponível.';
      _notify();
    });
    return _writes;
  }

  void clearError() {
    error = null;
    _notify();
  }

  Future<void> setAppearance({
    double? fontSize,
    bool? midnight,
    bool? showCover,
  }) async {
    readingSize = fontSize ?? readingSize;
    midnightTheme = midnight ?? midnightTheme;
    coverBackground = showCover ?? coverBackground;
    _notify();
    await save();
  }

  Future<void> setApiBaseUrl(String url) async {
    apiBaseUrl = url;
    useDjango = true;
    _notify();
    await save();
  }

  Future<void> setDjangoMode(bool enabled) async {
    useDjango = enabled && apiBaseUrl.isNotEmpty;
    _notify();
    await save();
  }

  Future<void> setSleepTimer(int minutes) async {
    sleepUntil = minutes > 0
        ? DateTime.now().add(Duration(minutes: minutes))
        : null;
    _notify();
    await handler.customAction('sleepTimer', {'minutes': minutes});
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}

class MusicScope extends InheritedNotifier<MusicController> {
  const MusicScope({
    super.key,
    required MusicController controller,
    required super.child,
  }) : super(notifier: controller);
  static MusicController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MusicScope>()!.notifier!;
}
