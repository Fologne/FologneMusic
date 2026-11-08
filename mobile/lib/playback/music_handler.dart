import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../library/models.dart';
import '../library/media_library.dart';

class MusicHandler extends BaseAudioHandler {
  final engine = AudioPlayer(maxSkipsOnError: 5);
  final _shuffleOrder = _PlaybackShuffleOrder();
  Future<void> _pending = Future.value();
  Timer? _sleepTimer;
  int _artworkRequest = 0;

  MusicHandler() {
    engine.playbackEventStream.listen((_) => _broadcast());
    engine.playerStateStream.listen((state) {
      _broadcast();
      if (state.processingState == ProcessingState.completed) {
        unawaited(pause());
      }
    });
    engine.currentIndexStream.listen((_) => _syncItem());
    engine.sequenceStateStream.listen((state) {
      final order = state.shuffleModeEnabled
          ? state.effectiveSequence
                .map((source) => (source.tag as MediaItem).id)
                .toList()
          : null;
      if (!listEquals(order, customState.valueOrNull as List<String>?)) {
        customState.add(order);
      }
    });
    engine.durationStream.listen((duration) {
      final item = mediaItem.value;
      if (item != null && duration != null) {
        mediaItem.add(item.copyWith(duration: duration));
      }
    });
    engine.errorStream.listen((error) {
      customEvent.add({
        'error': 'Não foi possível tocar este arquivo. Ele pode ter sido removido ou estar corrompido.',
      });
    });
  }

  Future<void> configure() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  void _syncItem() {
    final index = engine.currentIndex;
    if (index != null && index < queue.value.length) {
      _publishItem(queue.value[index]);
    }
    _broadcast();
  }

  void _publishItem(MediaItem item) {
    if (mediaItem.value?.id == item.id) return;
    final request = ++_artworkRequest;
    mediaItem.add(item);
    unawaited(_loadArtwork(item.id, request));
  }

  Future<void> _loadArtwork(String id, int request) async {
    try {
      final path = await AndroidMediaLibrary.notificationArtwork(id);
      final current = mediaItem.value;
      if (path != null && request == _artworkRequest && current?.id == id) {
        mediaItem.add(current!.copyWith(artUri: Uri.file(path)));
      }
    } catch (_) {
      // Playback and controls remain available if artwork cannot be loaded.
    }
  }

  void _broadcast() {
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          engine.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
          const MediaControl(
            androidIcon: 'drawable/ic_close_playback',
            label: 'Parar reprodução',
            action: MediaAction.stop,
          ),
        ],
        systemActions: {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: [0, 1, 2],
        processingState: switch (engine.processingState) {
          ProcessingState.idle => AudioProcessingState.idle,
          ProcessingState.loading => AudioProcessingState.loading,
          ProcessingState.buffering => AudioProcessingState.buffering,
          ProcessingState.ready => AudioProcessingState.ready,
          ProcessingState.completed => AudioProcessingState.completed,
        },
        playing: engine.playing,
        updatePosition: engine.position,
        bufferedPosition: engine.bufferedPosition,
        speed: engine.speed,
        queueIndex: engine.currentIndex,
        shuffleMode: engine.shuffleModeEnabled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        repeatMode: switch (engine.loopMode) {
          LoopMode.off => AudioServiceRepeatMode.none,
          LoopMode.all => AudioServiceRepeatMode.all,
          LoopMode.one => AudioServiceRepeatMode.one,
        },
      ),
    );
  }

  Future<void> _guard(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (_) {
      customEvent.add({
        'error': 'Não foi possível reproduzir. Verifique o arquivo e a permissão de áudio.',
      });
      _broadcast();
    }
  }

  @override
  Future<void> play() => _guard(() async {
    if (queue.value.isEmpty) return;
    if (engine.processingState == ProcessingState.completed) {
      await engine.seek(
        Duration.zero,
        index: engine.effectiveIndices.firstOrNull,
      );
    }
    unawaited(
      engine.play().catchError((Object error) {
        customEvent.add({
          'error':
              'A reprodução foi interrompida. Tente selecionar outra música.',
        });
      }),
    );
  });
  @override
  Future<void> pause() => _guard(engine.pause);
  @override
  Future<void> stop() => _guard(() async {
    _sleepTimer?.cancel();
    customEvent.add({'sleepUntil': null});
    await engine.stop();
    await super.stop();
  });
  @override
  Future<void> seek(Duration position) => _guard(() => engine.seek(position));
  @override
  Future<void> skipToNext() => _skip(1);
  @override
  Future<void> skipToPrevious() => _skip(-1);

  Future<void> _skip(int offset) => _guard(() async {
    final indices = engine.effectiveIndices;
    final currentIndex = engine.currentIndex;
    if (currentIndex == null || indices.length < 2) return;

    final position = indices.indexOf(currentIndex);
    if (position < 0) return;

    // Manual skips follow the queue even when the current track repeats.
    var target = position + offset;
    if (engine.loopMode == LoopMode.all) target %= indices.length;
    if (target < 0 || target >= indices.length) return;

    await engine.seek(Duration.zero, index: indices[target]);
  });
  @override
  Future<void> skipToQueueItem(int index) => _guard(() async {
    if (index >= 0 && index < queue.value.length) {
      await engine.seek(Duration.zero, index: index);
    }
  });
  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) =>
      _guard(() async {
        if (shuffleMode != AudioServiceShuffleMode.none) await engine.shuffle();
        await engine.setShuffleModeEnabled(
          shuffleMode != AudioServiceShuffleMode.none,
        );
        _broadcast();
      });
  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) =>
      _guard(() async {
        await engine.setLoopMode(switch (repeatMode) {
          AudioServiceRepeatMode.one => LoopMode.one,
          AudioServiceRepeatMode.all ||
          AudioServiceRepeatMode.group => LoopMode.all,
          AudioServiceRepeatMode.none => LoopMode.off,
        });
        _broadcast();
      });
  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    if (name == 'sleepTimer') {
      _sleepTimer?.cancel();
      final minutes = extras?['minutes'] as int? ?? 0;
      if (minutes > 0) {
        final delay = Duration(minutes: minutes);
        customEvent.add({
          'sleepUntil': DateTime.now().add(delay).millisecondsSinceEpoch,
        });
        _sleepTimer = Timer(delay, () {
          customEvent.add({'sleepUntil': null});
          unawaited(pause());
        });
      } else {
        customEvent.add({'sleepUntil': null});
      }
      return null;
    }
    final task = _pending.then(
      (_) => _guard(() async {
        if (name == 'load') {
          final tracks = (extras!['tracks'] as List)
              .map(
                (row) => Track.fromJson(Map<String, dynamic>.from(row as Map)),
              )
              .toList();
          await engine.pause();
          queue.add(tracks.map((track) => track.toMediaItem()).toList());
          if (tracks.isEmpty) {
            await stop();
            _artworkRequest++;
            mediaItem.add(null);
            return;
          }
          final index = (extras['index'] as int).clamp(0, tracks.length - 1);
          _publishItem(queue.value[index]);
          await engine.setAudioSources(
            tracks
                .map(
                  (track) => AudioSource.uri(
                    Uri.parse(track.id),
                    tag: track.toMediaItem(),
                  ),
                )
                .toList(),
            initialIndex: index,
            initialPosition: Duration(
              milliseconds: extras['positionMs'] as int? ?? 0,
            ),
            preload: extras['play'] == true,
            shuffleOrder: _shuffleOrder,
          );
          final shuffle = extras['shuffle'] == true;
          if (shuffle) {
            final savedOrder = (extras['playbackOrder'] as List?)
                ?.whereType<String>();
            final indicesById = {
              for (final (i, track) in tracks.indexed) track.id: i,
            };
            final restoredOrder = savedOrder
                ?.map((id) => indicesById[id])
                .whereType<int>()
                .toSet();
            _shuffleOrder.next =
                restoredOrder != null && restoredOrder.length == tracks.length
                ? restoredOrder.toList()
                : null;
            await engine.shuffle();
          }
          await engine.setShuffleModeEnabled(shuffle);
          _broadcast();
          if (extras['play'] == true) await play();
        } else if (name == 'reorder') {
          final from = extras!['from'] as int;
          final to = extras['to'] as int;
          final items = List<MediaItem>.of(queue.value);
          if (from < 0 ||
              from >= items.length ||
              to < 0 ||
              to >= items.length) {
            return;
          }
          if (engine.shuffleModeEnabled) {
            final order = List<int>.of(engine.effectiveIndices);
            if (order.length != items.length) return;
            order.insert(to, order.removeAt(from));
            _shuffleOrder.next = order;
            await engine.shuffle();
            return;
          }
          items.insert(to, items.removeAt(from));
          queue.add(items);
          await engine.moveAudioSource(from, to);
          _syncItem();
        }
      }),
    );
    _pending = task;
    await task;
    return null;
  }
}

class _PlaybackShuffleOrder extends DefaultShuffleOrder {
  List<int>? next;

  @override
  void shuffle({int? initialIndex}) {
    final order = next;
    next = null;
    if (order == null) {
      super.shuffle(initialIndex: initialIndex);
    } else {
      indices
        ..clear()
        ..addAll(order);
    }
  }
}
