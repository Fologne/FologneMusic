import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/youtube_link.dart';

enum AudioDownloadStatus {
  waiting,
  running,
  canceling,
  completed,
  failed,
  canceled,
}

class AudioDownload {
  AudioDownload(this.link);

  final Uri link;
  AudioDownloadStatus status = AudioDownloadStatus.waiting;
  int? progress;
  String? title;
  String? trackId;
  String? error;

  bool get finished => switch (status) {
    AudioDownloadStatus.completed ||
    AudioDownloadStatus.failed ||
    AudioDownloadStatus.canceled => true,
    _ => false,
  };

  Map<String, Object?> toJson() => {
    'link': link.toString(),
    'status': status.name,
    'title': title,
    'trackId': trackId,
    'error': error,
  };

  static AudioDownload? fromJson(Object? value) {
    if (value is! Map<String, dynamic> || value['link'] is! String) return null;
    final link = youtubeVideoLink(value['link'] as String);
    if (link == null) return null;
    final entry = AudioDownload(link);
    entry.status =
        AudioDownloadStatus.values
            .where((status) => status.name == value['status'])
            .firstOrNull ??
        AudioDownloadStatus.failed;
    entry.title = value['title'] is String ? value['title'] as String : null;
    entry.trackId = value['trackId'] is String
        ? value['trackId'] as String
        : null;
    entry.error = value['error'] is String ? value['error'] as String : null;
    if (!entry.finished) {
      entry.status = AudioDownloadStatus.failed;
      entry.error = 'Download interrompido ao fechar o aplicativo.';
    }
    return entry;
  }
}

class AudioDownloadQueue extends ChangeNotifier {
  AudioDownloadQueue({
    required this.historyFile,
    required this.refreshLibrary,
    this.channel = const MethodChannel('musicapp/audioDownloads'),
  });

  final File historyFile;
  final Future<void> Function() refreshLibrary;
  final MethodChannel channel;
  final _entries = <AudioDownload>[];
  AudioDownload? _active;
  Future<void> _writes = Future.value();
  bool _disposed = false;
  bool ready = false;
  bool available = false;
  bool historyError = false;

  List<AudioDownload> get entries => List.unmodifiable(_entries);
  Future<void> get historySaved => _writes;

  Future<void> initialize() async {
    try {
      if (await historyFile.exists()) {
        final history = jsonDecode(await historyFile.readAsString()) as List;
        _entries.addAll(
          history.map(AudioDownload.fromJson).whereType<AudioDownload>(),
        );
      }
    } on Object {
      historyError = true;
    }
    if (_disposed) return;
    channel.setMethodCallHandler((call) async {
      final entry = _active;
      if (call.method == 'progress' &&
          entry?.status == AudioDownloadStatus.running &&
          call.arguments is int) {
        entry!.progress = (call.arguments as int).clamp(0, 100);
        _notify();
      }
    });
    try {
      available = await channel.invokeMethod<bool>('available') == true;
    } on PlatformException {
      available = false;
    } on MissingPluginException {
      available = false;
    }
    ready = true;
    _notify();
  }

  bool enqueue(Uri link) {
    if (!available || _entries.any((entry) => entry.link == link)) return false;
    _entries.add(AudioDownload(link));
    _changed();
    _startNext();
    return true;
  }

  void retry(AudioDownload entry) {
    if (!available ||
        !entry.finished ||
        entry.status == AudioDownloadStatus.completed ||
        !_entries.remove(entry)) {
      return;
    }
    entry
      ..status = AudioDownloadStatus.waiting
      ..progress = null
      ..error = null;
    _entries.add(entry);
    _changed();
    _startNext();
  }

  Future<void> cancel(AudioDownload entry) async {
    if (entry.status == AudioDownloadStatus.waiting) {
      entry.status = AudioDownloadStatus.canceled;
      _changed();
    } else if (_active == entry &&
        entry.status == AudioDownloadStatus.running) {
      entry.status = AudioDownloadStatus.canceling;
      _notify();
      var accepted = false;
      try {
        accepted = await channel.invokeMethod<bool>('cancel') == true;
      } on PlatformException {
        accepted = false;
      }
      if (!accepted && _active == entry) {
        entry.status = AudioDownloadStatus.running;
        _notify();
      }
    }
  }

  void clearHistory() {
    _entries.removeWhere((entry) => entry.finished);
    _changed();
  }

  void _startNext() {
    if (_disposed || _active != null) return;
    final next = _entries
        .where((entry) => entry.status == AudioDownloadStatus.waiting)
        .firstOrNull;
    if (next == null) return;
    _active = next;
    next.status = AudioDownloadStatus.running;
    _changed();
    unawaited(_run(next));
  }

  Future<void> _run(AudioDownload entry) async {
    try {
      final result = await channel.invokeMapMethod<String, String>('start', {
        'url': entry.link.toString(),
      });
      if (result?['trackId'] == null) throw const FormatException();
      entry
        ..title = result?['title']
        ..trackId = result?['trackId']
        ..status = AudioDownloadStatus.completed;
      await refreshLibrary();
    } on PlatformException catch (error) {
      entry
        ..status = error.code == 'canceled'
            ? AudioDownloadStatus.canceled
            : AudioDownloadStatus.failed
        ..error = error.message;
    } on FormatException {
      entry
        ..status = AudioDownloadStatus.failed
        ..error = 'Não foi possível identificar o MP3 salvo.';
    } finally {
      _active = null;
      _changed();
      _startNext();
    }
  }

  void _changed() {
    final snapshot = jsonEncode(
      _entries.map((entry) => entry.toJson()).toList(),
    );
    _writes = _writes.then((_) async {
      try {
        final temporary = File('${historyFile.path}.tmp');
        await temporary.writeAsString(snapshot, flush: true);
        await temporary.rename(historyFile.path);
        if (historyError) {
          historyError = false;
          _notify();
        }
      } on FileSystemException {
        historyError = true;
        _notify();
      }
    });
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    channel.setMethodCallHandler(null);
    super.dispose();
  }
}
